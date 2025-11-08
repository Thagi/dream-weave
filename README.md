# DreamWeave

DreamWeaveは、ユーザーが目覚めた直後に夢を音声で記録し、LLMが物語化・構造化することで「自分だけの夢世界」を可視化することを目指すスマートフォンアプリです。本リポジトリは、MVPから将来拡張までを段階的に開発するための設計情報・ドキュメントを管理します。

## プロジェクト概要
- **対象プラットフォーム**: iOS / Android（Flutter）
- **バックエンド**: FastAPI + Supabase (PostgreSQL, Storage, Auth)
- **AI連携**: OpenAI Whisper, GPT-4o mini
- **MVPスコープ**: アラーム連携、音声入力、LLMによる夢日記生成、夢リストと検索

詳細な要件は[`RDD.md`](./RDD.md)を参照してください。

## リポジトリ構成
現時点ではドキュメント中心です。実装が追加される際は以下の構造を想定しています。

```
/
├── README.md        # プロジェクト概要（本ファイル）
├── RDD.md           # 要件定義ドキュメント
├── AGENTS.md        # コーディングアシスタント向け指針
├── PLANS.md         # 実装ロードマップ
├── backend/         # FastAPI サービス
├── mobile/          # Flutter アプリ
└── docs/            # 補助ドキュメント
```

## 開発の進め方
1. **要件の確認**: RDD.mdでMVP要件（F-1〜F-8, F-17, F-18）を確認します。
2. **タスク計画**: PLANS.mdを更新して、スプリント／タスクレベルに落とし込みます。
3. **実装とレビュー**: AGENTS.mdのガイドラインに従って、テスト・ドキュメンテーションを揃えたPRを作成します。
4. **継続的改善**: 改善アイデアは`IMPROVEMENTS.md`へ追記し、優先度を議論します。

## 開発環境のヒント
- Flutter: `>=3.19` を想定。`mobile/`配下で`flutter run`/`flutter test`を実行。
- FastAPI: Python 3.11, Poetry または uvによる依存管理を推奨。`backend/`配下で`uvicorn app.main:app --reload`を想定。
- Supabase: ローカル開発にはSupabase CLIの`supabase start`を利用。
- OpenAI API: Whisper/GPT-4o miniを使用。APIキーは`.env`に保持し、Secret ManagerまたはSupabaseのSecretsで管理。

## ライセンス
未定。利用するライセンスを決定次第、本セクションを更新してください。

## 貢献方法
- Issue / Discussionで質問や提案を歓迎します。
- PRは小さく保ち、テストとドキュメントを整えた上で提出してください。

DreamWeaveで、夢の世界を一緒に紡ぎましょう。
