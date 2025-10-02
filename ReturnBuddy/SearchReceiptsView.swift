//
//  SearchReceiptsView.swift
//  ReturnBuddy
//
//  Created by Anuj Mistry on 2025-10-02.
//

import SwiftUI
import CoreData

struct SearchReceiptsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var query: String = ""
    @State private var results: [Item] = []

    var body: some View {
        VStack {
            TextField("Search by item name or code", text: $query)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("Search") {
                performSearch()
            }
            .padding(.bottom)

            if results.isEmpty {
                Text("No results")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(results, id: \.itemId) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unnamed")
                            .font(.headline)
                        Text("Code: \(item.itemCode ?? "N/A")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let receipt = item.receipt {
                            Text("Store: \(receipt.storeName ?? "Unknown")")
                                .font(.footnote)
                        }
                        if let purchaseDate = item.receipt?.purchaseDate {
                            Text("Date: \(purchaseDate, style: .date)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Search Receipts")
        .padding()
    }

    private func performSearch() {
        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR itemCode CONTAINS[cd] %@",
            query, query
        )

        do {
            results = try viewContext.fetch(request)
        } catch {
            print("❌ Search failed: \(error.localizedDescription)")
        }
    }
}
