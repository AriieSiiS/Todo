import 'enums.dart';
import 'json_helpers.dart';

class QuickNote {
  const QuickNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.status = NoteStatus.inbox,
    this.scheduledFor,
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final NoteStatus status;
  final DateTime? scheduledFor;

  QuickNote copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    NoteStatus? status,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
  }) {
    return QuickNote(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      scheduledFor:
          clearScheduledFor ? null : scheduledFor ?? this.scheduledFor,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'scheduledFor': scheduledFor?.toIso8601String(),
    };
  }

  factory QuickNote.fromJson(Map<String, dynamic> json) {
    return QuickNote(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: enumByName(
          NoteStatus.values, json['status'] as String?, NoteStatus.inbox),
      scheduledFor: json['scheduledFor'] == null
          ? null
          : DateTime.tryParse(json['scheduledFor'] as String),
    );
  }
}
