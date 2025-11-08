import 'package:flutter/material.dart';

import 'screens/dream_capture_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DreamWeaveApp());
}

class DreamWeaveApp extends StatelessWidget {
  const DreamWeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamWeave',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const DreamCaptureScreen(),
    );
  }
}
