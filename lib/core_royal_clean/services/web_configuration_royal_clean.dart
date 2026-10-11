/// Public browser configuration supplied at build time, never backend secrets.
class WebConfigurationRoyalClean {
  static const appCheckSiteKey = String.fromEnvironment(
    'ROYAL_WEB_APP_CHECK_SITE_KEY',
  );
  static const visualPreview = bool.fromEnvironment('ROYAL_WEB_VISUAL_PREVIEW');
  // Institutional page and Flutter application share the same Hosting origin.
  static const institutionalUrl = String.fromEnvironment(
    'ROYAL_INSTITUTIONAL_URL',
  );

  static Uri? get institutionalUri {
    if (institutionalUrl == '/') return Uri(path: '/');
    final uri = Uri.tryParse(institutionalUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'institucional.royalcleandistribuidora.com.br' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    return uri;
  }

  static void requireAppCheck() {
    if (visualPreview || appCheckSiteKey.isEmpty) {
      throw StateError('Web App Check production configuration is required.');
    }
  }
}
