/// The newest app version the admin published, saved at `settings/appUpdate`:
///
///   latestBuild   whole number; the `+N` part of `version:` in pubspec.yaml
///   versionName   text shown to the customer, e.g. "1.1.0"
///   apkUrl        link to the APK (Google Drive); must start with https://
///   message       optional "What's new" text
class AppUpdateInfo {
  final int latestBuild;
  final String versionName;
  final String apkUrl;
  final String message;

  const AppUpdateInfo({
    required this.latestBuild,
    required this.versionName,
    required this.apkUrl,
    required this.message,
  });

  factory AppUpdateInfo.fromMap(Map<dynamic, dynamic> map) {
    String text(String key) => (map[key] ?? '').toString().trim();
    final build = map['latestBuild'];
    return AppUpdateInfo(
      latestBuild: build is num ? build.toInt() : int.tryParse('$build') ?? 0,
      versionName: text('versionName'),
      apkUrl: text('apkUrl'),
      message: text('message'),
    );
  }

  /// Only https links are opened, so a typo or bad value cannot launch
  /// anything else on the phone.
  bool get hasValidLink {
    final uri = Uri.tryParse(apkUrl);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }
}
