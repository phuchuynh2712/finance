import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys added by the Security screen / change-password feature. Each must
/// carry an `@key` description in the template ARB (older keys predate that
/// rule, so the description check is limited to this list).
const _securityFeatureKeys = [
  'securityScreenTitle',
  'securityChangePasswordRow',
  'securityBiometricRow',
  'securityBiometricReasonWeb',
  'securityBiometricReasonNoHardware',
  'securityBiometricReasonNotEnrolled',
  'securityBiometricPromptReason',
  'securityBiometricEnableFailed',
  'securityPasswordChangedNotice',
  'securityPasswordChangedOthersNotEnded',
  'securityOthersRetryAction',
  'securityOthersSignedOutNotice',
  'changePasswordTitle',
  'changePasswordCurrentLabel',
  'changePasswordNewLabel',
  'changePasswordConfirmLabel',
  'passwordRequirementHint',
  'passwordTooShortError',
  'changePasswordCurrentRequiredError',
  'changePasswordSameAsCurrentError',
  'changePasswordWrongCurrentError',
  'changePasswordSubmit',
  'errorMapperSessionExpired',
];

/// Keys added by the adaptive web layout feature (the Chi tiêu number pad's
/// delete key tooltip and screen-reader label). Checked exactly like
/// [_securityFeatureKeys].
const _adaptiveWebFeatureKeys = ['expenseKeypadDeleteSemantic'];

/// Keys added by the PIN lock feature (the lock screen's PIN mode, the set-up,
/// change and turn-off flow, the Security row and the one-time offer). Checked
/// exactly like [_securityFeatureKeys].
const _pinLockKeys = [
  'pinLockRow',
  'pinLockRowCaptionOff',
  'pinLockRowCaptionOn',
  'pinLockRowCaptionExpired',
  'pinChangeAction',
  'pinEnterTitle',
  'pinDotsSemantic',
  'pinKeypadDeleteSemantic',
  'pinWrongTries',
  'pinInvalidated',
  'pinExpired',
  'pinUsePasswordAction',
  'pinForgotAction',
  'pinSetupConfirmPasswordTitle',
  'pinSetupNewTitle',
  'pinSetupRepeatTitle',
  'pinChangeCurrentTitle',
  'pinTurnOffTitle',
  'pinTooEasy',
  'pinMismatch',
  'pinSetDone',
  'pinOfferTitle',
  'pinOfferMessage',
  'pinOfferAcceptAction',
  'pinOfferDeclineAction',
  'pinSetupContinueAction',
];

/// Keys added by the transaction corrections feature (delete, edit and reverse
/// a saved transaction, the notices of the sync layer). Checked exactly like
/// [_securityFeatureKeys].
const _correctionKeys = ['syncBalanceMismatchNotice'];

Map<String, dynamic> _readArb(String name) {
  final file = File('lib/core/l10n/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  final vi = _readArb('app_vi.arb');
  final en = _readArb('app_en.arb');

  test('app_vi.arb and app_en.arb define exactly the same message keys', () {
    final viKeys = _messageKeys(vi);
    final enKeys = _messageKeys(en);

    expect(
      viKeys.difference(enKeys),
      isEmpty,
      reason: 'Keys missing from app_en.arb',
    );
    expect(
      enKeys.difference(viKeys),
      isEmpty,
      reason: 'Keys missing from app_vi.arb (the template)',
    );
  });

  test('every message value is a non-empty string in both languages', () {
    for (final arb in [vi, en]) {
      for (final key in _messageKeys(arb)) {
        final value = arb[key];
        expect(value, isA<String>(), reason: key);
        expect((value as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('the feature keys exist and have a template description', () {
    for (final key in [
      ..._securityFeatureKeys,
      ..._adaptiveWebFeatureKeys,
      ..._pinLockKeys,
      ..._correctionKeys,
    ]) {
      expect(vi.containsKey(key), isTrue, reason: 'app_vi.arb is missing $key');
      expect(en.containsKey(key), isTrue, reason: 'app_en.arb is missing $key');
      final meta = vi['@$key'];
      expect(
        meta is Map && (meta['description'] as String?)?.isNotEmpty == true,
        isTrue,
        reason: 'app_vi.arb needs an @$key description',
      );
    }
  });

  test('the minimum length stated to the person is 8 in both languages', () {
    for (final arb in [vi, en]) {
      expect(arb['passwordRequirementHint'], contains('8'));
      expect(arb['passwordTooShortError'], contains('8'));
    }
  });
}
