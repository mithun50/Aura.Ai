import 'package:shared_preferences/shared_preferences.dart';
import 'package:aura_mobile/core/services/notification_service.dart';

class AppUsageTracker {
  static const String _lastOpenKey = 'last_app_open';
  static const int _inactivityDays = 3;

  final NotificationService _notificationService = NotificationService();

  /// Track app open
  Future<void> trackAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Check if user was inactive
    final lastOpen = prefs.getInt(_lastOpenKey);
    if (lastOpen != null) {
      final lastOpenDate = DateTime.fromMillisecondsSinceEpoch(lastOpen);
      final daysSinceLastOpen = DateTime.now().difference(lastOpenDate).inDays;
      
      if (daysSinceLastOpen >= _inactivityDays) {
        // User was inactive, cancel any pending inactivity reminder
        await _notificationService.cancelInactivityReminder();
      }
    }
    
    // Update last open time
    await prefs.setInt(_lastOpenKey, now);
    
    // Schedule new inactivity reminder for 3 days from now
    await _notificationService.scheduleInactivityReminder();
  }

  /// Check if user has been inactive
  Future<bool> isInactive() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpen = prefs.getInt(_lastOpenKey);
    
    if (lastOpen == null) return false;
    
    final lastOpenDate = DateTime.fromMillisecondsSinceEpoch(lastOpen);
    final daysSinceLastOpen = DateTime.now().difference(lastOpenDate).inDays;
    
    return daysSinceLastOpen >= _inactivityDays;
  }

  /// Get days since last app open
  Future<int> getDaysSinceLastOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final lastOpen = prefs.getInt(_lastOpenKey);
    
    if (lastOpen == null) return 0;
    
    final lastOpenDate = DateTime.fromMillisecondsSinceEpoch(lastOpen);
    return DateTime.now().difference(lastOpenDate).inDays;
  }
}
