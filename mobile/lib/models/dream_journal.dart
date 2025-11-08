import 'dream_entry.dart';

class DreamJournalResult {
  DreamJournalResult({
    required this.entry,
    required this.narrative,
    required this.engine,
  });

  factory DreamJournalResult.fromJson(Map<String, dynamic> json) {
    return DreamJournalResult(
      entry: DreamEntry.fromJson(json['dream'] as Map<String, dynamic>),
      narrative: json['narrative'] as String,
      engine: json['engine'] as String,
    );
  }

  final DreamEntry entry;
  final String narrative;
  final String engine;
}
