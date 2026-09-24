class AppEnvironment {
  AppEnvironment._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static void validate() {
    final uri = Uri.tryParse(supabaseUrl);
    if (supabaseUrl.isEmpty ||
        uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid Supabase URL configuration.');
    }
    if (supabasePublishableKey.isEmpty) {
      throw const FormatException(
        'Missing Supabase publishable key configuration.',
      );
    }
  }
}
