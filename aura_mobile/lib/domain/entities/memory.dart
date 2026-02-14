import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Memory extends Equatable {
  final String id;
  final String content;
  final String category;
  final DateTime timestamp;
  final List<double>? embedding;
  final DateTime? eventDate;
  final TimeOfDay? eventTime;
  final bool reminderScheduled;

  const Memory({
    required this.id,
    required this.content,
    required this.category,
    required this.timestamp,
    this.embedding,
    this.eventDate,
    this.eventTime,
    this.reminderScheduled = false,
  });

  Memory copyWith({
    String? id,
    String? content,
    String? category,
    DateTime? timestamp,
    List<double>? embedding,
    DateTime? eventDate,
    TimeOfDay? eventTime,
    bool? reminderScheduled,
  }) {
    return Memory(
      id: id ?? this.id,
      content: content ?? this.content,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      embedding: embedding ?? this.embedding,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      reminderScheduled: reminderScheduled ?? this.reminderScheduled,
    );
  }

  @override
  List<Object?> get props => [id, content, category, timestamp, embedding, eventDate, eventTime, reminderScheduled];
}
