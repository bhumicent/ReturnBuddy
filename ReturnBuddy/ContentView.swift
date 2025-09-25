import SwiftUI
import CoreData

// MARK: - ViewModel
class ReceiptListViewModel: ObservableObject {
    @Published var receipts: [Receipt] = []
    private var context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
        fetch(sortOption: .dateDesc)
    }

    func fetch(sortOption: ReceiptSortOption) {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        request.sortDescriptors = sortOption.sortDescriptors
        do {
            receipts = try context.fetch(request)
        } catch {
            print("❌ Fetch error: \(error.localizedDescription)")
            receipts = []
        }
    }

    func addDummyIfEmpty() {
        if receipts.isEmpty {
            let dummy = Receipt(context: context)
            dummy.storeName = "Sample Store"
            dummy.total = 12.99
            dummy.purchaseDate = Date()
            dummy.createdAt = Date()
            do {
                try context.save()
                fetch(sortOption: .dateDesc)
                print("✅ Dummy receipt added")
            } catch {
                print("❌ Error saving dummy receipt: \(error.localizedDescription)")
            }
        }
    }

    func delete(_ receipt: Receipt) {
        context.delete(receipt)
        do {
            try context.save()
            receipts.removeAll { $0.objectID == receipt.objectID }
        } catch {
            print("❌ Error deleting receipt: \(error.localizedDescription)")
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var sortOption: ReceiptSortOption = .dateDesc
    @State private var showingAddReceipt = false
    @State private var showingSearch = false

    @StateObject private var vm: ReceiptListViewModel

    init(context: NSManagedObjectContext) {
        _vm = StateObject(wrappedValue: ReceiptListViewModel(context: context))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(vm.receipts) { receipt in
                    NavigationLink(destination: ReceiptDetailsView(receipt: receipt)) {
                        HStack {
                            if let image = UIImage(named: "SampleReceipt") {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(6)
                            }

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
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { vm.receipts[$0] }.forEach { vm.delete($0) }
                }
            }
            .navigationTitle("Receipts")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // 🔍 Search button
                    Button { showingSearch = true } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                    // Sort menu
                    Menu {
                        Picker("Sort by", selection: $sortOption) {
                            ForEach(ReceiptSortOption.allCases) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }

                    // ➕ Add button
                    Button { showingAddReceipt = true } label: {
                        Label("Add Receipt", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddReceipt) {
                NavigationStack {
                    AddReceiptView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showingSearch) {
                NavigationStack {
                    ReceiptSearchView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .onChange(of: sortOption) { newValue in
                vm.fetch(sortOption: newValue)
            }
            .onAppear {
                vm.addDummyIfEmpty()
            }
        }
    }
}

