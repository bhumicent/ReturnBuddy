//
//  Item+CoreDataProperties.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-09-23.
//
//

import Foundation
import CoreData


extension Item {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Item> {
        return NSFetchRequest<Item>(entityName: "Item")
    }

    @NSManaged public var itemCode: String?
    @NSManaged public var itemId: UUID?
    @NSManaged public var name: String?
    @NSManaged public var price: Double
    @NSManaged public var quantity: Int16
    @NSManaged public var receipt: Receipt?

}

extension Item : Identifiable {

}
