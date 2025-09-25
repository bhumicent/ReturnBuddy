//
//  Receipt+CoreDataProperties.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-09-23.
//
//

import Foundation
import CoreData


extension Receipt {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Receipt> {
        return NSFetchRequest<Receipt>(entityName: "Receipt")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var invoiceNumber: String?
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var rawText: String?
    @NSManaged public var receiptImage: Data?
    @NSManaged public var returnDeadline: Date?
    @NSManaged public var storeName: String?
    @NSManaged public var total: Double
    @NSManaged public var totalAmount: Double
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension Receipt {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: Item)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: Item)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

extension Receipt : Identifiable {

}
