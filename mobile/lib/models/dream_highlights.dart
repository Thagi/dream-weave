class TagFrequency {
  TagFrequency({required this.tag, required this.count});

  factory TagFrequency.fromJson(Map<String, dynamic> json) {
    return TagFrequency(
      tag: json['tag'] as String,
      count: json['count'] as int,
    );
  }

  final String tag;
  final int count;
}

class MoodFrequency {
  MoodFrequency({required this.mood, required this.count});

  factory MoodFrequency.fromJson(Map<String, dynamic> json) {
    return MoodFrequency(
      mood: json['mood'] as String,
      count: json['count'] as int,
    );
  }

  final String mood;
  final int count;
}

class DreamHighlights {
  DreamHighlights({
    required this.totalCount,
    required this.topTags,
    required this.moods,
  });

  factory DreamHighlights.fromJson(Map<String, dynamic> json) {
    final tags = json['top_tags'] as List<dynamic>?;
    final moods = json['moods'] as List<dynamic>?;
    return DreamHighlights(
      totalCount: json['total_count'] as int,
      topTags: tags == null
          ? <TagFrequency>[]
          : tags
              .cast<Map<String, dynamic>>()
              .map(TagFrequency.fromJson)
              .toList(growable: false),
      moods: moods == null
          ? <MoodFrequency>[]
          : moods
              .cast<Map<String, dynamic>>()
              .map(MoodFrequency.fromJson)
              .toList(growable: false),
    );
  }

  final int totalCount;
  final List<TagFrequency> topTags;
  final List<MoodFrequency> moods;
}
