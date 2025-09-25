import SwiftUI
import CoreData

struct ReceiptListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.createdAt, ascending: false)],
        animation: .default
    )
    private var receipts: FetchedResults<Receipt>

    var body: some View {
        NavigationStack {
            List {
                ForEach(receipts) { receipt in
                    NavigationLink(destination: ReceiptDetailsView(receipt: receipt)) {
                        ReceiptRow(receipt: receipt)   // ✅ moved out into its own view
                    }
                }
                .onDelete(perform: deleteReceipts)
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { addDummyReceipt() }) {
                        Label("Add Test", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                print("📦 ReceiptListView loaded with \(receipts.count) receipts")
                for r in receipts {
                    print("   ↳ store=\(r.storeName ?? "nil"), total=\(r.total), date=\(String(describing: r.purchaseDate))")
                }
            }
        }
    }

    // MARK: - Delete
    private func deleteReceipts(offsets: IndexSet) {
        withAnimation {
            offsets.map { receipts[$0] }.forEach(viewContext.delete)
            do { try viewContext.save() }
            catch { print("❌ Delete error: \(error.localizedDescription)") }
        }
    }

    // MARK: - Debug helper
    private func addDummyReceipt() {
        let r = Receipt(context: viewContext)
        r.id = UUID()
        r.storeName = "Debug Store"
        r.purchaseDate = Date()
        r.total = 42.50
        r.createdAt = Date()
        do { try viewContext.save(); print("✅ Dummy saved") }
        catch { print("❌ Dummy save error: \(error.localizedDescription)") }
    }
}

struct ReceiptRow: View {
    let receipt: Receipt
    var body: some View {
        VStack(alignment: .leading) {
            Text(receipt.storeName ?? "Unknown Store")
                .font(.headline)

            HStack {
                if let purchaseDate = receipt.purchaseDate {
                    Text(purchaseDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("$\(receipt.total, specifier: "%.2f")")
                    .font(.subheadline)
                    .bold()
            }

            // Debug row
            Text("Debug -> id: \(receipt.id?.uuidString ?? "nil")")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

