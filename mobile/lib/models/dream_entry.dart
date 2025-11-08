class DreamEntry {
  DreamEntry({
    required this.id,
    required this.title,
    required this.transcript,
    required this.summary,
    required this.tags,
    required this.mood,
    required this.createdAt,
    this.journal,
    this.journalGeneratedAt,
  });

  factory DreamEntry.fromJson(Map<String, dynamic> json) {
    return DreamEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      transcript: json['transcript'] as String,
      summary: json['summary'] as String,
      tags: List<String>.from(json['tags'] as List<dynamic>),
      mood: json['mood'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      journal: json['journal'] as String?,
      journalGeneratedAt: json['journal_generated_at'] == null
          ? null
          : DateTime.parse(json['journal_generated_at'] as String),
    );
  }

  final String id;
  final String title;
  final String transcript;
  final String summary;
  final List<String> tags;
  final String? mood;
  final DateTime createdAt;
  final String? journal;
  final DateTime? journalGeneratedAt;

  DreamEntry copyWith({
    String? title,
    String? transcript,
    String? summary,
    List<String>? tags,
    String? mood,
    String? journal,
    DateTime? journalGeneratedAt,
  }) {
    return DreamEntry(
      id: id,
      title: title ?? this.title,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      tags: tags ?? List<String>.from(this.tags),
      mood: mood ?? this.mood,
      createdAt: createdAt,
      journal: journal ?? this.journal,
      journalGeneratedAt: journalGeneratedAt ?? this.journalGeneratedAt,
    );
  }
}
