/// Public links baked into share messages. Update when the repo or domain changes.
abstract final class AppLinks {
  static const repo = 'https://github.com/C00LPIXER/trailseek';

  /// Always points at the newest GitHub release's Android build.
  static const androidApk = '$repo/releases/latest/download/trailseek.apk';

  static const privacy = 'https://c00lpixer.github.io/trailseek/privacy.html';
  static const terms = 'https://c00lpixer.github.io/trailseek/terms.html';

  static String joinDeepLink(String code) => 'trailseek://join/$code';

  static String groupInvite({required String groupName, required String adventureName, required String date, required String code}) =>
      'Join my Trail Seek group "$groupName" for $adventureName on $date. Code: $code\n'
      'Get the Android app: $androidApk\n'
      'Open the app → Groups → Join → enter $code';
}
