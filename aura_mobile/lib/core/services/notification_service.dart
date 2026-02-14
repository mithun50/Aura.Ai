import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:aura_mobile/domain/entities/memory.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize notification system
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); // Set to user's timezone

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Schedule a reminder for a memory with date/time
  Future<void> scheduleReminder(Memory memory) async {
    if (!_initialized) await initialize();
    if (memory.eventDate == null) return;

    final eventDateTime = _combineDateTime(memory.eventDate!, memory.eventTime);
    final notificationId = memory.id.hashCode;

    // Schedule notification at event time
    await _scheduleNotification(
      id: notificationId,
      title: '🔔 Reminder',
      body: memory.content,
      scheduledDate: eventDateTime,
    );

    // Schedule 1-day-before reminder if event is more than 1 day away
    final oneDayBefore = eventDateTime.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: notificationId + 1, // Different ID for pre-reminder
        title: '📅 Tomorrow',
        body: memory.content,
        scheduledDate: oneDayBefore,
      );
    }
  }

  /// Cancel a scheduled reminder
  Future<void> cancelReminder(String memoryId) async {
    final notificationId = memoryId.hashCode;
    await _notifications.cancel(notificationId);
    await _notifications.cancel(notificationId + 1); // Cancel pre-reminder too
  }

  /// Schedule daily summary at 8 PM
  Future<void> scheduleDailySummary(int eventCount) async {
    if (!_initialized) await initialize();
    if (eventCount == 0) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 20, 0); // 8 PM today
    
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1)); // Tomorrow 8 PM
    }

    await _scheduleNotification(
      id: 999999, // Fixed ID for daily summary
      title: '📋 Daily Summary',
      body: 'You have $eventCount task${eventCount > 1 ? 's' : ''} tomorrow.',
      scheduledDate: scheduledTime,
    );
  }

  /// Schedule inactivity reminder (3 days)
  Future<void> scheduleInactivityReminder() async {
    if (!_initialized) await initialize();

    final threeDaysLater = DateTime.now().add(const Duration(days: 3));

    await _scheduleNotification(
      id: 888888, // Fixed ID for inactivity
      title: '💡 AURA Reminder',
      body: 'Do you want to review your saved notes?',
      scheduledDate: threeDaysLater,
    );
  }

  /// Cancel inactivity reminder (called when user opens app)
  Future<void> cancelInactivityReminder() async {
    await _notifications.cancel(888888);
  }

  // ========== PRIVATE HELPERS ==========

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'aura_reminders',
          'AURA Reminders',
          channelDescription: 'Notifications for scheduled events and reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay? time) {
    if (time == null) {
      return DateTime(date.year, date.month, date.day, 9, 0); // Default 9 AM
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap (e.g., navigate to specific memory)
    debugPrint('Notification tapped: ${response.payload}');
  }
}
