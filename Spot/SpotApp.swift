//
//  SpotApp.swift
//  Spot
//
//  Created by Surya Kukkapalli on 1/17/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct SpotApp: App {
    // Initialize Firebase in the init() of the app struct
    init() {
        FirebaseApp.configure()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
