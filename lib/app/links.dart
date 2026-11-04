/// Public links baked into share messages. Update when the repo or domain changes.
abstract final class AppLinks {
  static const repo = 'https://github.com/C00LPIXER/trailseek';

  /// Always points at the newest GitHub release's Android build.
  static const androidApk = '$repo/releases/latest/download/trailseek.apk';

  static const privacy = 'https://c00lpixer.github.io/trailseek/privacy.html';
  static const terms = 'https://c00lpixer.github.io/trailseek/terms.html';

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
      'Join my Trail Seek group "$groupName" for $adventureName on $date.\\n'
      'Code: $code\\n'
      '${joinDeepLink(code, securityKey: securityKey)}\\n'
      'Scan this private invitation QR/link in Trail Seek to join securely. '
      'Do not post the invite publicly.\\n'
      'Get the Android app: $androidApk';
}
