bool isAllowedGoogleFormUrl(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      uri.port != 443) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'forms.gle') {
    return RegExp(r'^/[A-Za-z0-9_-]+/?$').hasMatch(uri.path);
  }
  return host == 'docs.google.com' &&
      RegExp(r'^/forms/d/(?:e/)?[A-Za-z0-9_-]+/viewform/?$').hasMatch(uri.path);
}

/// Menentukan navigasi dokumen, bukan permintaan gambar/script Google.
class FormNavigationPolicy {
  FormNavigationPolicy(this.initialUrl) {
    if (!isAllowedGoogleFormUrl(initialUrl)) {
      throw const FormatException('Tautan Google Forms tidak valid.');
    }
    if (initialUrl.host == 'docs.google.com') _formPath = _root(initialUrl);
  }

  final Uri initialUrl;
  String? _formPath;
  bool _responseClosed = false;
  String? get formPath => _formPath;

  static String _root(Uri uri) =>
      uri.path.replaceFirst(RegExp(r'/(viewform|formResponse)/?$'), '');

  bool allows(Uri target, {bool isMainFrame = true}) {
    if (target.scheme != 'https' ||
        target.port != 443 ||
        target.userInfo.isNotEmpty ||
        target.fragment.isNotEmpty) {
      return false;
    }
    if (!isMainFrame) {
      return (target.host == 'www.google.com' ||
              target.host == 'www.recaptcha.net') &&
          target.path.startsWith('/recaptcha/');
    }
    if (_responseClosed ||
        target.queryParameters.keys.any(
          (key) => key.toLowerCase().startsWith('edit'),
        )) {
      return false;
    }
    if (_formPath == null) {
      if (target == initialUrl) return true;
      if (target.host != 'docs.google.com' || !isAllowedGoogleFormUrl(target)) {
        return false;
      }
      _formPath = _root(target);
    }
    final path = target.path.replaceFirst(RegExp(r'/$'), '');
    return target.host == 'docs.google.com' &&
        (path == '$_formPath/viewform' || path == '$_formPath/formResponse');
  }

  void observePage(Uri uri, {required bool hasForm}) {
    // formResponse juga dipakai Form multi-halaman. URL saja tidak
    // menyatakan submit berhasil. Guru tetap memeriksa respons sendiri.
    if (uri.path.replaceFirst(RegExp(r'/$'), '') == '$_formPath/formResponse' &&
        !hasForm) {
      _responseClosed = true;
    }
  }
}
