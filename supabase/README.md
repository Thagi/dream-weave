# Supabase ローカル開発環境

DreamWeaveでは将来的にSupabase(PostgreSQL + Auth + Storage)を利用して夢データの永続化と同期を行う予定です。このディレクトリには、
ローカルでSupabaseスタックを起動するための設定ファイルと手順をまとめています。

## 前提条件
- [Docker](https://www.docker.com/) が起動していること
- [Supabase CLI](https://supabase.com/docs/guides/cli) v1.150.0 以降がインストール済みであること
  - macOS: `brew install supabase/tap/supabase`
  - Windows: `scoop bucket add supabase https://github.com/supabase/scoop-bucket && scoop install supabase`
  - Linux: リリースページからバイナリをダウンロードし、パスに追加してください

## セットアップ手順
1. 環境変数ファイルを作成します。
   ```bash
   cd supabase
   cp .env.example .env
   ```
   必要に応じてAPIキーやポート番号を変更してください。

2. Supabaseスタックを起動します。
   ```bash
   supabase start
   ```
   初回実行時はDockerイメージのダウンロードに時間がかかります。起動後、以下のサービスが利用可能になります。
   - API Gateway: http://localhost:54321
   - PostgreSQL: `localhost:54322`
   - Supabase Studio: http://localhost:54323

3. ステータスの確認や停止・再起動は以下のコマンドで行えます。
   ```bash
   supabase status   # 稼働状況の確認
   supabase stop     # コンテナを停止
   supabase restart  # 設定を変更した後の再起動
   ```

4. 既定の匿名キー/サービスロールキーは`.env`に記載されています。バックエンドやモバイルアプリからアクセスする際は、
   `.env`を読み込んで環境変数を設定してください。

## 既定の構成
- 設定ファイル: [`config.toml`](./config.toml)
  - APIポートやJWTシークレット、影響するスキーマ一覧を定義しています。
  - PostgreSQLの接続情報は `postgresql://postgres:postgres@localhost:54322/postgres` です。
- サービスキー: Supabase CLIのローカル実行に合わせたダミー値を設定しています。実運用時は必ず変更してください。
- 追加リダイレクトURL: Web/モバイルのローカルホストポートを想定して `3000` / `5173` / `8081` を登録済みです。

## データの初期化
- 現時点ではスキーマやテーブル定義は用意していません。バックエンド実装がPostgreSQLへ移行するタイミングで、
  マイグレーション用のSQLや`supabase/migrations/`ディレクトリを追加してください。

## トラブルシューティング
- `supabase start` 実行時に`Error: address already in use`が発生した場合は、既にポートが使用されていないか確認し、`config.toml`で
  ポート番号を調整してください。
- Dockerのメモリ不足によりサービスが停止する場合は、Docker Desktopのリソース割り当てを4GB以上に拡張してください。

今後、Supabase連携機能を実装する際はこの環境を起点にAPIキーやテーブルを整備していきます。
