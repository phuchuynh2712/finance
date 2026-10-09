import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finance/core/auth/password_change_gateway.dart';

/// The two tokens of a session created by [SupabaseAuthRest.signInWithPassword].
/// Held in memory only, for a few seconds, and never logged.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Just the three Supabase Auth REST calls a password change needs, made with
/// plain HTTP instead of a second `GoTrueClient`.
///
/// Why not a second client: on web every `GoTrueClient` for a project shares
/// one `BroadcastChannel`, and a client that receives a broadcast adopts (or
/// drops) the session it carries. A throwaway "isolated" client would therefore
/// sign the app's own client in as the temporary session and, when closed,
/// sign it out. Plain HTTP has no channel, no storage and no events, so nothing
/// can leak into the app's session on any platform.
class SupabaseAuthRest {
  SupabaseAuthRest({
    required String baseUrl,
    required String apiKey,
    required http.Client httpClient,
    required bool ownsHttpClient,
  }) : _authUrl = '$baseUrl/auth/v1',
       _apiKey = apiKey,
       _http = httpClient,
       _ownsHttpClient = ownsHttpClient;

  static const _timeout = Duration(seconds: 20);

  final String _authUrl;
  final String _apiKey;
  final http.Client _http;
  final bool _ownsHttpClient;

  /// `POST /token?grant_type=password`. Throws the same exception types as
  /// gotrue: [AuthApiException] for a rejected request (`invalid_credentials`,
  /// `over_request_rate_limit`, …) and [AuthRetryableFetchException] for a
  /// network failure or a 5xx.
  Future<AuthTokens> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final json = await _send(
      'POST',
      '/token',
      query: const {'grant_type': 'password'},
      body: {'email': email, 'password': password},
    );
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    if (access is! String || refresh is! String) {
      throw AuthSessionMissingException();
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  /// `PUT /user` with the temporary session's token. The server also revokes
  /// every OTHER session of the account; this session is the one that survives.
  Future<void> updatePassword({
    required String accessToken,
    required String newPassword,
  }) async {
    await _send(
      'PUT',
      '/user',
      bearer: accessToken,
      body: {'password': newPassword},
    );
  }

  /// `POST /logout?scope=local`: revokes only this temporary session.
  Future<void> signOutLocal({required String accessToken}) async {
    await _send(
      'POST',
      '/logout',
      query: const {'scope': 'local'},
      bearer: accessToken,
    );
  }

  void close() {
    if (_ownsHttpClient) _http.close();
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    String? bearer,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(
      method,
      Uri.parse('$_authUrl$path').replace(queryParameters: query),
    )..headers['apikey'] = _apiKey;
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw AuthRetryableFetchException(message: 'Request timed out');
    } on SocketException {
      throw AuthRetryableFetchException(message: 'No connection');
    } on http.ClientException {
      throw AuthRetryableFetchException(message: 'No connection');
    }

    final json = _decode(response);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;

    final message =
        (json['msg'] ?? json['error_description'] ?? json['message'])
            ?.toString() ??
        'Request failed';
    // Like gotrue, a 5xx is "retryable" (reads as offline), not an API error.
    if (status >= 500) {
      throw AuthRetryableFetchException(
        message: message,
        statusCode: '$status',
      );
    }
    final code = json['error_code'] ?? json['error'];
    throw AuthApiException(
      message,
      statusCode: '$status',
      code: code is String ? code : null,
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }
}

/// The temporary session behind [VerifiedPasswordSession]: signed in with the
/// current password, used to set the new one, then either handed to the app
/// ([continueOnThisDevice]) or revoked ([close]).
class TemporaryPasswordSession implements VerifiedPasswordSession {
  TemporaryPasswordSession({
    required SupabaseAuthRest rest,
    required AuthTokens tokens,
    required GoTrueClient appAuth,
  }) : _rest = rest,
       _tokens = tokens,
       _appAuth = appAuth;

  final SupabaseAuthRest _rest;
  final AuthTokens _tokens;
  final GoTrueClient _appAuth;

  bool _handedOver = false;
  bool _closed = false;

  @override
  Future<void> setNewPassword(String newPassword) => _rest.updatePassword(
    accessToken: _tokens.accessToken,
    newPassword: newPassword,
  );

  /// The server revokes every other session when a password is updated, and
  /// this temporary session is the only one that survives. Handing it to the
  /// app's own client (`setSession` refreshes it and announces an ordinary
  /// `tokenRefreshed`) keeps THIS device signed in on a valid session.
  @override
  Future<void> continueOnThisDevice() async {
    await _appAuth.setSession(_tokens.refreshToken);
    _handedOver = true;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_handedOver) {
      try {
        // `local` revokes only this temporary session.
        await _rest.signOutLocal(accessToken: _tokens.accessToken);
      } catch (_) {
        // The session lives in memory and is being discarded; a failed revoke
        // only leaves a short-lived session that expires on its own.
      }
    }
    _rest.close();
  }
}
