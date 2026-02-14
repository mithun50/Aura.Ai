import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aura_mobile/domain/entities/memory.dart';

class MemoryModel extends Memory {
  const MemoryModel({
    required super.id,
    required super.content,
    required super.category,
    required super.timestamp,
    super.embedding,
    super.eventDate,
    super.eventTime,
    super.reminderScheduled,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    return MemoryModel(
      id: json['id'],
      content: json['content'],
      category: json['category'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      embedding: json['embedding'] != null
          ? (jsonDecode(json['embedding']) as List).cast<double>()
          : null,
      eventDate: json['eventDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['eventDate'])
          : null,
      eventTime: json['eventTime'] != null
          ? _timeOfDayFromString(json['eventTime'])
          : null,
      reminderScheduled: json['reminderScheduled'] == 1,
    );
  }

  static TimeOfDay? _timeOfDayFromString(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'category': category,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'embedding': embedding != null ? jsonEncode(embedding) : null,
      'eventDate': eventDate?.millisecondsSinceEpoch,
      'eventTime': eventTime != null ? '${eventTime!.hour}:${eventTime!.minute}' : null,
      'reminderScheduled': reminderScheduled ? 1 : 0,
    };
  }

  factory MemoryModel.fromEntity(Memory memory) {
    return MemoryModel(
      id: memory.id,
      content: memory.content,
      category: memory.category,
      timestamp: memory.timestamp,
      embedding: memory.embedding,
      eventDate: memory.eventDate,
      eventTime: memory.eventTime,
      reminderScheduled: memory.reminderScheduled,
    );
  }
}
