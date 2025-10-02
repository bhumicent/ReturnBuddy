// PersistenceController.swift
import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Replace "ReturnTracker" with your actual .xcdatamodeld name if different
        container = NSPersistentContainer(name: "ReturnBuddy")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error loading persistent stores: \(error), \(error.userInfo)")
            } else {
                print("📦 Loaded persistent store:", storeDescription.url?.absoluteString ?? "(no url)")
            }
        }

        // Very important for multi-context changes / background saves
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

