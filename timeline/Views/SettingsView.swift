//
//  SettingsView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayName: String = ""
    @State private var selectedTheme = "system"
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [Color.teal.opacity(0.8), Color.green.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profil")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("Nom d'affichage", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: displayName) { oldValue, newValue in
                                    appState.playerDisplayName = newValue
                                }
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Apparence")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Picker("Thème", selection: $selectedTheme) {
                                Text("Système").tag("system")
                                Text("Clair").tag("light")
                                Text("Sombre").tag("dark")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .onChange(of: selectedTheme) { oldValue, newValue in
                                appState.userPreferredColorScheme = newValue
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Audio et Haptique")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Toggle(isOn: $appState.soundEnabled) {
                                HStack {
                                    Image(systemName: "speaker.wave.2.fill")
                                    Text("Sons")
                                }
                                .foregroundStyle(.white)
                            }
                            .tint(.green)
                            
                            Toggle(isOn: $appState.hapticsEnabled) {
                                HStack {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                    Text("Vibrations")
                                }
                                .foregroundStyle(.white)
                            }
                            .tint(.green)
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("À propos")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Version")
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text("1.0.0")
                                        .foregroundStyle(.white)
                                }
                                
                                HStack {
                                    Text("Développeur")
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text("Timeline Team")
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        Button(action: {
                            AudioHapticsService.shared.haptic(.light)
                            clearCache()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Effacer le cache")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red.opacity(0.2))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Paramètres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        AudioHapticsService.shared.haptic(.light)
                        appState.navigateTo(.home)
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            displayName = appState.playerDisplayName
            selectedTheme = appState.userPreferredColorScheme
        }
    }
    
    private func clearCache() {
        appState.lastPlayedGamesData = Data()
        AudioHapticsService.shared.haptic(.success)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}