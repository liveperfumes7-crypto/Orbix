/// Build-time configuration. Nothing secret lives here: the Supabase URL and
/// publishable key are public by design (access is enforced by RLS on the server).
class Config {
  static const appName = 'Orbix';
  static const shortCode = 'OB';
  static const websiteUrl = String.fromEnvironment('WEBSITE_URL', defaultValue: 'https://orbix-gray.vercel.app');
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: '');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://wppultvjscruthsuddae.supabase.co');
  static const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_UzXZR01dpByanCoXuYPPNQ_6_-2h5Ph');

  /// Set by CI for the Play bundle: no UPI, no WebView, no prices.
  static const playStore = bool.fromEnvironment('PLAY_STORE');

  /// Set by CI for the ads APK: utm_source=meta&utm_medium=paid_social&utm_campaign=apk_download
  static const apkReferrer = String.fromEnvironment('APK_REFERRER');
  static const authScheme = String.fromEnvironment('AUTH_SCHEME', defaultValue: 'com.orbix.app');

  /// Kept in sync with pubspec.yaml; a test fails when they differ.
  static const versionLabel = '1.0.1';
}
