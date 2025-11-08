# DreamWeave Mobile

Flutter client application for DreamWeave. The MVP now captures morning dreams end-to-end with
local alarm scheduling, Whisper-powered speech capture, AI-generated summaries, and a guided
editing experience. Users can highlight focus prompts, search by keyword or mood, and regenerate
long-form dream journals from the detail sheet.

## Prerequisites
- Flutter SDK 3.19 or later
- Xcode (iOS) / Android Studio + Android SDK (Android)

## Getting Started
1. Install dependencies and connect a simulator or device
   ```bash
   cd mobile
   flutter pub get
   ```
2. Ensure the FastAPI backend is running locally on port 8000.
3. Launch the mobile app
   ```bash
   flutter run --dart-define=DREAMWEAVE_API_BASE_URL=http://localhost:8000
   ```

## Key Features
- Wake-up alarm card that schedules local notifications and encourages immediate capture.
- Voice recorder with Whisper-backed transcription to append audio notes directly into the form.
- Conversation prompts, validation, and manual editing to polish each dream before saving.
- Insight card highlighting totals, motifs, and mood statistics sourced from the backend.
- Keyword/mood search controls and motif chips to slice the recent dream list.
- Detail sheet with inline editing, deletion, and one-tap dream journal regeneration.

## Testing
```bash
flutter test
```

## Project Structure
- `lib/main.dart` – Application entry point and Material theme definition.
- `lib/screens/dream_capture_screen.dart` – Dream capture form, insights, filters, and recent entries list.
- `lib/services/dream_service.dart` – HTTP client that talks to the FastAPI backend.
- `lib/models/dream_entry.dart` – DTO representing the backend response payload.
- `lib/models/dream_highlights.dart` – DTO for backend insight responses used by the insights card.
- `test/widget_test.dart` – Widget tests with a fake service for deterministic results.
- `analysis_options.yaml` – Lint rules (extends `flutter_lints`).

Use `--dart-define=DREAMWEAVE_API_BASE_URL=<https://api.example.com>` to point builds at staging
or production environments.
