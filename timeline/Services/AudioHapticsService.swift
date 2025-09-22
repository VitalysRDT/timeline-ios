//
//  AudioHapticsService.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import AVFoundation
import CoreHaptics
import SwiftUI
import AudioToolbox

final class AudioHapticsService: ObservableObject {
    static let shared = AudioHapticsService()
    
    @Published var soundEnabled = true
    @Published var hapticsEnabled = true
    
    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var hapticEngine: CHHapticEngine?
    
    // System Sound IDs for iOS
    private let systemSounds: [String: SystemSoundID] = [
        "success": 1057,     // Tink sound (positive)
        "error": 1053,        // Tock sound (negative)
        "tap": 1104,          // Tap sound
        "countdown": 1103,    // BeginRecording sound
        "victory": 1025,      // Fanfare/completion sound
        "elimination": 1073,  // JBL_Cancel sound
        "hint": 1113,         // BeginVideoRecording
        "placement": 1105     // Keyboard tap
    ]
    
    private init() {
        setupHaptics()
        loadSounds()
    }
    
    private func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error starting haptic engine: \(error)")
        }
    }
    
    private func loadSounds() {
        // Configuration audio session pour les sons système
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error)")
        }
    }
    
    /// Play a sound effect
    func playSound(_ name: String, volume: Float = 1.0) {
        guard soundEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            // Utiliser les sons système iOS
            if let soundID = self?.systemSounds[name] {
                AudioServicesPlaySystemSound(soundID)
            }
        }
    }
    
    /// Play system sound with vibration
    func playSystemSoundWithVibration(_ name: String) {
        guard soundEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            if let soundID = self?.systemSounds[name] {
                AudioServicesPlayAlertSound(soundID) // Joue le son + vibration
            }
        }
    }
    
    /// Trigger haptic feedback
    func haptic(_ type: HapticType) {
        guard hapticsEnabled else { return }
        
        switch type {
        case .success:
            playHapticPattern(intensity: 0.7, sharpness: 0.5, duration: 0.1)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
        case .error:
            playHapticPattern(intensity: 1.0, sharpness: 1.0, duration: 0.2)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
            
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    
    private func playHapticPattern(intensity: Float, sharpness: Float, duration: TimeInterval) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }
        
        do {
            let pattern = try CHHapticPattern(
                events: [
                    CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                        ],
                        relativeTime: 0,
                        duration: duration
                    )
                ],
                parameters: []
            )
            
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Error playing haptic pattern: \(error)")
        }
    }
    
    /// Play countdown tick
    func playCountdownTick(secondsRemaining: Int) {
        if secondsRemaining <= 5 && secondsRemaining > 0 {
            playSound("countdown", volume: 0.5)
            haptic(.light)
        } else if secondsRemaining == 0 {
            playSound("elimination", volume: 0.8)
            haptic(.error)
        }
    }
    
    /// Play card placement feedback
    func playCardPlacement(isCorrect: Bool) {
        if isCorrect {
            // Son positif + haptic
            playSound("success")
            haptic(.success)
        } else {
            // Son négatif + haptic plus fort
            playSystemSoundWithVibration("error")
            haptic(.error)
        }
    }
    
    /// Play victory fanfare
    func playVictory() {
        playSound("victory")
        haptic(.heavy)
        // Double haptic pour la victoire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.haptic(.medium)
        }
    }
    
    /// Play hint sound
    func playHintSound() {
        playSound("hint")
        haptic(.light)
    }
}

enum HapticType {
    case success
    case error
    case light
    case medium
    case heavy
    case selection
    case warning
}