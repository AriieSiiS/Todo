import 'enums.dart';
import 'json_helpers.dart';

class QuickNote {
  const QuickNote({
    required this.id,
    required this.content,
    required this.createdAt,
    this.status = NoteStatus.inbox,
    this.scheduledFor,
    this.emoji = '',
    this.colorValue,
    this.isPinned = false,
    this.updatedAt,
    this.categoryIds = const <String>[],
  });

  final String id;
  final String content;
  final DateTime createdAt;
  final NoteStatus status;
  final DateTime? scheduledFor;
  final String emoji;
  final int? colorValue;
  final bool isPinned;
  final DateTime? updatedAt;
  final List<String> categoryIds;

  DateTime get effectiveUpdatedAt => updatedAt ?? createdAt;

  QuickNote copyWith({
    String? id,
    String? content,
    DateTime? createdAt,
    NoteStatus? status,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
    String? emoji,
    int? colorValue,
    bool clearColor = false,
    bool? isPinned,
    DateTime? updatedAt,
    List<String>? categoryIds,
  }) {
    return QuickNote(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      scheduledFor:
          clearScheduledFor ? null : scheduledFor ?? this.scheduledFor,
      emoji: emoji ?? this.emoji,
      colorValue: clearColor ? null : colorValue ?? this.colorValue,
      isPinned: isPinned ?? this.isPinned,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'scheduledFor': scheduledFor?.toIso8601String(),
      'emoji': emoji,
      'colorValue': colorValue,
      'isPinned': isPinned,
      'updatedAt': updatedAt?.toIso8601String(),
      'categoryIds': categoryIds,
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
      emoji: json['emoji'] as String? ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt(),
      isPinned: json['isPinned'] as bool? ?? false,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      categoryIds: (json['categoryIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }
}
