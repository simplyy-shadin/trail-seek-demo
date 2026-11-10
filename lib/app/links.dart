/// Public links baked into share messages. Update when the repo or domain changes.
abstract final class AppLinks {
  /// The brand website. The code repo is private, so everything public
  /// (download, policies) is served from here.
  static const site = 'https://trailseek.vercel.app';

  /// Always the newest Android build (copied in on every website deploy).
  static const androidApk = '$site/trailseek.apk';

  static const privacy = '$site/privacy.html';
  static const terms = '$site/terms.html';

  static String joinDeepLink(String code, {String? securityKey}) {
    final uri = Uri(
      scheme: 'trailseek',
      host: 'join',
      path: '/$code',
      queryParameters: securityKey == null ? null : {'key': securityKey},
    );
    return uri.toString();
  }

  static String groupInvite({
    required String groupName,
    required String adventureName,
    required String date,
    required String code,
    String? securityKey,
  }) =>
      'Join my Trail Seek group "$groupName" for $adventureName on $date.\n'
      'Code: $code\n'
      '${joinDeepLink(code, securityKey: securityKey)}\n'
      'Scan this private invitation QR/link in Trail Seek to join securely. '
      'Do not post the invite publicly.\n'
      'Get the Android app: $androidApk';
}
