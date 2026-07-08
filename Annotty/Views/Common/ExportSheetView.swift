import SwiftUI

/// Export sheet for selecting export formats and triggering export
struct ExportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CanvasViewModel

    @State private var exportPNG = true
    @State private var exportCOCO = true
    @State private var exportYOLO = true
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var showingShareSheet = false
    @State private var exportedURLs: [URL] = []
    @State private var showingErrorAlert = false
    @State private var exportErrorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Format selection
                VStack(alignment: .leading, spacing: 16) {
                    Text("Export Formats")
                        .font(.headline)

                    Toggle(isOn: $exportPNG) {
                        HStack {
                            Image(systemName: "photo")
                            Text("PNG Mask")
                        }
                    }

                    Toggle(isOn: $exportCOCO) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("COCO JSON")
                        }
                    }

                    Toggle(isOn: $exportYOLO) {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                            Text("YOLO-seg TXT")
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)

                // Export button
                Button(action: performExport) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "Exporting..." : "Export")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canExport ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canExport || isExporting)

                if exportComplete {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Export complete!")
                    }

                    Button("Share Files") {
                        showingShareSheet = true
                    }
                }

                Spacer()

                // Info text
                Text("Files will be saved to the labels/ folder")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(24)
            .navigationTitle("Export Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if !exportedURLs.isEmpty {
                    ShareSheet(items: exportedURLs)
                }
            }
            .alert("Export Failed", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
        }
    }

    private var canExport: Bool {
        exportPNG || exportCOCO || exportYOLO
    }

    private func performExport() {
        exportComplete = false
        exportedURLs = []
        exportErrorMessage = ""
        isExporting = true

        var formats = Set<ExportFormat>()
        if exportPNG { formats.insert(.png) }
        if exportCOCO { formats.insert(.coco) }
        if exportYOLO { formats.insert(.yolo) }

        do {
            let snapshot = try viewModel.makeCurrentExportSnapshot(formats: formats)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let urls = try ExportService.shared.export(
                        masks: snapshot.masks,
                        classes: snapshot.classes,
                        imageURL: snapshot.imageURL,
                        imageSize: snapshot.imageSize,
                        scaleFactor: snapshot.scaleFactor,
                        formats: snapshot.formats
                    )
                    let existingURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }

                    DispatchQueue.main.async {
                        isExporting = false
                        exportedURLs = existingURLs
                        exportComplete = !existingURLs.isEmpty

                        if existingURLs.isEmpty {
                            exportErrorMessage = "Export finished, but no files were created."
                            showingErrorAlert = true
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        isExporting = false
                        exportComplete = false
                        exportedURLs = []
                        exportErrorMessage = error.localizedDescription
                        showingErrorAlert = true
                    }
                }
            }
        } catch {
            isExporting = false
            exportComplete = false
            exportedURLs = []
            exportErrorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}

/// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    ExportSheetView(viewModel: CanvasViewModel())
}
