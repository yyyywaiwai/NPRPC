# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

**Music Discord RPC**は、iPhoneで再生中の音楽情報をDiscordのRich Presenceに表示するiOS + Pythonアプリです。iPhone app（Swift/SwiftUI）がPython server（Flask）経由でDiscordに音楽情報を送信します。

## ビルド・実行コマンド

### iOS App
```bash
# Xcodeプロジェクトビルド（シミュレーター）
xcodebuild -project NPRPC.xcodeproj -scheme NPRPC -destination 'platform=iOS Simulator,name=iPhone 16' build

# Xcodeプロジェクトビルド（実機）
xcodebuild -project NPRPC.xcodeproj -scheme NPRPC -destination 'generic/platform=iOS' build
```

### Python Server
```bash
cd server
pip install -r requirements.txt
python rpc_server.py
```

### 環境設定
```bash
# サーバー用.env設定
cp server/.env.example server/.env
# DISCORD_CLIENT_ID と DISCORD_WEBHOOK_URL を設定
```

## アーキテクチャ構造

### データフロー
```
MusicManager → ContentView → RPCClient → Python Server → Discord RPC
     ↓              ↓             ↓
音楽情報取得    UI状態管理    JSON-RPC通信
```

### 主要コンポーネント

**MusicManager** (`NPRPC/MusicManager.swift`)
- `MPMusicPlayerController.systemMusicPlayer`で音楽情報監視
- アルバムアートワークをBase64変換
- 2秒間隔のポーリング + NotificationCenter監視

**RPCClient** (`NPRPC/RPCClient.swift`)  
- JSON-RPC 2.0プロトコル実装（`updatePresence`, `clearPresence`, `getStatus`）
- カスタム`AnyCodable`型でJSONエンコーディング対応

**ServerDiscovery** (`NPRPC/ServerDiscovery.swift`)
- ローカルネットワーク自動スキャン（192.168.x.x, 10.0.x.x等）
- TaskGroupで並行スキャン実行

**BackgroundLocationManager** (`NPRPC/BackgroundLocationManager.swift`)
- 位置情報を利用したバックグラウンド実行維持
- Live Activity代替手段（無料開発者アカウント対応）

### プロジェクト設定の重要事項

**Background Modes**: `audio`, `background-processing`, `location`が必要
**Permission**: Apple Music (`NSAppleMusicUsageDescription`) と Location (`NSLocationWhenInUseUsageDescription`) が必須
**Deployment Target**: iOS 17.0（位置情報バックグラウンドモード要）

## 重要な実装パターン

### JSON-RPC通信実装
```swift
struct RPCRequest<T: Codable>: Codable {
    let jsonrpc = "2.0"
    let method: String
    let params: T
    let id: Int
}
```

### 音楽情報監視パターン  
```swift
// NotificationCenter + Timer併用
NotificationCenter.default.addObserver(
    forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
    object: musicPlayer,
    queue: .main
) { _ in
    Task { @MainActor in
        self.updateCurrentTrack()
    }
}
```

### ネットワーク探索パターン
```swift
// TaskGroupで並行処理
await withTaskGroup(of: Void.self) { group in
    for ip in ipAddresses {
        group.addTask {
            await self.checkServer(at: ip)
        }
    }
}
```

## Discord連携仕様

**Rich Presence更新**: `pypresence`でDiscord IPCに接続
**アートワーク表示**: Discord WebhookでCDNアップロード → Rich PresenceのLarge Image設定
**JSON-RPC通信**: `/rpc`エンドポイントでHTTP通信

## トラブルシューティング

### プロジェクト設定エラー
- Xcodeで開いている状態でproject.pbxprojを手動編集すると設定が上書きされる
- Info.plist競合時は手動作成ファイルを削除してXcode設定のみ使用

### 権限エラー
- Apple Music権限が拒否されると音楽情報取得不可
- Location権限がないとバックグラウンド実行不可

### ネットワークエラー  
- iPhone-PC間が同一ネットワーク必須
- ファイアウォールでポート8080開放必要