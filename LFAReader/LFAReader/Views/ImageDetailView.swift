import SwiftUI

struct ImageDetailView: View {
    @State private var viewModel: ImageDetailViewModel
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0

    init(testImage: TestImage) {
        _viewModel = State(initialValue: ImageDetailViewModel(testImage: testImage))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                imageSection
                resultSection
                correctionSection
                patientInfoSection
                metadataSection
            }
            .padding()
        }
        .navigationTitle("Image #\(viewModel.imageId)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadImage()
        }
    }

    // MARK: - Image with zoom

    private var imageSection: some View {
        ZStack {
            if let image = viewModel.loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(zoom)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                zoom = min(max(lastZoom * value.magnification, 1.0), 5.0)
                            }
                            .onEnded { value in
                                zoom = min(max(lastZoom * value.magnification, 1.0), 5.0)
                                lastZoom = zoom
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            zoom = 1.0
                            lastZoom = 1.0
                        }
                    }
            } else if viewModel.isLoadingImage {
                ProgressView()
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(height: 250)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Classification result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Classification Result")
                .font(.headline)

            HStack {
                Text(viewModel.testImage.finalResult)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(resultColor(for: viewModel.testImage.finalResult))

                Spacer()

                if viewModel.testImage.manualCorrection != nil {
                    Label("Corrected", systemImage: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let cvResult = viewModel.testImage.cvResult {
                LabeledContent("CV Result", value: cvResult)
                    .font(.subheadline)
            }

            if let confidence = viewModel.testImage.cvConfidence {
                LabeledContent("Confidence", value: confidence)
                    .font(.subheadline)
            }

            Button {
                Task { await viewModel.reclassify() }
            } label: {
                Label("Re-classify", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.isReclassifying)
            .padding(.top, 4)

            if viewModel.isReclassifying {
                if let progress = viewModel.reclassifyProgress {
                    ProgressView(value: Double(progress.completed), total: Double(progress.total)) {
                        Text("Classifying...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } currentValueLabel: {
                        Text("\(progress.completed)/\(progress.total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("Starting classification...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = viewModel.classificationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Manual correction

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Correction")
                .font(.headline)

            Picker("Category", selection: $viewModel.selectedCorrection) {
                Text("Select...").tag("")
                ForEach(ClassificationCategory.allCases, id: \.rawValue) { category in
                    Text(category.rawValue).tag(category.rawValue)
                }
            }
            .pickerStyle(.menu)

            if let error = viewModel.correctionError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.saveCorrection() }
            } label: {
                Label("Save Correction", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.selectedCorrection.isEmpty || viewModel.isSavingCorrection)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Patient info

    @ViewBuilder
    private var patientInfoSection: some View {
        if let info = viewModel.testImage.patientInfo {
            VStack(alignment: .leading, spacing: 8) {
                Text("Patient Information")
                    .font(.headline)

                if let species = info.species { LabeledContent("Species", value: species) }
                if let age = info.age { LabeledContent("Age", value: "\(age) years") }
                if let sex = info.sex { LabeledContent("Sex", value: sex) }
                if let breed = info.breed { LabeledContent("Breed", value: breed) }
                if let zipCode = info.zipCode { LabeledContent("Zip Code", value: zipCode) }
            }
            .font(.subheadline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)

            LabeledContent("Filename", value: viewModel.testImage.originalFilename)
            LabeledContent("Size", value: formatFileSize(viewModel.testImage.fileSize))
            LabeledContent("Preprocessed", value: viewModel.testImage.isPreprocessed ? "Yes" : "No")
            LabeledContent("Created", value: viewModel.testImage.createdAt.formattedDate)
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatFileSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
