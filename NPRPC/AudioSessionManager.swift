//
//  AudioSessionManager.swift
//  NPRPC
//
//  Created by yyyywaiwai on 2025/07/05.
//

import Foundation
import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private init() {}
    
    func setupBackgroundAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .allowAirPlay]
            )
            
            try audioSession.setActive(true)
            
            print("Background audio session configured successfully")
            
        } catch {
            print("Failed to setup background audio: \(error)")
        }
    }
    
    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false)
            print("Audio session deactivated")
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}