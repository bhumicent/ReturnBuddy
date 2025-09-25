// AddReceiptView.swift
import SwiftUI
import Vision
import CoreData
import UIKit

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
    @State private var showingScanner = false
    @State private var scannedImage: UIImage? = nil            // stored until Save
    @State private var parsedItems: [ParsedItem] = []

    // Parsed item model (temporary, not NSManagedObject)
    struct ParsedItem: Identifiable {
        let id = UUID()
        var name: String
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
                        .frame(height: 140)
                        .cornerRadius(8)
                }
            }

            Button("Scan Receipt") {
                showingScanner = true
            }
        }
        .navigationTitle("Add Receipt")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveReceipt() }
                    .disabled(storeName.trimmingCharacters(in: .whitespaces).isEmpty && scannedImage == nil)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingScanner) {
            // Use camera if available, otherwise photo library (safe for Simulator)
            ImagePicker(sourceType: UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary) { img in
                showingScanner = false
                guard let img = img else { return }
                scannedImage = img
                extractText(from: img)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Save
    private func saveReceipt() {
        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.storeName = storeName
        receipt.invoiceNumber = invoiceNumber
        receipt.purchaseDate = purchaseDate
        receipt.total = Double(totalString) ?? 0.0
        receipt.rawText = rawOCRText
        receipt.createdAt = Date()

        if let img = scannedImage, let data = img.jpegData(compressionQuality: 0.8) {
            receipt.receiptImage = data
        }

        // Add parsed items
        for p in parsedItems {
            let item = Item(context: viewContext)
            item.itemId = UUID()
            item.name = p.name
            item.quantity = p.qty
            item.price = p.price
            item.receipt = receipt
        }

        do {
            try viewContext.save()
            print("✅ Saved receipt: store=\(receipt.storeName ?? "nil") " +
                  "invoice=\(receipt.invoiceNumber ?? "nil") " +
                  "total=\(receipt.total) " +
                  "date=\(String(describing: receipt.purchaseDate)) " +
                  "items=\(receipt.items?.count ?? 0)")
            dismiss()
        } catch {
            print("❌ Failed to save receipt: \(error.localizedDescription)")
        }
    }


    // MARK: - OCR (Vision)
    private func extractText(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("No CGImage found in UIImage")
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let err = error {
                print("OCR error:", err.localizedDescription)
                return
            }

            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let lines: [String] = observations.compactMap { obs in
                obs.topCandidates(1).first?.string
            }

            print("🔍 OCR lines:\n", lines.joined(separator: "\n"))

            DispatchQueue.main.async {
                self.parseReceiptText(lines, sourceImage: image)
            }
        }


        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en_US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform Vision request:", error)
            }
        }
    }

    // MARK: - Parsing (store, date, total, items, invoice)
    private func parseReceiptText(_ lines: [String], sourceImage: UIImage?) {
        let fullText = lines.joined(separator: "\n")
        rawOCRText = fullText

        // ---- Invoice (robust labeled pattern) ----
        var invoiceFound: String? = nil
        do {
            let labeledPattern = #"(?i)(?:invoice(?:\s*(?:number|no\.?|#)?)|inv(?:oice)?(?:\s*(?:no\.?|#)?)|invoice#)\s*[:#\-\s]*([A-Za-z0-9][A-Za-z0-9\-\/_.]{0,39})"#
            let re = try NSRegularExpression(pattern: labeledPattern)
            if let m = re.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
               let r = Range(m.range(at: 1), in: fullText) {
                invoiceFound = String(fullText[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            print("Invoice regex error:", error)
        }

        // ---- Total (look for labeled totals near bottom, else largest amount) ----
        var totalFound: Double? = nil
        do {
            let totalPattern = #"(?i)(?:total|amount\s+due|balance\s+due|grand\s+total|amount)\s*[:\-]?\s*\$?\s*([0-9]{1,3}(?:[,]\d{3})*(?:\.\d{2})?)"#
            let reTotal = try NSRegularExpression(pattern: totalPattern)
            // search bottom N lines first
            let bottomCount = min(12, lines.count)
            let bottomRangeStartIndex = max(0, lines.count - bottomCount)
            let bottomLines = lines[bottomRangeStartIndex..<lines.count].joined(separator: "\n")
            if let m = reTotal.firstMatch(in: bottomLines, range: NSRange(bottomLines.startIndex..., in: bottomLines)),
               let r = Range(m.range(at: 1), in: bottomLines) {
                let s = bottomLines[r].replacingOccurrences(of: ",", with: "")
                totalFound = Double(s)
            } else {
                // fallback: find all amounts in full text and pick the largest
                let amountPattern = #"\$?\s*([0-9]{1,3}(?:[,]\d{3})*(?:\.\d{2})?)"#
                let reAmt = try NSRegularExpression(pattern: amountPattern)
                let matches = reAmt.matches(in: fullText, range: NSRange(fullText.startIndex..., in: fullText))
                var amounts: [Double] = []
                for m in matches {
                    if let r = Range(m.range(at: 1), in: fullText) {
                        let s = fullText[r].replacingOccurrences(of: ",", with: "")
                        if let v = Double(s) {
                            amounts.append(v)
                        }
                    }
                }
                totalFound = amounts.max()
            }
        } catch {
            print("Total regex error:", error)
        }

        // ---- Purchase Date (search lines labeled with Date/Purchase first, else global) ----
        var dateFound: Date? = nil
        do {
            // flexible date patterns (dd/mm/yyyy, mm/dd/yyyy, yyyy-mm-dd, Jan 23 2025, etc.)
            let datePattern = #"(?:\b(?:Date|Purchase|Trans|Txn|Time|Sale)[^\d]{0,6})?(\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{4}[\/\-.]\d{1,2}[\/\-.]\d{1,2}|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{2,4})"#
            let reDate = try NSRegularExpression(pattern: datePattern, options: .caseInsensitive)

            // prefer lines containing "date" or "purchase"
            if let labeledLine = lines.first(where: { $0.range(of: "(?i)date|purchase|trans|txn", options: .regularExpression) != nil }) {
                if let m = reDate.firstMatch(in: labeledLine, range: NSRange(labeledLine.startIndex..., in: labeledLine)),
                   let r = Range(m.range(at: 1), in: labeledLine) {
                    dateFound = tryParseDate(from: String(labeledLine[r]))
                }
            }

            // fallback - scan entire text
            if dateFound == nil {
                if let m = reDate.firstMatch(in: fullText, range: NSRange(fullText.startIndex..., in: fullText)),
                   let r = Range(m.range(at: 1), in: fullText) {
                    dateFound = tryParseDate(from: String(fullText[r]))
                }
            }
        } catch {
            print("Date regex error:", error)
        }

        // ---- Store Name: prefer top lines, look for a likely store string ----
        var storeFound: String? = nil
        let topCandidates = Array(lines.prefix(8)) // only top lines
        for line in topCandidates {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            // skip lines that look like dates or amounts or invoice labels
            if trimmed.range(of: #"\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}"#, options: .regularExpression) != nil { continue }
            if trimmed.range(of: #"\$?\s*\d{1,3}(?:[,]\d{3})*(?:\.\d{2})?"#, options: .regularExpression) != nil { continue }
            if trimmed.range(of: "(?i)invoice|inv|total|amount|tax|qty|item", options: .regularExpression) != nil { continue }

            // choose lines that look like a store: mostly letters, optionally uppercase, length > 2
            if trimmed.range(of: #"^[A-Z0-9 '&\.\-]{3,40}$"#, options: .regularExpression) != nil ||
                trimmed.range(of: #"[A-Za-z]{3,}"#, options: .regularExpression) != nil {
                storeFound = trimmed
                break
            }
        }
        // final fallback = first non-empty line
        if storeFound == nil {
            storeFound = lines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // ---- Items extraction: lines like "Milk 2 x 3.49" or "ItemName 1 @ 4.99" ----
        var parsed: [ParsedItem] = []
        do {
            let itemPattern = #"(?m)^(.{1,60}?)\s+(\d{1,3})\s*(?:x|X|@)\s*(\d+\.\d{2})\s*$"#
            let reItems = try NSRegularExpression(pattern: itemPattern)
            let matches = reItems.matches(in: fullText, range: NSRange(fullText.startIndex..., in: fullText))
            for m in matches {
                if let rName = Range(m.range(at: 1), in: fullText),
                   let rQty = Range(m.range(at: 2), in: fullText),
                   let rPrice = Range(m.range(at: 3), in: fullText) {
                    let name = String(fullText[rName]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let qty = Int16(Int(String(fullText[rQty])) ?? 1)
                    let price = Double(String(fullText[rPrice])) ?? 0.0
                    parsed.append(ParsedItem(name: name, qty: qty, price: price))
                }
            }
        } catch {
            print("Items regex error:", error)
        }

        // ---- Commit parsed results to UI state on main thread ----
        DispatchQueue.main.async {
            if let s = storeFound { self.storeName = s }
            if let inv = invoiceFound { self.invoiceNumber = inv }
            if let d = dateFound { self.purchaseDate = d }
            if let t = totalFound { self.totalString = String(format: "%.2f", t) }
            if let img = sourceImage { self.scannedImage = img }
            self.parsedItems = parsed
        }
    }

    // Try parsing a date string with many possible formats
    private func tryParseDate(from string: String) -> Date? {
        let cleaned = string.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let fmts = [
            "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd",
            "yyyy/MM/dd", "MM/dd/yyyy", "M/d/yyyy", "dd/MM/yyyy", "d/M/yyyy",
            "dd-MM-yyyy", "MM-dd-yyyy", "MMM d yyyy", "d MMM yyyy", "MMM dd yyyy",
            "MMM d, yyyy", "d MMM, yyyy", "yyyy.MM.dd", "dd.MM.yyyy",
            "MM/dd/yy", "dd/MM/yy", "MM-dd-yy", "dd-MM-yy"
        ]
        let localeCandidates: [Locale] = [Locale(identifier: "en_US_POSIX"), Locale.current, Locale(identifier: "en_GB")]
        for loc in localeCandidates {
            let df = DateFormatter()
            df.locale = loc
            for f in fmts {
                df.dateFormat = f
                if let d = df.date(from: cleaned) {
                    return d
                }
            }
            // try flexible parsing with dateStyle/ timeStyle as fallback
            let df2 = DateFormatter()
            df2.locale = loc
            df2.dateStyle = .short
            if let d = df2.date(from: cleaned) {
                return d
            }
        }
        return nil
    }
}

// MARK: - Small UIImagePicker wrapper (works in Simulator: falls back to .photoLibrary)
fileprivate struct ImagePicker: UIViewControllerRepresentable {
    enum SourceType {
        case camera, photoLibrary
    }

    var sourceType: SourceType
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}

