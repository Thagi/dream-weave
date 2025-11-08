# DreamWeave

DreamWeaveは、ユーザーが目覚めた直後に夢を音声で記録し、LLMが物語化・構造化することで「自分だけの夢世界」を可視化することを目指す
スマートフォンアプリです。本リポジトリは、MVPから将来拡張までを段階的に開発するための設計情報・ドキュメントを管理します。

## プロジェクト概要
- **対象プラットフォーム**: iOS / Android（Flutter）
- **バックエンド**: FastAPI + Supabase (PostgreSQL, Storage, Auth)
- **AI連携**: OpenAI Whisper, GPT-4o mini
- **MVPスコープ**: アラーム連携、音声入力、LLMによる夢日記生成、夢リストと検索、テキスト編集

詳細な要件は[`RDD.md`](./RDD.md)を参照してください。

## リポジトリ構成
現時点ではドキュメントと初期実装が含まれます。開発が進むにつれ、以下の構造をベースに機能を追加していきます。

```
/
├── README.md        # プロジェクト概要（本ファイル）
├── RDD.md           # 要件定義ドキュメント
├── AGENTS.md        # コーディングアシスタント向け指針
├── PLANS.md         # 実装ロードマップ
├── backend/         # FastAPI サービス（夢記録/検索/音声文字起こし/夢日記生成APIを提供）
├── mobile/          # Flutter アプリ（アラーム + 音声入力 + 編集/検索付き夢記録画面）
├── supabase/        # ローカルSupabaseスタック用の設定ファイルと手順
└── .github/workflows# CI 設定ファイル
```

### Backend: FastAPI
- エントリポイント: `backend/app/main.py`
- 依存関係・ツール定義: `backend/pyproject.toml`
- ヘルスチェック: `GET /health`
- 夢記録API: `POST /dreams/`, `GET /dreams/`, `GET /dreams/{id}`, `PUT /dreams/{id}`, `DELETE /dreams/{id}`, `GET /dreams/highlights`（タグ・キーワード検索 + インメモリ保存 + 要約/タグ自動生成）
- 音声文字起こし: `POST /dreams/transcribe`（base64エンコードした音声をWhisper/ローカルフォールバックで文字起こし）
- 夢日記生成: `POST /dreams/{id}/journal`（GPT-4o miniまたはフォールバックで物語テキストを生成し保存）
- テスト: `pytest`

### Mobile: Flutter
- エントリポイント: `mobile/lib/main.dart`
- 主要ウィジェット: `DreamCaptureScreen`（起床アラーム設定 + 音声文字起こし + 会話プロンプト + 編集/検索付き一覧 + 夢日記生成）
- テスト: `flutter test`

## セットアップガイド

### 1. Backend (FastAPI)
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
OPENAI_API_KEY=sk-... uvicorn app.main:app --reload
```

主要コマンド:
- テスト: `pytest`
- Lint: `ruff check .`
- 型チェック: `mypy .`

OpenAI APIキーが環境変数`OPENAI_API_KEY`に設定されている場合、Whisper/GPTエンドポイントが有効化されます。キーが未設定でもローカルフォールバックでテストできます。

### 2. Mobile (Flutter)
```bash
cd mobile
flutter pub get
flutter run --dart-define=DREAMWEAVE_API_BASE_URL=http://localhost:8000
```

主要コマンド:
- テスト: `flutter test`
- フォーマット: `flutter format lib`
- Lint: `flutter analyze`

FlutterアプリはHTTP経由でFastAPIの`/dreams`エンドポイントと連携します。ビルド時に
`DREAMWEAVE_API_BASE_URL`を指定して接続先を切り替えてください。

## 開発の進め方
1. **要件の確認**: RDD.mdでMVP要件（F-1〜F-8, F-17, F-18）を確認します。
2. **タスク計画**: PLANS.mdを更新して、スプリント／タスクレベルに落とし込みます。
3. **実装とレビュー**: AGENTS.mdのガイドラインに従って、テスト・ドキュメンテーションを揃えたPRを作成します。
4. **継続的改善**: 改善アイデアは`IMPROVEMENTS.md`へ追記し、優先度を議論します。

## 開発環境のヒント
- Flutter: `>=3.19` を想定。`mobile/`配下で`flutter run`/`flutter test`を実行。
- FastAPI: Python 3.11, Poetry または uvによる依存管理を推奨。`backend/`配下で`uvicorn app.main:app --reload`を想定。
- Supabase: [`supabase/README.md`](./supabase/README.md) に沿ってSupabase CLIの`supabase start`でローカルスタックを起動。`.env.example`にデフォルトキーを用意。
- OpenAI API: Whisper/GPT-4o miniを使用。APIキーは`.env`に保持し、Secret ManagerまたはSupabaseのSecretsで管理。
- CI: GitHub Actions (`.github/workflows/ci.yml`) でPythonバックエンドとFlutterクライアントのLint/テストを自動実行。

## 運用・リリースドキュメント
- [`docs/RELEASE_PLAYBOOK.md`](./docs/RELEASE_PLAYBOOK.md): プロダクトオーナー向けの詳細手順。

## ライセンス
未定。利用するライセンスを決定次第、本セクションを更新してください。

## 貢献方法
- Issue / Discussionで質問や提案を歓迎します。
- PRは小さく保ち、テストとドキュメントを整えた上で提出してください。

DreamWeaveで、夢の世界を一緒に紡ぎましょう。
