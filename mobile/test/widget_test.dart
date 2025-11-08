import 'dart:convert';
import 'dart:typed_data';

import 'package:dream_weave/models/dream_entry.dart';
import 'package:dream_weave/models/dream_highlights.dart';
import 'package:dream_weave/models/dream_journal.dart';
import 'package:dream_weave/models/transcription_result.dart';
import 'package:dream_weave/screens/dream_capture_screen.dart';
import 'package:dream_weave/services/alarm_service.dart';
import 'package:dream_weave/services/dream_service.dart';
import 'package:dream_weave/services/voice_recorder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDreamService extends DreamService {
  FakeDreamService({List<DreamEntry>? seed})
      : _entries = List<DreamEntry>.from(seed ?? <DreamEntry>[]),
        super(baseUrl: 'http://localhost');

  final List<DreamEntry> _entries;

  @override
  Future<List<DreamEntry>> fetchDreams({
    String? tag,
    String? query,
    String? mood,
    DateTime? start,
    DateTime? end,
    int limit = 20,
  }) async {
    Iterable<DreamEntry> dreams = _entries;
    if (tag != null) {
      dreams = dreams.where((entry) => entry.tags.contains(tag));
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      dreams = dreams.where((entry) =>
          entry.title.toLowerCase().contains(q) ||
          entry.transcript.toLowerCase().contains(q) ||
          entry.summary.toLowerCase().contains(q) ||
          (entry.journal?.toLowerCase().contains(q) ?? false));
    }
    if (mood != null && mood.isNotEmpty) {
      dreams = dreams.where((entry) => entry.mood == mood);
    }
    return dreams.take(limit).toList();
  }

  @override
  Future<DreamEntry> createDream({
    required String title,
    required String transcript,
    required List<String> tags,
    String? mood,
  }) async {
    final entry = DreamEntry(
      id: (_entries.length + 1).toString(),
      title: title,
      transcript: transcript,
      summary: transcript,
      tags: tags,
      mood: mood,
      createdAt: DateTime.now(),
      journal: null,
      journalGeneratedAt: null,
    );
    _entries.insert(0, entry);
    return entry;
  }

  @override
  Future<DreamHighlights> fetchHighlights() async {
    final tagCounts = <String, int>{};
    final moodCounts = <String, int>{};
    for (final entry in _entries) {
      for (final tag in entry.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
      final mood = entry.mood;
      if (mood != null) {
        moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
      }
    }

    final sortedTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DreamHighlights(
      totalCount: _entries.length,
      topTags: sortedTags
          .take(5)
          .map((entry) => TagFrequency(tag: entry.key, count: entry.value))
          .toList(),
      moods: sortedMoods
          .map((entry) => MoodFrequency(mood: entry.key, count: entry.value))
          .toList(),
    );
  }

  @override
  Future<DreamEntry> updateDream({
    required String id,
    String? title,
    String? transcript,
    List<String>? tags,
    String? mood,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw Exception('Dream not found');
    }
    final current = _entries[index];
    final updated = current.copyWith(
      title: title ?? current.title,
      transcript: transcript ?? current.transcript,
      summary: transcript ?? current.summary,
      tags: tags ?? current.tags,
      mood: mood ?? current.mood,
    );
    _entries[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDream(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<DreamJournalResult> generateJournal({
    required String id,
    List<String> focusPoints = const <String>[],
    String? tone,
  }) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw Exception('Dream not found');
    }
    final focus = focusPoints.isEmpty ? '' : ' Focus: ${focusPoints.join(', ')}';
    final entry = _entries[index];
    final journal = 'Journal for ${entry.title}.$focus ${tone ?? ''}'.trim();
    final updated = entry.copyWith(journal: journal, journalGeneratedAt: DateTime.now());
    _entries[index] = updated;
    return DreamJournalResult(entry: updated, narrative: journal, engine: 'stub');
  }

  @override
  Future<TranscriptionResult> transcribeAudio(Uint8List audio, {String? prompt}) async {
    final transcript = utf8.decode(audio, allowMalformed: true);
    return TranscriptionResult(transcript: transcript, engine: 'stub', confidence: 0.5);
  }
}

class StubWakeAlarmService implements WakeAlarmService {
  ScheduledAlarm? _scheduledAlarm;

  @override
  ScheduledAlarm? get scheduledAlarm => _scheduledAlarm;

  @override
  Future<void> initialise() async {}

  @override
  Future<ScheduledAlarm> scheduleAlarm({
    required TimeOfDay time,
    bool requireTranscription = true,
    String? note,
  }) async {
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final alarm = ScheduledAlarm(
      scheduledAt: scheduled,
      requireTranscription: requireTranscription,
      note: note,
    );
    _scheduledAlarm = alarm;
    return alarm;
  }

  @override
  Future<void> cancel() async {
    _scheduledAlarm = null;
  }
}

class StubVoiceRecorder implements VoiceRecorder {
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> initialise() async {}

  @override
  Future<void> start() async {
    _isRecording = true;
  }

  @override
  Future<Uint8List?> stop() async {
    if (!_isRecording) {
      return null;
    }
    _isRecording = false;
    return Uint8List(0);
  }
}

void main() {
  testWidgets('Dream capture screen renders empty state, form, and highlights',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DreamCaptureScreen(
          service: FakeDreamService(),
          alarmService: StubWakeAlarmService(),
          recorder: StubVoiceRecorder(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Dream Capture Journal'), findsOneWidget);
    expect(find.text('Wake-up alarm & voice capture'), findsOneWidget);
    expect(find.text('Voice capture'), findsOneWidget);
    expect(find.text('Save dream'), findsOneWidget);
    expect(find.text('Total dreams recorded: 0'), findsOneWidget);
    expect(
      find.text(
        'No dreams recorded yet. Save your first dream to unlock insights and narrative summaries.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Selecting a tag chip filters the rendered dreams',
      (WidgetTester tester) async {
    final seededService = FakeDreamService(
      seed: [
        DreamEntry(
          id: '1',
          title: 'Forest temple',
          transcript: 'Exploring a forest temple with glowing runes.',
          summary: 'Exploring a forest temple with glowing runes.',
          tags: const ['forest', 'temple'],
          mood: 'curious',
          createdAt: DateTime(2024, 6, 1, 6, 30),
        ),
        DreamEntry(
          id: '2',
          title: 'Ocean city',
          transcript: 'Walking through a floating city above calm seas.',
          summary: 'Walking through a floating city above calm seas.',
          tags: const ['ocean'],
          mood: 'calm',
          createdAt: DateTime(2024, 6, 2, 7, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DreamCaptureScreen(
          service: seededService,
          alarmService: StubWakeAlarmService(),
          recorder: StubVoiceRecorder(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Forest temple'), findsOneWidget);
    expect(find.text('Ocean city'), findsOneWidget);

    final forestChipFinder = find.widgetWithText(ChoiceChip, '#forest');
    expect(forestChipFinder, findsOneWidget);

    await tester.tap(forestChipFinder);
    await tester.pumpAndSettle();

    expect(find.text('Forest temple'), findsOneWidget);
    expect(find.text('Ocean city'), findsNothing);
  });
}
