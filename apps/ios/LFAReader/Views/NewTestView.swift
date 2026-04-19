import SwiftUI

struct NewTestView: View {
    @State private var viewModel = NewTestViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.uploadComplete {
                    successView
                } else if viewModel.selectedImage != nil {
                    reviewView
                } else {
                    sourceSelectionView
                }
            }
            .navigationTitle("New Test")
            .sheet(isPresented: $viewModel.showCamera) {
                CameraCaptureView { image in
                    viewModel.handleCapturedImage(image)
                }
            }
            .sheet(isPresented: $viewModel.showPhotoPicker) {
                PhotoPickerView(selectionLimit: 1) { images in
                    viewModel.handlePickedImages(images)
                }
            }
        }
    }

    // MARK: - Step 1: Source Selection

    private var sourceSelectionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("New Test")
                .font(.largeTitle.bold())

            Text("Capture or select a FeLV/FIV lateral flow assay image for analysis")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    viewModel.showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    viewModel.showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 2: Review & Patient Info

    private var reviewView: some View {
        Form {
            // Image preview
            if let image = viewModel.selectedImage {
                Section("Image Preview") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Patient info
            PatientInfoFormView(
                shareInfo: $viewModel.shareInfo,
                species: $viewModel.species,
                age: $viewModel.age,
                sex: $viewModel.sex,
                breed: $viewModel.breed,
                zipCode: $viewModel.zipCode
            )

            // Error
            if let error = viewModel.uploadError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            // Actions
            Section {
                Button {
                    Task { await viewModel.upload() }
                } label: {
                    Label("Upload", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isUploading)

                Button("Retake / Re-select", role: .destructive) {
                    viewModel.reset()
                }
                .disabled(viewModel.isUploading)
            }
        }
        .overlay {
            if viewModel.isUploading {
                UploadProgressView(message: "Uploading image...")
            }
        }
    }

    // MARK: - Step 3: Success

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Upload Successful")
                .font(.title2.bold())

            if let result = viewModel.uploadResult {
                VStack(spacing: 4) {
                    Text("Batch ID: \(result.batchId)")
                    Text("Image ID: \(result.imageId)")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Label("New Test", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    NewTestView()
}
