# Music Discord RPC

iPhoneで現在再生中の音楽情報をDiscordのRich Presenceに表示するアプリです。

## 機能

- 📱 iPhone音楽情報の取得（MPMusicPlayerController）
- 🖼️ アルバムアートワークの表示
- 🎮 Discord Rich Presence連携
- 🔄 リアルタイム自動同期
- 📍 位置情報を利用したバックグラウンド実行
- 🔍 自動サーバー検索機能

## アーキテクチャ

```
MusicManager → ContentView → RPCClient → Python Server → Discord RPC
     ↓              ↓             ↓
音楽情報取得    UI状態管理    JSON-RPC通信
```

## セットアップ

### 1. Discord Developer Portal設定

1. [Discord Developer Portal](https://discord.com/developers/applications)にアクセス
2. 新しいアプリケーションを作成
3. Client IDをコピー

### 2. Python サーバーセットアップ

```bash
cd server
pip install -r requirements.txt

# 環境変数設定
cp .env.example .env
# .envファイルを編集してAPI キーを設定
```

`.env`ファイル例：
```
DISCORD_CLIENT_ID=your_discord_client_id_here
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
```

### 3. サーバー起動

```bash
python rpc_server.py
```

### 4. iOSアプリ設定

1. Xcodeでプロジェクトを開く
2. アプリを実行
3. Apple Music権限を許可
4. 位置情報権限を許可（バックグラウンド実行用）
5. アプリが自動的にサーバーを検索

## 使用方法

### 基本的な使い方

1. PCでPythonサーバーを起動
2. iPhoneアプリを起動
3. 音楽アプリ（Apple Music等）で音楽を再生
4. 自動的にDiscordステータスが更新される

### 手動操作

- **Scan for Servers**: サーバーを手動検索
- **Update Now**: 手動でRich Presence更新
- **Clear Presence**: Discord表示をクリア

## API仕様

### JSON-RPC エンドポイント

`POST /rpc`

#### updatePresence

```json
{
  "jsonrpc": "2.0",
  "method": "updatePresence",
  "params": {
    "title": "曲名",
    "artist": "アーティスト名",
    "album": "アルバム名"
  },
  "id": 1
}
```

#### clearPresence

```json
{
  "jsonrpc": "2.0",
  "method": "clearPresence",
  "params": {},
  "id": 2
}
```

#### getStatus

```json
{
  "jsonrpc": "2.0",
  "method": "getStatus",
  "params": {},
  "id": 3
}
```

## 技術仕様

### iOS要件

- iOS 17.0以上
- Swift 5.9以上
- SwiftUI
- MediaPlayer framework
- CoreLocation framework

### 使用フレームワーク

#### iOS
- **MediaPlayer**: 音楽情報取得（MPMusicPlayerController）
- **CoreLocation**: バックグラウンド実行維持
- **Foundation**: JSON-RPC通信
- **SwiftUI**: UI構築

#### Python
- **pypresence**: Discord Rich Presence
- **Flask**: HTTPサーバー

## 制約事項

### iOS制限
- Apple Music ストリーミング楽曲（未ダウンロード）はアートワーク取得不可
- 位置情報を利用したバックグラウンド実行のため、バッテリー消費が増加する可能性
- 無料開発者アカウントでは署名が7日間で期限切れ

### ネットワーク
- iPhoneとPCが同一ネットワーク内にある必要がある
- ファイアウォール設定でポート8080を開放

## トラブルシューティング

### 音楽情報が取得できない
- Apple Musicのメディアライブラリアクセス許可を確認
- 音楽アプリで楽曲が再生中か確認

### サーバー接続エラー
- PC側のPythonサーバーが起動しているか確認
- ネットワーク接続とIPアドレスを確認
- ファイアウォール設定を確認
- 「Scan for Servers」ボタンで手動検索を実行

### Discord表示されない
- Discord Client IDが正しく設定されているか確認
- Discordの「現在のゲームを表示」設定が有効か確認

### バックグラウンド実行が停止する
- 位置情報権限が「アプリ使用中」に設定されているか確認
- iOSの省電力モードが無効か確認
- アプリがバックグラウンドで実行されているか確認

## ライセンス

MIT License