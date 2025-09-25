// ReceiptDetailsView.swift
import SwiftUI

struct ReceiptDetailsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let receipt: Receipt
    @State private var showFullImage = false
    @State private var showDeleteConfirm = false
    @State private var showRawOCR = false

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }

    var body: some View {
        List {
            
            Section(header: Text("Store")) {
                Text(receipt.storeName ?? "Unknown Store")
            }
            
            Section(header: Text("Invoice Number")) {
                Text(receipt.invoiceNumber ?? "N/A")
            }
            
            Section(header: Text("Date")) {
                if let d = receipt.purchaseDate {
                    Text(dateFormatter.string(from: d))
                } else {
                    Text("No date available")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Total")) {
                Text(String(format: "$%.2f", receipt.total))
            }
            
            // Thumbnail (if present)
            if let data = receipt.receiptImage,
               let uiImage = UIImage(data: data) {
                Section {
                    Button(action: { showFullImage = true }) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 140)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                } header: {
                    Text("Receipt Image")
                }
            }
            
            if let itemsSet = receipt.items as? Set<Item>, !itemsSet.isEmpty {
                let items = Array(itemsSet).sorted { ($0.name ?? "") < ($1.name ?? "") }
                Section(header: Text("Items")) {
                    ForEach(items) { item in
                        HStack {
                            Text(item.name ?? "Unknown")
                            Spacer()
                            Text("x\(item.quantity)")
                            Text(String(format: "$%.2f", item.price))
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                }
            }
            
            if showRawOCR {
                
                if let raw = receipt.rawText, !raw.isEmpty {
                    Section(header: Text("Raw OCR Text")) {
                        ScrollView(.vertical) {
                            Text(raw)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                        }
                        .frame(minHeight: 100)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Receipt Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showRawOCR.toggle()
                    } label: {
                        Image(systemName: showRawOCR ? "eye.slash" : "eye")
                    }

                    Button(role: .destructive) {
                        deleteReceipt()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Delete this receipt?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteReceipt()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove the receipt and any attached items.")
        }
        .fullScreenCover(isPresented: $showFullImage) {
            if let data = receipt.receiptImage,
               let uiImage = UIImage(data: data) {
                ReceiptImageView(image: uiImage, isPresented: $showFullImage)
            } else {
                // fallback
                Color.black.ignoresSafeArea()
            }
        }
    }

    private func deleteReceipt() {
        viewContext.delete(receipt)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting receipt: \(error.localizedDescription)")
        }
    }
}

// Full-screen receipt image viewer
struct ReceiptImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

