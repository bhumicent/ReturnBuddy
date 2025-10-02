import SwiftUI
import CoreData

struct ReceiptListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.createdAt, ascending: false)],
        animation: .default
    )
    private var receipts: FetchedResults<Receipt>

    @State private var showingAddReceipt = false
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            List {
                if receipts.isEmpty {
                    VStack(alignment: .center) {
                        Text("No receipts yet")
                            .foregroundColor(.secondary)
                        Text("Tap + to scan a receipt")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(receipts) { receipt in
                        NavigationLink(destination: ReceiptDetailsView(receipt: receipt)) {
                            ReceiptRow(receipt: receipt)
                        }
                    }
                    .onDelete(perform: deleteReceipts)
                }
            }
            .id(refreshID)
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // ✅ Open AddReceiptView
                    Button(action: { showingAddReceipt = true }) {
                        Label("Add Receipt", systemImage: "plus")
                    }

                    // Optional: Refresh button for debugging
                    Button(action: { refreshID = UUID() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddReceipt) {
                NavigationStack {
                    AddReceiptView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .onAppear {
                print("📦 ReceiptListView onAppear — receipts.count = \(receipts.count)")
                for r in receipts {
                    print("   ↳ \(r.storeName ?? "nil") total=\(r.total) createdAt=\(String(describing: r.createdAt))")
                }
            }
        }
    }

    private func deleteReceipts(offsets: IndexSet) {
        withAnimation {
            offsets.map { receipts[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
                print("🗑️ Deleted receipts, saved context")
            } catch {
                print("❌ Delete save error:", error.localizedDescription)
            }
        }
    }
}

struct ReceiptRow: View {
    let receipt: Receipt
    var body: some View {
        VStack(alignment: .leading) {
            Text(receipt.storeName ?? "Unknown Store")
                .font(.headline)

            HStack {
                if let d = receipt.purchaseDate {
                    Text(d, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("$\(receipt.total, specifier: "%.2f")")
                    .font(.subheadline).bold()
            }

            Text("Debug id: \(receipt.id?.uuidString ?? "nil")")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 6)
    }
}

