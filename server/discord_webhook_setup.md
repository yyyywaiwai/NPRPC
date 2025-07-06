# Discord Webhook設定ガイド

## Webhookの作成方法

### 1. Discord サーバーでWebhook作成

1. **Discord サーバー**で任意のチャンネルに移動
2. チャンネル設定 → **統合** → **ウェブフック**
3. **新しいウェブフック**をクリック
4. 名前を設定（例: `Music RPC Artwork`）
5. **ウェブフックURLをコピー**

### 2. 専用チャンネル推奨

- アートワーク専用の非公開チャンネルを作成することを推奨
- チャンネル名例: `#music-artwork-storage`
- このチャンネルは画像保存専用として使用

### 3. Webhook URLの形式

```
https://discord.com/api/webhooks/{webhook_id}/{webhook_token}
```

### 4. 環境変数設定

`.env`ファイルに以下を追加：

```bash
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/your_webhook_id/your_webhook_token
```

## Webhook使用時の注意点

### Discord CDN URL特徴

- **永続性**: アップロードした画像はDiscord CDNに永続保存
- **高速配信**: Discord CDNは高速で世界中に配信
- **無料**: Discord Webhookは無料で使用可能
- **制限**: ファイルサイズ上限8MB（通常のアルバムアートワークには十分）

### Rich Presenceでの表示

- Discord CDN URLは Rich Presence の `large_image` として正常に表示される
- 画像は自動的に適切なサイズにリサイズされる
- 高品質なアルバムアートワークが表示される

## トラブルシューティング

### Webhook エラー

- **404 Not Found**: Webhook URLが間違っている
- **401 Unauthorized**: Webhook トークンが無効
- **413 Payload Too Large**: ファイルサイズが8MBを超過

### 権限確認

- Webhookを作成したユーザーに十分な権限があることを確認
- チャンネルの「ファイルをアップロード」権限が必要

### ログ確認

サーバーログで以下を確認：
```
Discord Webhook エラー: {status_code}
Response: {response_text}
```