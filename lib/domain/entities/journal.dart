/// Entrada del diario: una por día, con ánimo y foto opcionales.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.text = '',
    this.mood = 0,
    this.imagePath = '',
    this.thumbnailPath = '',
    this.imageSha256 = '',
  });

  final String id;
  final DateTime date;
  final String text;

  /// De 1 (muy bajo) a 5 (muy bueno). 0 significa «sin indicar».
  final int mood;
  final String imagePath;
  final String thumbnailPath;
  final String imageSha256;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasImage => imagePath.isNotEmpty;

  JournalEntry copyWith({
    DateTime? date,
    String? text,
    int? mood,
    String? imagePath,
    String? thumbnailPath,
    String? imageSha256,
    DateTime? updatedAt,
  }) =>
      JournalEntry(
        id: id,
        date: date ?? this.date,
        text: text ?? this.text,
        mood: mood ?? this.mood,
        imagePath: imagePath ?? this.imagePath,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        imageSha256: imageSha256 ?? this.imageSha256,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date.toIso8601String(),
        'text': text,
        'mood': mood,
        'imagePath': imagePath,
        'thumbnailPath': thumbnailPath,
        'imageSha256': imageSha256,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now();
    final parsedDate = DateTime.tryParse(json['date'] as String? ?? '');
    final day = parsedDate ?? created;
    return JournalEntry(
      id: json['id'] as String? ?? '',
      date: DateTime(day.year, day.month, day.day),
      text: json['text'] as String? ?? '',
      mood: ((json['mood'] as num?)?.toInt() ?? 0).clamp(0, 5),
      imagePath: json['imagePath'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String? ?? '',
      imageSha256: json['imageSha256'] as String? ?? '',
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
    );
  }
}
