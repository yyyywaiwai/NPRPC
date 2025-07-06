//
//  MusicManager.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import Foundation
import MediaPlayer
import UIKit

@MainActor
class MusicManager: ObservableObject {
    @Published var currentTrack: MusicTrack?
    @Published var isPlaying = false
    @Published var isConnected = false
    
    private var timer: Timer?
    
    init() {
        requestMediaLibraryPermission()
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    func requestMediaLibraryPermission() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Media library access granted")
                case .denied, .restricted:
                    print("Media library access denied")
                case .notDetermined:
                    print("Media library access not determined")
                @unknown default:
                    print("Unknown media library authorization status")
                }
            }
        }
    }
    
    func startMonitoring() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Enable notifications for the music player
        musicPlayer.beginGeneratingPlaybackNotifications()
        
        updateCurrentTrack()
        
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateCurrentTrack()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.updateCurrentTrack()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.updateCurrentTrack()
            }
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        NotificationCenter.default.removeObserver(self)
        
        // Stop generating notifications
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.endGeneratingPlaybackNotifications()
    }
    
    func updateCurrentTrack() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        guard let nowPlayingItem = musicPlayer.nowPlayingItem else {
            currentTrack = nil
            isPlaying = false
            return
        }
        
        let title = nowPlayingItem.title ?? "Unknown Title"
        let artist = nowPlayingItem.artist ?? "Unknown Artist"
        let album = nowPlayingItem.albumTitle ?? "Unknown Album"
        
        var artworkBase64: String?
        if let artwork = nowPlayingItem.artwork {
            let artworkImage = artwork.image(at: CGSize(width: 300, height: 300))
            if let compressedImageData = compressImageToJPEG(artworkImage) {
                artworkBase64 = compressedImageData.base64EncodedString()
            }
        }
        
        let playbackState = musicPlayer.playbackState
        isPlaying = playbackState == .playing
        
        let newTrack = MusicTrack(
            title: title,
            artist: artist,
            album: album,
            artworkBase64: artworkBase64,
            isPlaying: isPlaying
        )
        
        // 常に最新の情報に更新（アートワークの変更も含む）
        currentTrack = newTrack
    }
    
    private func compressImageToJPEG(_ image: UIImage?, quality: CGFloat = 0.7) -> Data? {
        guard let image = image else { return nil }
        
        // 最適なサイズにリサイズ
        let targetSize = CGSize(width: 512, height: 512)
        let resizedImage = resizeImage(image, to: targetSize)
        
        // JPEG圧縮
        return resizedImage.jpegData(compressionQuality: quality)
    }
    
    private func resizeImage(_ image: UIImage, to targetSize: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: targetSize)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: rect)
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}

struct MusicTrack: Equatable {
    let title: String
    let artist: String
    let album: String
    let artworkBase64: String?
    let isPlaying: Bool
    
    static func == (lhs: MusicTrack, rhs: MusicTrack) -> Bool {
        return lhs.title == rhs.title &&
               lhs.artist == rhs.artist &&
               lhs.album == rhs.album &&
               lhs.isPlaying == rhs.isPlaying
    }
}