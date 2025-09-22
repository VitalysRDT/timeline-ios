//
//  HomeView.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showJoinDialog = false
    @State private var gameCode = ""
    @State private var animateTitle = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 80))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                        .scaleEffect(animateTitle ? 1.1 : 1.0)
                        .animation(
                            .spring(response: 2, dampingFraction: 0.5)
                            .repeatForever(autoreverses: true),
                            value: animateTitle
                        )
                    
                    Text("Timeline")
                        .font(.system(size: 50, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 10)
                    
                    Text("Placez les événements dans l'ordre chronologique")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        AudioHapticsService.shared.haptic(.medium)
                        appState.navigateTo(.solo)
                    }) {
                        HStack {
                            Image(systemName: "person.fill")
                            Text("Mode Solo")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(radius: 5)
                    }
                    
                    Button(action: {
                        AudioHapticsService.shared.haptic(.medium)
                        Task {
                            await appState.createGame(mode: .privateGame)
                        }
                    }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                            Text("Créer une partie privée")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2))
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.white, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    
                    Button(action: {
                        AudioHapticsService.shared.haptic(.heavy)
                        Task {
                            await appState.createGame(mode: .battleRoyale)
                        }
                    }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "globe")
                                Text("Battle Royale")
                                    .fontWeight(.bold)
                                Image(systemName: "flame.fill")
                            }
                            .font(.title3)
                            
                            Text("Affrontez le monde entier !")
                                .font(.caption)
                                .opacity(0.9)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                        .shadow(color: .orange.opacity(0.5), radius: 10)
                    }
                    
                    Button(action: {
                        AudioHapticsService.shared.haptic(.medium)
                        showJoinDialog = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Rejoindre une partie")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.2))
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.white, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                    
                    Button(action: {
                        AudioHapticsService.shared.haptic(.light)
                        appState.navigateTo(.settings)
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Paramètres")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(.white.opacity(0.5), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding(.horizontal, 40)
                
                // Removed recent games section as they now use 4-digit codes
                
                Spacer()
            }
        }
        .overlay(
            Group {
                if appState.isLoading {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
        )
        .alert("Rejoindre une partie", isPresented: $showJoinDialog) {
            TextField("Code à 4 chiffres", text: $gameCode)
                .keyboardType(.numberPad)
                .onChange(of: gameCode) { oldValue, newValue in
                    // Limiter à 4 chiffres
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 4 {
                        gameCode = String(filtered.prefix(4))
                    } else {
                        gameCode = filtered
                    }
                }
            
            Button("Rejoindre") {
                AudioHapticsService.shared.haptic(.medium)
                let code = gameCode  // Capturer la valeur avant de la réinitialiser
                gameCode = ""
                Task {
                    await appState.joinGame(gameId: code)
                }
            }
            .disabled(gameCode.count < 4)
            
            Button("Annuler", role: .cancel) {
                gameCode = ""
            }
        } message: {
            Text("Entrez le code à 4 chiffres pour rejoindre une partie")
        }
        .onAppear {
            animateTitle = true
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}