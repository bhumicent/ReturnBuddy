//// ReceiptDetailsView.swift
///

import SwiftUI

struct ReceiptDetailsView: View {
    let receipt: Receipt

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(label: Text("Store")) {
                    Text(receipt.storeName ?? "Unknown Store")
                        .font(.headline)
                }

                GroupBox(label: Text("Invoice Number")) {
                    Text(receipt.invoiceNumber ?? "N/A")
                }

                GroupBox(label: Text("Date")) {
                    if let purchaseDate = receipt.purchaseDate {
                        Text(dateFormatter.string(from: purchaseDate))
                    } else {
                        Text("No date available")
                            .foregroundColor(.secondary)
                    }
                }

                GroupBox(label: Text("Total")) {
                    if receipt.total > 0 {
                        Text(String(format: "$%.2f", receipt.total))
                            .bold()
                    } else {
                        Text("Not available")
                            .foregroundColor(.secondary)
                    }
                }

                // ✅ Items Section
                if let items = receipt.items as? Set<Item>, !items.isEmpty {
                    GroupBox(label: Text("Items")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(items), id: \.self) { item in
                                HStack {
                                    Text(item.name ?? "Unnamed")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(item.itemId?.uuidString.prefix(6) ?? "-") // short code
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "$%.2f", item.price))
                                        .bold()
                                }
                            }
                        }
                    }
                }

                // ✅ Receipt image thumbnail
                if let data = receipt.receiptImage, let uiImage = UIImage(data: data) {
                    GroupBox(label: Text("Receipt Image")) {
                        NavigationLink(destination: ImageDetailView(image: uiImage)) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .cornerRadius(8)
                        }
                    }
                }

                // ✅ Raw OCR text toggle (hidden behind disclosure)
                if let raw = receipt.rawText, !raw.isEmpty {
                    DisclosureGroup("Raw OCR Text") {
                        ScrollView(.vertical) {
                            Text(raw)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Receipt Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// ✅ Full-screen image viewer
struct ImageDetailView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
            Spacer()
            Button("Close") { dismiss() }
                .padding()
        }
    }
}

//import SwiftUI
//import CoreData
//
//struct ReceiptDetailsView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    let receipt: Receipt
//
//    private var dateFormatter: DateFormatter {
//        let df = DateFormatter()
//        df.dateStyle = .medium
//        return df
//    }
//
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 12) {
//                Group {
//                    Text(receipt.storeName ?? "Unknown Store")
//                        .font(.title2)
//                        .bold()
//
//                    HStack {
//                        if let purchaseDate = receipt.purchaseDate {
//                            Text("Purchased: \(dateFormatter.string(from: purchaseDate))")
//                        }
//                        Spacer()
//                        Text("$\(receipt.total, specifier: "%.2f")")
//                            .font(.headline)
//                    }
//                }
//                .padding(.horizontal)
//
//                Divider()
//
//                // Items section
//                VStack(alignment: .leading, spacing: 8) {
//                    HStack {
//                        Text("Items").font(.headline)
//                        Spacer()
//                        Text("\((receipt.items as? Set<Item>)?.count ?? 0) items")
//                            .foregroundColor(.secondary)
//                            .font(.subheadline)
//                    }
//                    .padding(.horizontal)
//
//                    if let itemsSet = receipt.items as? Set<Item>, !itemsSet.isEmpty {
//                        ForEach(itemsSet.sorted(by: { ($0.name ?? "") < ($1.name ?? "") }), id: \.objectID) { item in
//                            HStack(alignment: .top) {
//                                VStack(alignment: .leading, spacing: 4) {
//                                    Text(item.name ?? "Unnamed item")
//                                        .font(.body)
//                                    // show item code if attribute exists
//                                    if let code = getItemCode(item: item) {
//                                        Text(code).font(.caption).foregroundColor(.secondary)
//                                    }
//                                }
//                                Spacer()
//                                VStack(alignment: .trailing) {
//                                    Text(String(format: "$%.2f", item.price))
//                                        .font(.subheadline)
//                                    Text("x\(item.quantity)")
//                                        .font(.caption)
//                                        .foregroundColor(.secondary)
//                                }
//                            }
//                            .padding(.horizontal)
//                            .padding(.vertical, 6)
//                        }
//                    } else {
//                        Text("No line items parsed for this receipt.")
//                            .foregroundColor(.secondary)
//                            .padding(.horizontal)
//                            .padding(.vertical, 6)
//                    }
//                }
//
//                Divider()
//
//                // Raw OCR / invoice
//                VStack(alignment: .leading, spacing: 6) {
//                    if let invoice = receipt.invoiceNumber, !invoice.isEmpty {
//                        Text("Invoice: \(invoice)").font(.subheadline).padding(.horizontal)
//                    }
//
//                    if let raw = receipt.rawText, !raw.isEmpty {
//                        Section(header: Text("Raw OCR").font(.headline).padding(.horizontal)) {
//                            ScrollView {
//                                Text(raw)
//                                    .font(.caption)
//                                    .foregroundColor(.secondary)
//                                    .padding(.horizontal)
//                                    .padding(.bottom, 20)
//                            }
//                        }
//                    }
//                }
//
//            } // VStack
//            .padding(.top)
//        }
//        .navigationTitle("Receipt Details")
//    }
//
//    // Safely get item code if attribute exists
//    private func getItemCode(item: Item) -> String? {
//        // check Core Data attributes for key presence
//        let attrKeys = item.entity.attributesByName.keys
//        if attrKeys.contains("itemCode") {
//            return item.value(forKey: "itemCode") as? String
//        }
//        // other common attribute names fallback
//        if attrKeys.contains("code") {
//            return item.value(forKey: "code") as? String
//        }
//        return nil
//    }
//}
//
