bool isAllowedGoogleFormUrl(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host == 'forms.gle') return uri.pathSegments.isNotEmpty;
  return host == 'docs.google.com' &&
      uri.pathSegments.isNotEmpty &&
      uri.pathSegments.first == 'forms' &&
      uri.pathSegments.contains('d');
}
