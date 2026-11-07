import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update_info.dart';

enum UpdateCheckStatus { updateAvailable, upToDate, failed }

/// The outcome of [AppUpdateService.check].
class UpdateCheckResult {
  final UpdateCheckStatus status;

  /// Set only when [status] is [UpdateCheckStatus.updateAvailable].
  final AppUpdateInfo? info;

  const UpdateCheckResult._(this.status, this.info);

  const UpdateCheckResult.available(AppUpdateInfo info)
      : this._(UpdateCheckStatus.updateAvailable, info);

  const UpdateCheckResult.upToDate() : this._(UpdateCheckStatus.upToDate, null);

  const UpdateCheckResult.failed() : this._(UpdateCheckStatus.failed, null);
}

/// Compares the installed build number with `settings/appUpdate`.
class AppUpdateService {
  static const _timeout = Duration(seconds: 10);

  final DatabaseReference _root;

  AppUpdateService({DatabaseReference? root})
      : _root = root ?? FirebaseDatabase.instance.ref();

  /// Looks for a newer version and says what happened, so the "Check for
  /// updates" button can tell "you are up to date" apart from "could not
  /// check". Never throws.
  Future<UpdateCheckResult> check() async {
    try {
      final snapshot =
          await _root.child('settings/appUpdate').get().timeout(_timeout);
      final value = snapshot.value;
      if (value is! Map) return const UpdateCheckResult.upToDate();

      final info = AppUpdateInfo.fromMap(value);
      if (info.latestBuild <= 0 || !info.hasValidLink) {
        return const UpdateCheckResult.upToDate();
      }

      final package = await PackageInfo.fromPlatform();
      final installed = int.tryParse(package.buildNumber) ?? 0;
      return info.latestBuild > installed
          ? UpdateCheckResult.available(info)
          : const UpdateCheckResult.upToDate();
    } catch (e) {
      debugPrint('AppUpdateService: $e');
      return const UpdateCheckResult.failed();
    }
  }

  /// The published update when it is newer than this install, otherwise null.
  /// Never throws: a missing setting, no internet or a bad value just means
  /// "no update to show".
  Future<AppUpdateInfo?> findUpdate() async => (await check()).info;
}
