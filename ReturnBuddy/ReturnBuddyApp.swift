//
//  ReturnBuddyApp.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-09-07.
//

import SwiftUI

@main
struct ReturnBuddyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(context: persistenceController.container.viewContext)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
