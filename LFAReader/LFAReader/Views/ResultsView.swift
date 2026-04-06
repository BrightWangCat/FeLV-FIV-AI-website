import SwiftUI

struct ResultsView: View {
    @State private var viewModel = ResultsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.batches.isEmpty {
                    ProgressView("Loading batches...")
                } else if viewModel.batches.isEmpty {
                    emptyState
                } else {
                    batchList
                }
            }
            .navigationTitle("Results")
            .task {
                await viewModel.loadBatches()
            }
            .refreshable {
                await viewModel.loadBatches()
            }
            .onDisappear {
                viewModel.stopAllPolling()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("Delete Batch?", isPresented: .constant(viewModel.deleteTargetId != nil)) {
                Button("Cancel", role: .cancel) { viewModel.deleteTargetId = nil }
                Button("Delete", role: .destructive) {
                    if let id = viewModel.deleteTargetId {
                        viewModel.deleteTargetId = nil
                        Task { await viewModel.deleteBatch(id: id) }
                    }
                }
            } message: {
                Text("Delete this batch and all its images? This cannot be undone.")
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            Text("No Results Yet")
                .font(.largeTitle.bold())

            Text("Upload and classify test strip images to see results here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Batch list

    private var batchList: some View {
        List {
            ForEach(viewModel.batches) { batch in
                Section {
                    // Title row inside the card
                    batchTitleRow(batch: batch)

                    // Classification controls (only when not yet completed)
                    if !isClassificationDone(batch) {
                        classificationRow(batch: batch)
                    }

                    // Image rows
                    ForEach(batch.images) { img in
                        NavigationLink {
                            ImageDetailView(testImage: img)
                        } label: {
                            imageRow(img)
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        viewModel.deleteTargetId = batch.id
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Batch title row (inside the card)

    private func batchTitleRow(batch: Batch) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(batch.name ?? "Batch #\(batch.id)")
                    .font(.subheadline.weight(.semibold))

                Text("\(batch.createdAt.formattedDate) · \(batch.totalImages) image\(batch.totalImages == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusBadge(batch.readingStatus)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: String?) -> some View {
        let s = status ?? "idle"
        Text(s.capitalized)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor(s).opacity(0.15), in: Capsule())
            .foregroundStyle(statusColor(s))
    }

    // MARK: - Classification row (no duplicate status text)

    @ViewBuilder
    private func classificationRow(batch: Batch) -> some View {
        let isClassifying = viewModel.classifyingBatchIds.contains(batch.id)
        let status = batch.readingStatus ?? "idle"

        if isClassifying {
            HStack {
                if let progress = viewModel.classificationProgress[batch.id] {
                    ProgressView(value: Double(progress.completed), total: Double(progress.total))
                        .frame(maxWidth: .infinity)
                    Text("\(progress.completed)/\(progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                    Text("Classifying...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Cancel", role: .destructive) {
                    Task { await viewModel.cancelClassification(batchId: batch.id) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        } else if status == "failed" {
            Button {
                Task { await viewModel.startClassification(batchId: batch.id) }
            } label: {
                Label("Retry Classification", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button {
                Task { await viewModel.startClassification(batchId: batch.id) }
            } label: {
                Label("Classify", systemImage: "cpu")
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }

    // MARK: - Image row

    private func imageRow(_ img: TestImage) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(img.originalFilename)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(img.createdAt.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(img.finalResult)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(resultColor(for: img.finalResult).opacity(0.15), in: Capsule())
                .foregroundStyle(resultColor(for: img.finalResult))
        }
    }

    // MARK: - Helpers

    private func isClassificationDone(_ batch: Batch) -> Bool {
        let status = batch.readingStatus ?? "idle"
        return status == "completed" && !viewModel.classifyingBatchIds.contains(batch.id)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": .green
        case "processing": .orange
        case "failed": .red
        default: .gray
        }
    }
}

#Preview {
    ResultsView()
}
