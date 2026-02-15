import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_mobile/core/services/permission_service.dart';

final smsServiceProvider = Provider((ref) => SmsService());

/// Simple SMS message model (replaces telephony package dependency)
class SmsMessage {
  final String? address;
  final String? body;
  final int? date;

  SmsMessage({this.address, this.body, this.date});
}

/// SMS reading service using platform MethodChannel.
/// Replaces the telephony package which is incompatible with AGP 8+.
class SmsService {
  static const _channel = MethodChannel('com.aura.mobile/sms');
  final PermissionService _permissionService = PermissionService();

  /// Read recent SMS messages
  Future<List<SmsMessage>> getRecentMessages({int count = 20}) async {
    try {
      final hasPermission = await _permissionService.requestSmsPermission();
      if (!hasPermission) return [];

      final List<dynamic> result = await _channel.invokeMethod(
        'getMessages',
        {'count': count},
      );

      return result.map((m) => SmsMessage(
        address: m['address'] as String?,
        body: m['body'] as String?,
        date: m['date'] as int?,
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error reading SMS: $e');
      return [];
    }
  }

  /// Search SMS by query (sender name/number or content)
  Future<List<SmsMessage>> searchMessages(String query, {int limit = 10}) async {
    try {
      final hasPermission = await _permissionService.hasSmsPermission();
      if (!hasPermission) return [];

      final List<dynamic> result = await _channel.invokeMethod(
        'searchMessages',
        {'query': query, 'limit': limit},
      );

      return result.map((m) => SmsMessage(
        address: m['address'] as String?,
        body: m['body'] as String?,
        date: m['date'] as int?,
      )).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error searching SMS: $e');
      return [];
    }
  }

  /// Format SMS messages as context for LLM
  String formatAsContext(List<SmsMessage> messages) {
    if (messages.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('SMS MESSAGES:');
    for (final msg in messages) {
      final date = msg.date != null
          ? DateTime.fromMillisecondsSinceEpoch(msg.date!).toString().substring(0, 16)
          : 'unknown date';
      buffer.writeln('From: ${msg.address ?? 'unknown'} ($date)');
      buffer.writeln('  ${msg.body ?? ''}');
      buffer.writeln('');
    }
    return buffer.toString();
  }
}
