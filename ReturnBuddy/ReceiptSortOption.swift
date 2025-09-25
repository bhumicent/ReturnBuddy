//
//  ReceiptSortOption.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-09-24.
//

// ReceiptSortOption.swift
import Foundation
import CoreData

enum ReceiptSortOption: String, CaseIterable, Identifiable {
    case dateDesc = "Date (Newest First)"
    case dateAsc  = "Date (Oldest First)"
    case storeAZ  = "Store (A–Z)"
    case storeZA  = "Store (Z–A)"

    var id: String { rawValue }

    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .dateDesc:
            return [NSSortDescriptor(keyPath: \Receipt.purchaseDate, ascending: false)]
        case .dateAsc:
            return [NSSortDescriptor(keyPath: \Receipt.purchaseDate, ascending: true)]
        case .storeAZ:
            return [NSSortDescriptor(
                key: "storeName",
                ascending: true,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
            )]
        case .storeZA:
            return [NSSortDescriptor(
                key: "storeName",
                ascending: false,
                selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
            )]

        }
    }
}
