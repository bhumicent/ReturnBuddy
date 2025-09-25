//
//  ReceiptSearchView.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-09-23.
//

import SwiftUI
import CoreData

struct ReceiptSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var minPrice: String = ""
    @State private var maxPrice: String = ""
    @State private var itemName: String = ""
    @State private var itemCode: String = ""
    @State private var storeName: String = ""

    @State private var results: [Receipt] = []

    var body: some View {
        Form {
            Section(header: Text("Date Range")) {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
            }

            Section(header: Text("Price Range")) {
                TextField("Min", text: $minPrice).keyboardType(.decimalPad)
                TextField("Max", text: $maxPrice).keyboardType(.decimalPad)
            }

            Section(header: Text("Filters")) {
                TextField("Item Name", text: $itemName)
                TextField("Item Code", text: $itemCode)
                TextField("Store Name", text: $storeName)
            }

            Button("Search") {
                runSearch()
            }

            if !results.isEmpty {
                Section(header: Text("Results")) {
                    List(results, id: \.objectID) { receipt in
                        NavigationLink(destination: ReceiptDetailsView(receipt: receipt)) {
                            VStack(alignment: .leading) {
                                Text(receipt.storeName ?? "Unknown Store")
                                    .font(.headline)
                                if let d = receipt.purchaseDate {
                                    Text(d, style: .date)
                                }
                                Text(String(format: "$%.2f", receipt.total))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Search Receipts")
    }

    private func runSearch() {
        let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()

        var predicates: [NSPredicate] = []

        // Date range
        predicates.append(NSPredicate(format: "purchaseDate >= %@ AND purchaseDate <= %@", startDate as NSDate, endDate as NSDate))

        // Price range
        if let min = Double(minPrice) {
            predicates.append(NSPredicate(format: "total >= %f", min))
        }
        if let max = Double(maxPrice) {
            predicates.append(NSPredicate(format: "total <= %f", max))
        }

        // Store name
        if !storeName.isEmpty {
            predicates.append(NSPredicate(format: "storeName CONTAINS[cd] %@", storeName))
        }

        // Item filters (via relationship)
        if !itemName.isEmpty {
            predicates.append(NSPredicate(format: "ANY items.name CONTAINS[cd] %@", itemName))
        }
        if !itemCode.isEmpty {
            predicates.append(NSPredicate(format: "ANY items.code CONTAINS[cd] %@", itemCode))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            results = try viewContext.fetch(fetchRequest)
        } catch {
            print("❌ Search error: \(error.localizedDescription)")
            results = []
        }
    }
}
