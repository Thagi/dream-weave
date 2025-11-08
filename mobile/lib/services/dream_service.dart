import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/dream_entry.dart';
import '../models/dream_highlights.dart';
import '../models/dream_journal.dart';
import '../models/transcription_result.dart';

class DreamService {
  DreamService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? const String.fromEnvironment(
          'DREAMWEAVE_API_BASE_URL',
          defaultValue: 'http://localhost:8000',
        );

  final http.Client _client;
  final String _baseUrl;

  Future<List<DreamEntry>> fetchDreams({
    String? tag,
    String? query,
    String? mood,
    DateTime? start,
    DateTime? end,
    int limit = 20,
  }) async {
    var uri = Uri.parse('$_baseUrl/dreams/');
    final queryParameters = <String, String>{
      'limit': limit.toString(),
    };
    if (tag != null && tag.isNotEmpty) {
      queryParameters['tag'] = tag;
    }
    if (query != null && query.isNotEmpty) {
      queryParameters['query'] = query;
    }
    if (mood != null && mood.isNotEmpty) {
      queryParameters['mood'] = mood;
    }
    if (start != null) {
      queryParameters['start'] = start.toIso8601String();
    }
    if (end != null) {
      queryParameters['end'] = end.toIso8601String();
    }
    uri = uri.replace(queryParameters: queryParameters);

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load dreams: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    final dreams = jsonBody['dreams'] as List<dynamic>;
    return dreams
        .cast<Map<String, dynamic>>()
        .map(DreamEntry.fromJson)
        .toList(growable: false);
  }

  Future<DreamEntry> createDream({
    required String title,
    required String transcript,
    required List<String> tags,
    String? mood,
  }) async {
    final uri = Uri.parse('$_baseUrl/dreams/');
    final payload = <String, dynamic>{
      'title': title,
      'transcript': transcript,
      'tags': tags,
      'mood': mood,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create dream: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return DreamEntry.fromJson(jsonBody);
  }

  Future<DreamHighlights> fetchHighlights() async {
    final uri = Uri.parse('$_baseUrl/dreams/highlights');
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load highlights: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return DreamHighlights.fromJson(jsonBody);
  }

  Future<DreamEntry> updateDream({
    required String id,
    String? title,
    String? transcript,
    List<String>? tags,
    String? mood,
  }) async {
    final uri = Uri.parse('$_baseUrl/dreams/$id');
    final payload = <String, dynamic>{};
    if (title != null) {
      payload['title'] = title;
    }
    if (transcript != null) {
      payload['transcript'] = transcript;
    }
    if (tags != null) {
      payload['tags'] = tags;
    }
    if (mood != null) {
      payload['mood'] = mood;
    }

    final response = await _client.put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update dream: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return DreamEntry.fromJson(jsonBody);
  }

  Future<void> deleteDream(String id) async {
    final uri = Uri.parse('$_baseUrl/dreams/$id');
    final response = await _client.delete(uri);

    if (response.statusCode != 204) {
      throw Exception('Failed to delete dream: ${response.body}');
    }
  }

  Future<DreamJournalResult> generateJournal({
    required String id,
    List<String> focusPoints = const <String>[],
    String? tone,
  }) async {
    final uri = Uri.parse('$_baseUrl/dreams/$id/journal');
    final payload = <String, dynamic>{
      'focus_points': focusPoints,
      'tone': tone,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to generate journal: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return DreamJournalResult.fromJson(jsonBody);
  }

  Future<TranscriptionResult> transcribeAudio(Uint8List audio, {String? prompt}) async {
    final uri = Uri.parse('$_baseUrl/dreams/transcribe');
    final payload = <String, dynamic>{
      'audio_base64': base64Encode(audio),
      'prompt': prompt,
    };

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to transcribe audio: ${response.body}');
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    return TranscriptionResult.fromJson(jsonBody);
  }
}
