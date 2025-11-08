class TranscriptionResult {
  TranscriptionResult({
    required this.transcript,
    required this.engine,
    required this.confidence,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      transcript: json['transcript'] as String,
      engine: json['engine'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  final String transcript;
  final String engine;
  final double confidence;
}
