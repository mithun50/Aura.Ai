import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request storage permission based on Android version
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ uses granular media permissions
    final status = await Permission.storage.status;
    if (status.isGranted) return true;

    final result = await Permission.storage.request();
    if (result.isGranted) return true;

    // Try manage external storage as fallback
    final manageStatus = await Permission.manageExternalStorage.request();
    return manageStatus.isGranted;
  }

  /// Request SMS read permission
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;

    final status = await Permission.sms.status;
    if (status.isGranted) return true;

    final result = await Permission.sms.request();
    if (result.isGranted) return true;

    if (kDebugMode) debugPrint('SMS permission denied');
    return false;
  }

  /// Check if SMS permission is granted
  Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    return await Permission.sms.isGranted;
  }

  /// Check if storage permission is granted
  Future<bool> hasStoragePermission() async {
    return await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted;
  }
}
