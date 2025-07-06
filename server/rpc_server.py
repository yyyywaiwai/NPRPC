#!/usr/bin/env python3
"""
Discord Rich Presence RPC Server
iPhone音楽情報をDiscordに表示するRPCサーバー
"""

import os
import base64
import json
import time
import threading
from io import BytesIO
from typing import Optional, Dict, Any

import requests
from PIL import Image
from flask import Flask, request, jsonify
from pypresence import Presence
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

class MusicDiscordRPC:
    def __init__(self):
        self.discord_client_id = os.getenv('DISCORD_CLIENT_ID')
        self.discord_webhook_url = os.getenv('DISCORD_WEBHOOK_URL')
        self.presence: Optional[Presence] = None
        self.current_track = {}
        self.is_connected = False
        
    def connect_discord(self):
        """Discord Rich Presenceに接続"""
        try:
            if self.presence:
                self.presence.close()
            
            self.presence = Presence(self.discord_client_id)
            self.presence.connect()
            self.is_connected = True
            print("Discord Rich Presenceに接続しました")
            return True
        except Exception as e:
            print(f"Discord接続エラー: {e}")
            self.is_connected = False
            return False
    
    def upload_to_discord(self, base64_image: str) -> Optional[str]:
        """Base64画像をDiscord WebhookでアップロードしてCDN URLを取得"""
        try:
            # Base64データをデコード
            image_data = base64.b64decode(base64_image)
            
            # PIL Imageで最適化
            image = Image.open(BytesIO(image_data))
            image = image.convert('RGB')
            
            # 300x300にリサイズ
            image = image.resize((300, 300), Image.Resampling.LANCZOS)
            
            # JPEGとして再エンコード
            output = BytesIO()
            image.save(output, format='JPEG', quality=85, optimize=True)
            optimized_data = output.getvalue()
            
            # Discord Webhookで画像アップロード
            webhook_url = os.getenv('DISCORD_WEBHOOK_URL')
            if not webhook_url:
                print("Discord Webhook URL が設定されていません")
                return None
            
            # マルチパートファイルアップロード
            files = {
                'file': ('artwork.jpg', optimized_data, 'image/jpeg')
            }
            
            # Webhookペイロード
            data = {
                'content': f'Album artwork - {int(time.time())}'
            }
            
            response = requests.post(
                webhook_url,
                data=data,
                files=files,
                timeout=15
            )
            
            if response.status_code == 200:
                result = response.json()
                # Discord CDN URLを取得
                if 'attachments' in result and len(result['attachments']) > 0:
                    attachment = result['attachments'][0]
                    return attachment['url']
                else:
                    print("Discord Webhook: 添付ファイルが見つかりません")
                    return None
            else:
                print(f"Discord Webhook エラー: {response.status_code}")
                print(f"Response: {response.text}")
                return None
                
        except Exception as e:
            print(f"Discord画像アップロードエラー: {e}")
            return None
    
    def update_presence(self, title: str, artist: str, artwork_base64: Optional[str] = None):
        """Discord Rich Presenceを更新"""
        try:
            if not self.is_connected:
                if not self.connect_discord():
                    return False
            
            # Rich Presence設定
            presence_data = {
                'details': title,
                'state': f'by {artist}',
                'start': int(time.time()),
                'large_image': 'music_icon',
                'large_text': f'{title} - {artist}'
            }
            
            self.presence.update(**presence_data)
            
            # 現在の楽曲情報を保存
            self.current_track = {
                'title': title,
                'artist': artist,
                'artwork_url': 'music_icon',
                'updated_at': time.time()
            }
            
            print(f"Rich Presence更新: {title} - {artist}")
            return True
            
        except Exception as e:
            print(f"Rich Presence更新エラー: {e}")
            self.is_connected = False
            return False
    
    def clear_presence(self):
        """Rich Presenceをクリア"""
        try:
            if self.presence and self.is_connected:
                self.presence.clear()
                self.current_track = {}
                print("Rich Presenceをクリアしました")
        except Exception as e:
            print(f"Rich Presenceクリアエラー: {e}")

# グローバルインスタンス
music_rpc = MusicDiscordRPC()

@app.route('/health', methods=['GET'])
def health_check():
    """ヘルスチェック"""
    return jsonify({
        'status': 'ok',
        'discord_connected': music_rpc.is_connected,
        'current_track': music_rpc.current_track
    })

@app.route('/discovery', methods=['GET'])
def server_discovery():
    """サーバー自動発見用エンドポイント"""
    import socket
    
    # サーバーの実際のIPアドレスを取得
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    # より正確なローカルIPを取得
    try:
        # 外部接続用のソケットを作成してローカルIPを取得
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        pass
    
    port = int(os.getenv('SERVER_PORT', 8080))
    
    return jsonify({
        'service': 'NPRPC Music Server',
        'version': '1.0.0',
        'server_url': f'http://{local_ip}:{port}',
        'endpoints': {
            'rpc': '/rpc',
            'health': '/health',
            'discovery': '/discovery'
        },
        'status': 'running',
        'discord_connected': music_rpc.is_connected
    })

@app.route('/rpc', methods=['POST'])
def handle_rpc():
    """JSON-RPC エンドポイント"""
    try:
        data = request.get_json()
        
        if not data or 'method' not in data:
            return jsonify({
                'jsonrpc': '2.0',
                'error': {'code': -32600, 'message': 'Invalid Request'},
                'id': data.get('id') if data else None
            }), 400
        
        method = data['method']
        params = data.get('params', {})
        request_id = data.get('id')
        
        if method == 'updatePresence':
            title = params.get('title', 'Unknown Title')
            artist = params.get('artist', 'Unknown Artist')
            artwork = params.get('artwork')
            
            success = music_rpc.update_presence(title, artist, artwork)
            
            return jsonify({
                'jsonrpc': '2.0',
                'result': {'success': success},
                'id': request_id
            })
        
        elif method == 'clearPresence':
            music_rpc.clear_presence()
            return jsonify({
                'jsonrpc': '2.0',
                'result': {'success': True},
                'id': request_id
            })
        
        elif method == 'getStatus':
            return jsonify({
                'jsonrpc': '2.0',
                'result': {
                    'connected': music_rpc.is_connected,
                    'current_track': music_rpc.current_track
                },
                'id': request_id
            })
        
        else:
            return jsonify({
                'jsonrpc': '2.0',
                'error': {'code': -32601, 'message': 'Method not found'},
                'id': request_id
            }), 404
    
    except Exception as e:
        return jsonify({
            'jsonrpc': '2.0',
            'error': {'code': -32603, 'message': f'Internal error: {str(e)}'},
            'id': data.get('id') if 'data' in locals() else None
        }), 500

def initialize_discord():
    """アプリ起動時にDiscordに接続"""
    music_rpc.connect_discord()

if __name__ == '__main__':
    if not music_rpc.discord_client_id:
        print("エラー: DISCORD_CLIENT_ID が設定されていません")
        exit(1)
    
    if not music_rpc.discord_webhook_url:
        print("警告: DISCORD_WEBHOOK_URL が設定されていません（アートワーク機能は無効）")
    
    # Discord接続を別スレッドで初期化
    threading.Thread(target=initialize_discord, daemon=True).start()
    
    host = os.getenv('SERVER_HOST', '0.0.0.0')
    port = int(os.getenv('SERVER_PORT', 8080))
    
    print(f"RPC Server starting on {host}:{port}")
    app.run(host=host, port=port, debug=False)