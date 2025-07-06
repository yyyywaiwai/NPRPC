# Music Discord RPC

iPhoneで現在再生中の音楽情報をDiscordのRich Presenceに表示するアプリです。

## 機能

- 📱 iPhone音楽情報の取得（MPNowPlayingInfoCenter）
- 🖼️ アルバムアートワークの表示（Base64変換・Discord Webhook連携）
- 🎮 Discord Rich Presence連携
- 🔄 リアルタイム自動同期
- 📱 Live Activity対応（iOS 16.1+）
- 🎵 Background Audio Mode対応

## アーキテクチャ

```
iPhone App (Swift/SwiftUI)
    ↓ JSON-RPC over HTTP
PC Server (Python/Flask)
    ↓ Discord IPC + Webhook
Discord Rich Presence + CDN
```

## セットアップ

### 1. Discord Developer Portal設定

1. [Discord Developer Portal](https://discord.com/developers/applications)にアクセス
2. 新しいアプリケーションを作成
3. Client IDをコピー

### 2. Discord Webhook設定

1. **Discord サーバーでWebhook作成**
   - 任意のチャンネルで設定 → 統合 → ウェブフック
   - 新しいウェブフック作成
   - アートワーク専用チャンネル推奨（例: `#music-artwork-storage`）

2. **Webhook URLをコピー**
   - 形式: `https://discord.com/api/webhooks/{id}/{token}`

### 3. Python サーバーセットアップ

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
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/your_webhook_id/your_webhook_token
SERVER_HOST=0.0.0.0
SERVER_PORT=8080
```

### 4. サーバー起動

```bash
python rpc_server.py
```

### 5. iOSアプリ設定

1. Xcodeでプロジェクトを開く
2. アプリを実行
3. Settings画面でサーバーURLを設定
4. Auto Syncを有効化

## 使用方法

### 基本的な使い方

1. PCでPythonサーバーを起動
2. iPhoneアプリを起動
3. 音楽アプリ（Apple Music等）で音楽を再生
4. 自動的にDiscordステータスが更新される

### 手動操作

- **Check Connection**: サーバー接続確認
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
    "album": "アルバム名",
    "artwork": "base64_encoded_image_data"
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

- iOS 15.0以上
- Swift 5.5以上
- SwiftUI
- MediaPlayer framework
- ActivityKit（Live Activity用）

### 使用フレームワーク

#### iOS
- **MediaPlayer**: 音楽情報取得
- **AVFoundation**: Background Audio Mode
- **ActivityKit**: Live Activity
- **URLSession**: HTTP通信

#### Python
- **pypresence**: Discord Rich Presence
- **Flask**: HTTPサーバー
- **Pillow**: 画像処理
- **requests**: Discord Webhook通信

## Discord Webhook利用の利点

### Imgur APIと比較した利点

- **外部API不要**: Discord Webhookのみで完結
- **永続性**: Discord CDNに永続保存される
- **高速配信**: Discord CDNの高速配信ネットワーク
- **無料**: 追加コストなし
- **簡単設定**: Webhook URL 1つで設定完了
- **高品質**: 8MBまでの高品質画像対応

### 画像アップロードフロー

1. iPhoneアプリがアルバムアートワークを取得
2. Base64エンコードしてPCサーバーに送信
3. PCサーバーがDiscord Webhookに画像アップロード
4. Discord CDN URLを取得
5. Rich PresenceのLarge Imageに設定

## 制約事項

### iOS制限
- Apple Music ストリーミング楽曲（未ダウンロード）はアートワーク取得不可
- iOS 18ではLive Activity更新頻度が5-15秒に制限
- Live Activityは最大8時間で自動終了

### ネットワーク
- iPhoneとPCが同一ネットワーク内にある必要がある
- ファイアウォール設定でポート8080を開放

## トラブルシューティング

### 音楽情報が取得できない
- Apple Musicのメディアライブラリアクセス許可を確認
- Background Audio Modeが有効か確認

### サーバー接続エラー
- PC側のPythonサーバーが起動しているか確認
- ネットワーク接続とIPアドレスを確認
- ファイアウォール設定を確認

### Discord表示されない
- Discord Client IDが正しく設定されているか確認
- Discord Webhook URLが正しく設定されているか確認
- Discordの「現在のゲームを表示」設定が有効か確認
- Webhookチャンネルへのアクセス権限を確認

## ライセンス

MIT License