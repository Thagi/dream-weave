# DreamWeave リリースプレイブック

> **対象読者**: プロダクトオーナー / ノンテクニカルメンバー。モバイルアプリの実務経験がなくても、ここに記載した手順を順番に実施すればローカル検証からストア申請まで到達できることを目的にしています。

---

## 0. 全体像

1. ローカル開発環境の準備（Python + Flutter + 必要ツール）
2. バックエンドFastAPIのセットアップと動作確認
3. Supabaseプロジェクトの作成と環境変数の設定
4. OpenAI APIキーの取得・保管
5. Flutterモバイルアプリのセットアップとバックエンド接続
6. テスト／品質確認（自動テスト + 手動シナリオ）
7. バックエンドの本番ホスティング（例: Render, Fly.io, Railway など）
8. Androidリリースフロー（Google Play Console）
9. iOSリリースフロー（App Store Connect）
10. リリース後の運用タスク

各ステップには「あなたが行う作業」を明示してあります。チェックリストとして活用してください。

---

## 1. 事前準備

### 1.1 ハードウェア / OS 要件
- macOS Ventura 以降（iOSビルドにXcodeが必要なため推奨）
- メモリ16GB以上（Android Emulator + iOS Simulator併用を想定）
- ストレージ50GB以上の空き容量（XcodeやAndroid SDKが大容量のため）

### 1.2 アカウント作成
- ✅ GitHub アカウント（ソースコード管理）
- ✅ Google Cloud / Google Play Console（Androidリリース）
- ✅ Apple Developer Program（年間$99、iOSリリース）
- ✅ Supabase（PostgreSQL + Auth + Storage 用）
- ✅ OpenAI（Whisper / GPT-4o mini 利用）

