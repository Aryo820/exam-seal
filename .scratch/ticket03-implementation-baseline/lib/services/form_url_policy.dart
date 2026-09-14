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
