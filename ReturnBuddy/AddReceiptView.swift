import SwiftUI
import Vision
import CoreData
import PhotosUI

struct AddReceiptView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var storeName: String = ""
    @State private var purchaseDate: Date = Date()
    @State private var totalString: String = ""
    @State private var invoiceNumber: String = ""
    @State private var rawOCRText: String = ""

    // Scanning / parsed items
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var scannedImage: UIImage? = nil
    @State private var parsedItems: [ParsedItem] = []

    // Temporary parsed item model
    struct ParsedItem: Identifiable {
        let id = UUID()
        var name: String
        var code: String?
        var qty: Int16
        var price: Double
    }

    var body: some View {
        Form {
            Section(header: Text("Receipt Details")) {
                TextField("Store Name", text: $storeName)
                TextField("Invoice Number", text: $invoiceNumber)
                DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                TextField("Total", text: $totalString)
                    .keyboardType(.decimalPad)
            }

            if !parsedItems.isEmpty {
                Section(header: Text("Parsed Items")) {
                    ForEach(parsedItems) { item in
                        HStack {
                            Text(item.name)
                            if let code = item.code {
                                Text("(\(code))")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("x\(item.qty)")
                            Text(String(format: "$%.2f", item.price))
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                    }
                }
            }

            if let img = scannedImage {
                Section(header: Text("Scanned Image")) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .cornerRadius(8)
                }
            }

            Section {
                Button("Scan with Camera") { showingCamera = true }
                Button("Pick from Gallery") { showingImagePicker = true }
            }
        }
        .navigationTitle("Add Receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveReceipt() }
                    .disabled(scannedImage == nil)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $scannedImage) { img in
                if let ui = img { extractText(from: ui) }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(image: $scannedImage) { img in
                if let ui = img { extractText(from: ui) }
            }
        }
    }

    // MARK: - Save
    private func saveReceipt() {
        guard let img = scannedImage else { return }

        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.createdAt = Date()
        receipt.storeName = storeName
        receipt.invoiceNumber = invoiceNumber
        receipt.purchaseDate = purchaseDate
        receipt.total = Double(totalString) ?? 0.0
        receipt.rawText = rawOCRText

        if let data = img.jpegData(compressionQuality: 0.8) {
            receipt.receiptImage = data
        }

        // Add parsed items as Item managed objects
        for p in parsedItems {
            let item = Item(context: viewContext)
            item.itemId = UUID()
            item.name = p.name
            item.itemCode = p.code
            item.quantity = p.qty
            item.price = p.price
            item.receipt = receipt
        }

        do {
            try viewContext.save()
            print("✅ Saved receipt: store=\(receipt.storeName ?? "?") total=\(receipt.total) createdAt=\(receipt.createdAt?.description ?? "nil") items=\(parsedItems.count)")
            dismiss()
        } catch {
            print("❌ Failed to save receipt: \(error.localizedDescription)")
        }
    }

    // MARK: - OCR
    private func extractText(from image: UIImage) {
        guard let cg = image.cgImage else { return }

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let request = VNRecognizeTextRequest { req, err in
            guard err == nil else {
                print("OCR error:", err!.localizedDescription)
                return
            }
            let observations = req.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            parseReceiptText(lines, sourceImage: image)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en_US"]

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Parsing
    private func parseReceiptText(_ lines: [String], sourceImage: UIImage?) {
        let combined = lines.joined(separator: "\n")
        print("📝 OCR text:\n\(combined)")
        rawOCRText = combined

        // Invoice
        if let re = try? NSRegularExpression(pattern: #"(?i)(?:invoice(?:\s*(?:number|no\.?|#)?)|inv(?:oice)?(?:\s*(?:no\.?|#)?)|invoice#)\s*[:#\-\s]*([A-Za-z0-9][A-Za-z0-9\-\/_.]{0,39})"#) {
            if let m = re.firstMatch(in: combined, range: NSRange(combined.startIndex..., in: combined)),
               let r = Range(m.range(at: 1), in: combined) {
                invoiceNumber = String(combined[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Totals: pick largest amount
        let amountPattern = #"\$?\d{1,3}(?:,\d{3})*(?:\.\d{2})"#
        var amounts: [Double] = []
        if let re = try? NSRegularExpression(pattern: amountPattern) {
            let matches = re.matches(in: combined, range: NSRange(combined.startIndex..., in: combined))
            for m in matches {
                if let r = Range(m.range, in: combined) {
                    var s = String(combined[r])
                    s = s.replacingOccurrences(of: "$", with: "")
                    s = s.replacingOccurrences(of: ",", with: "")
                    if let v = Double(s) { amounts.append(v) }
                }
            }
        }
        if let maxAmount = amounts.max() {
            totalString = String(format: "%.2f", maxAmount)
        }

        // Items
        var parsed: [ParsedItem] = []
        do {
            // pattern 1: code + name + optional price
            let p1 = #"(?m)^\s*(\d{3,12})\s+(.{2,40}?)(?:\s+(\d+(?:[.,]\d{2})))?\s*$"#
            let re1 = try NSRegularExpression(pattern: p1)
            let matches1 = re1.matches(in: combined, range: NSRange(combined.startIndex..., in: combined))
            for m in matches1 {
                if let rCode = Range(m.range(at: 1), in: combined),
                   let rName = Range(m.range(at: 2), in: combined) {
                    let code = String(combined[rCode]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = String(combined[rName]).trimmingCharacters(in: .whitespacesAndNewlines)
                    var price: Double = 0.0
                    if m.numberOfRanges >= 4, let rPrice = Range(m.range(at: 3), in: combined) {
                        var pr = String(combined[rPrice]).replacingOccurrences(of: ",", with: ".")
                        price = Double(pr) ?? 0.0
                    }
                    parsed.append(ParsedItem(name: name, code: code, qty: 1, price: price))
                }
            }

            // pattern 2: NAME qty x price
            let p2 = #"(?m)^(.{1,60}?)\s+(\d{1,3})\s*(?:x|X|@)\s*(\d+(?:[.,]\d{2})?)\s*$"#
            let re2 = try NSRegularExpression(pattern: p2)
            let matches2 = re2.matches(in: combined, range: NSRange(combined.startIndex..., in: combined))
            for m in matches2 {
                if let rName = Range(m.range(at: 1), in: combined),
                   let rQty = Range(m.range(at: 2), in: combined),
                   let rPrice = Range(m.range(at: 3), in: combined) {
                    let name = String(combined[rName]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let qty = Int16(Int(String(combined[rQty])) ?? 1)
                    var pr = String(combined[rPrice]).replacingOccurrences(of: ",", with: ".")
                    let price = Double(pr) ?? 0.0
                    parsed.append(ParsedItem(name: name, code: nil, qty: qty, price: price))
                }
            }
        } catch {
            print("❌ Items regex error:", error)
        }

        DispatchQueue.main.async {
            if let img = sourceImage { self.scannedImage = img }
            self.parsedItems = parsed
            if storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let first = lines.first, !first.isEmpty { self.storeName = first }
            }
        }
    }
}

