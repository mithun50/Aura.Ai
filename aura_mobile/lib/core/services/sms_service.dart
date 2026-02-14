import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telephony/telephony.dart';
import 'package:aura_mobile/core/services/permission_service.dart';

final smsServiceProvider = Provider((ref) => SmsService());

class SmsService {
  final Telephony _telephony = Telephony.instance;
  final PermissionService _permissionService = PermissionService();

  /// Read recent SMS messages
  Future<List<SmsMessage>> getRecentMessages({int count = 20}) async {
    try {
      final hasPermission = await _permissionService.requestSmsPermission();
      if (!hasPermission) return [];

      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      return messages.take(count).toList();
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

      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.ADDRESS)
            .like('%$query%')
            .or(SmsColumn.BODY)
            .like('%$query%'),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      return messages.take(limit).toList();
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
