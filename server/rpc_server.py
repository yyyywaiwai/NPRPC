#!/usr/bin/env python3
"""
Discord Rich Presence RPC Server
iPhone音楽情報をDiscordに表示するRPCサーバー
"""

import os
import time
import threading
from typing import Optional, Dict, Any

from flask import Flask, request, jsonify
from pypresence import Presence
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

class MusicDiscordRPC:
    def __init__(self):
        self.discord_client_id = os.getenv('DISCORD_CLIENT_ID')
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
    
    def update_presence(self, title: str, artist: str):
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
            
            success = music_rpc.update_presence(title, artist)
            
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
    
    # Discord接続を別スレッドで初期化
    threading.Thread(target=initialize_discord, daemon=True).start()
    
    host = os.getenv('SERVER_HOST', '0.0.0.0')
    port = int(os.getenv('SERVER_PORT', 8080))
    
    print(f"RPC Server starting on {host}:{port}")
    app.run(host=host, port=port, debug=False)