//
//  timelineApp.swift
//  timeline
//
//  Created by Vitalys ROUGETET--DE TROYANE on 11/09/2025.
//

import SwiftUI
import UserNotifications
import Firebase
import FirebaseAppCheck
import FirebaseMessaging


final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        configureFirebase()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                print("🔴 Notification authorization error: \(error.localizedDescription)")
            } else {
                print("🔔 Notification permission granted: \(granted)")
            }
        }
        application.registerForRemoteNotifications()
        return true
    }
    
    private func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif
        FirebaseApp.configure()
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

@main
struct TimelineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }
    
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "timeline",
              url.host == "join",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let gameId = components.queryItems?.first(where: { $0.name == "gameId" })?.value else {
            return
        }
        
        appState.pendingGameId = gameId
    }
}

