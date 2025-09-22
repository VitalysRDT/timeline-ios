//
//  AuthService.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import Foundation
import FirebaseAuth
import Combine

final class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Don't setup listener until needed
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUser = user
            self?.isAuthenticated = user != nil
        }
    }
    
    /// Sign in anonymously
    func signInAnonymously() async throws {
        // Setup listener if not done
        if authStateListener == nil {
            setupAuthStateListener()
        }
        
        isLoading = true
        error = nil
        
        do {
            let result = try await Auth.auth().signInAnonymously()
            currentUser = result.user
            isAuthenticated = true
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    /// Get current user ID
    var userId: String? {
        currentUser?.uid
    }
    
    /// Sign out
    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }
}