### 1.3 開発ツールのインストール
- ✅ [Homebrew](https://brew.sh/)（macOS のパッケージマネージャ）
- ✅ Python 3.11（`pyenv` or `asdf` 推奨）
- ✅ [uv](https://github.com/astral-sh/uv) または `pip`
- ✅ Flutter SDK 3.19 以上（`brew install --cask flutter`）
- ✅ Xcode（App Store からインストール後、初回起動で追加コンポーネントを導入）
- ✅ Android Studio（Android SDK と AVD Manager のセットアップ）
- ✅ Supabase CLI (`brew install supabase/tap/supabase`)

---

## 2. バックエンド環境の構築

### 2.1 リポジトリ取得と仮想環境作成
```bash
# プロジェクトを取得
git clone <your-fork-or-origin>
cd dream-weave/backend

# 仮想環境
python3.11 -m venv .venv
source .venv/bin/activate

# 依存パッケージ
pip install -e .[dev]
```

### 2.2 環境変数ファイルの作成
`backend/.env` を作成し、以下のように記述します（現時点ではダミー値でOK）。
```env
OPENAI_API_KEY=sk-...
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=...
SUPABASE_SERVICE_KEY=...
```

> 🛠️ **あなたの作業**: Supabaseの管理画面とOpenAIダッシュボードからキーを取得して記入してください。キーは社内パスワードマネージャに保管しましょう。

### 2.3 ローカルでの起動確認
```bash
uvicorn app.main:app --reload
```
- `http://localhost:8000/health` が `{ "status": "ok" }` を返すこと
- `POST http://localhost:8000/dreams/` にサンプルJSONを送ると `summary` が返ること（`backend/README.md`参照）

### 2.4 自動テスト
```bash
pytest
```

> ✅ すべてのテストが成功することを確認してください。失敗した場合は依存関係やPythonバージョンを見直します。

### 2.5 既存エントリの更新・削除確認
既に登録した夢を編集・削除できるか、`curl` で動作を確認します。

```bash
# 既存エントリの更新例（タイトルはそのまま、本文のみ更新）
curl -X PUT http://localhost:8000/dreams/1 \
  -H 'Content-Type: application/json' \
  -d '{
        "transcript": "Exploring luminous caverns with glowing crystals.",
        "mood": "curious"
      }'

# エントリ削除
curl -X DELETE http://localhost:8000/dreams/1
```

レスポンスで更新内容が反映され、`DELETE` 実行後に `404` が返ることを確認してください。モバイルアプリの編集UIを実装する際の後方互換テストにも利用できます。

---

## 3. データベース（Supabase）設定

### 3.1 プロジェクト作成
1. [Supabase](https://supabase.com/) で新規プロジェクトを作成
2. リージョンはアプリ主要ユーザーに近い地域を選択
3. プロジェクト作成後、`Project Settings > API` から `URL`, `anon key`, `service_role key` を取得

### 3.2 テーブル定義（初期案）
Supabase SQL Editor に以下を貼り付けて実行してください。
```sql
create table dreams (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  transcript text not null,
  summary text not null,
  tags text[] default '{}',
  mood text,
  created_at timestamptz default timezone('utc', now())
);
```

> 🛠️ **あなたの作業**: テーブル作成後、「Table editor」でスキーマが出来ていることを確認し、必要なら行レベルセキュリティ（RLS）を有効化してください。

### 3.3 ローカルからの接続確認（任意）
Supabase CLI を使ってローカルで `supabase start` を実行すると、開発用DBをDocker上に立ち上げられます。詳しい手順はリポジトリ内
[`supabase/README.md`](../supabase/README.md) を参照し、`.env.example` をコピーした上でサービスを起動してください。起動後は
`http://localhost:54321` にAPI、`http://localhost:54323` にSupabase Studioが立ち上がります。データ構造の検証やモバイルアプリとの接続テストに便利です。

---

## 4. OpenAI Whisper / GPT 設定

1. [OpenAI](https://platform.openai.com/) で API キーを発行
2. 利用上限（Usage limit）を設定し、予期しない請求を防止
3. `.env` に保存し、アプリからは環境変数経由で参照

> 🔐 **セキュリティ**: リポジトリにキーを絶対コミットしないでください。GitGuardian などの検知サービスを有効化すると安心です。

---

## 5. Flutter モバイルアプリのセットアップ

### 5.1 依存関係の取得
```bash
cd ../mobile
flutter pub get
```

### 5.2 バックエンドとの接続
バックエンドが `http://localhost:8000` で動いている場合、以下のコマンドでアプリを起動します。
```bash
flutter run --dart-define=DREAMWEAVE_API_BASE_URL=http://localhost:8000
```

> 🛠️ **あなたの作業**: 実機テスト時は、PCとスマホが同一ネットワークに接続されていることを確認し、`http://<PCのローカルIP>:8000` を指定してください。

### 5.3 自動テスト
```bash
flutter test
```

### 5.4 手動テストシナリオ
1. アプリを起動すると「Dream Capture Journal」画面が表示される
2. タイトル・本文・タグ・ムードを入力して「Save dream」を押す
3. バックエンドからサマリーが返り、画面下部のリストに追加される
4. 画面上部のハイライトカードに合計件数と人気タグが反映されることを確認する
5. 人気タグチップをタップし、該当タグのみがリスト表示されることを確認する
6. リストアイテムをタップすると詳細シートが開き、全文とタグが表示されることを確認する
7. ネットワークを切断するとエラートーストが表示されること（失敗時挙動の確認）

---

## 6. 品質保証チェックリスト

| 項目 | 確認内容 | 担当 |
| ---- | -------- | ---- |
| 自動テスト | `pytest` / `flutter test` が通る | あなた |
| Lint | `ruff check .`, `mypy .`, `flutter analyze` | エンジニア or あなた |
| CI ステータス | GitHub Actions の `CI` ワークフローが成功している | あなた |
| UXレビュー | 実機での画面レイアウト崩れがないか | あなた + デザイナー |
| アクセシビリティ | カラーコントラスト・フォントサイズ・TalkBack対応 | デザイナー |
| セキュリティ | APIキー保護、HTTPS化、Supabase RLS | エンジニア |

---

## 7. バックエンドの本番デプロイ

> ここでは Render を例とします。Fly.io や Railway でも同様の流れです。

1. [Render](https://render.com/) でアカウント作成
2. 「New +」→「Web Service」→ GitHub リポジトリを選択
3. Build コマンド: `pip install -e .[dev]`
4. Start コマンド: `uvicorn app.main:app --host 0.0.0.0 --port 10000`
5. 環境変数タブに `.env` の値を登録（OPENAI_API_KEY など）
6. デプロイ完了後、`https://<your-service>.onrender.com/health` を確認
7. カスタムドメインを設定し、Let's Encrypt で HTTPS 化

> 🛠️ **あなたの作業**: Render と GitHub の連携、環境変数の登録、ドメイン設定を順に行ってください。

---

## 8. Android リリース手順

### 8.1 署名鍵の生成
```bash
cd mobile/android
keytool -genkey -v -keystore dreamweave-release.keystore \
  -alias dreamweave -keyalg RSA -keysize 2048 -validity 10000
```
- パスワードとキーストア情報は安全な場所に保管
- `android/key.properties` を作成
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=dreamweave
storeFile=../android/dreamweave-release.keystore
```

### 8.2 ビルド
```bash
cd ..
flutter build appbundle --release \
  --dart-define=DREAMWEAVE_API_BASE_URL=https://api.yourdomain.com
```
生成物: `build/app/outputs/bundle/release/app-release.aab`

### 8.3 Google Play Console
1. [Google Play Console](https://play.google.com/console) でアプリを作成
2. アプリ名・言語・カテゴリ・コンテンツレーティングを入力
3. 「リリース管理 > 新しいリリース」を開き、`.aab` をアップロード
4. プライバシーポリシーURLとアプリ内データの扱いを入力
5. テストトラック（内部テスト→クローズド→公開）を順に進める

> 🛠️ **あなたの作業**: ストアリスティング素材（アイコン、スクリーンショット、説明文）を用意し、審査に必要なチェック項目をすべて埋めてください。

---

## 9. iOS リリース手順

### 9.1 証明書とプロビジョニング
1. Apple Developer アカウントで「Certificates, Identifiers & Profiles」を開く
2. App ID（Bundle Identifier）を登録（例: `com.yourcompany.dreamweave`）
3. 開発用・配布用の証明書を作成し、ダウンロード
4. 「Profiles」でアドホック or App Store 配布用プロファイルを作成

### 9.2 Xcode プロジェクト設定
1. `open ios/Runner.xcworkspace`
2. `Runner` ターゲットの `Signing & Capabilities` でチームとBundle IDを設定
3. `Info.plist` のアプリ名や権限文言（マイク使用など）を更新

### 9.3 ビルドとアップロード
```bash
flutter build ipa --release \
  --dart-define=DREAMWEAVE_API_BASE_URL=https://api.yourdomain.com
```
- 出力: `build/ios/ipa/Runner.ipa`
- [Transporter](https://apps.apple.com/jp/app/transporter/id1450874784?mt=12) で App Store Connect にアップロード

### 9.4 App Store Connect
1. App Store Connect > My Apps > 新規アプリを作成
2. メタデータ（説明文、キーワード、サポートURL）を入力
3. スクリーンショットを登録（6.7", 5.5" など必要端末サイズ）
4. プライバシー情報「App Privacy」を入力
5. TestFlight 内部テスト → 外部テスト → App Store 審査の順に進める

> 🛠️ **あなたの作業**: Appleの審査ガイドライン（[App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)）を確認し、リジェクト理由を防ぎましょう。

---

## 10. リリース後の運用

| タスク | 頻度 | 内容 |
| ------ | ---- | ---- |
| モニタリング | 毎日 | Render / Supabase のダッシュボードでエラーログを確認 |
| 分析 | 週次 | 将来的には Supabase + Metabase でKPIを可視化 |
| バックアップ | 週次 | Supabase の自動バックアップ設定を確認 |
| サポート | 随時 | ユーザー問い合わせを記録し、IMPROVEMENTS.md に反映 |

---

## 付録

### A. よくある質問
- **Q. バックエンドはまだインメモリですがリリースできますか？**
  - 本番運用では Supabase への永続化が必須です。上記「3. データベース設定」を完了し、`DreamStore` を Supabase 対応実装に置き換えるタスクを開発チームに依頼してください。
- **Q. 音声入力（Whisper）はどこで設定しますか？**
  - `backend/.env` またはホスティング環境の環境変数に `OPENAI_API_KEY` を設定すると `/dreams/transcribe` エンドポイントが Whisper 経由で音声→テキスト変換を行います。キーがない場合でもフォールバックの簡易文字起こしが動作し、モバイル側の録音フローは継続できます。

### B. 追加リソース
- [Flutter リリースガイド (公式)](https://docs.flutter.dev/deployment)
- [FastAPI デプロイガイド](https://fastapi.tiangolo.com/deployment/)
- [Supabase Docs](https://supabase.com/docs)
- [Google Play Console ヘルプ](https://support.google.com/googleplay/android-developer)
- [App Store Connect ガイド](https://developer.apple.com/support/app-store-connect/)

---

このプレイブックを進める中で不明点があれば、必ずメモを残して次回アップデートに反映してください。継続的な改善により、誰が読んでも迷わずリリースできるドキュメントへ育てていきましょう。
