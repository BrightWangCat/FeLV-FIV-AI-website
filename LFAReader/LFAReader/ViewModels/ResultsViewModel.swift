import Foundation

@Observable
class ResultsViewModel {
    var batches: [Batch] = []
    var isLoading = false
    var errorMessage: String?
    var deleteTargetId: Int?

    // Classification state per batch
    var classifyingBatchIds: Set<Int> = []
    var classificationProgress: [Int: ClassificationProgress] = [:]

    private let api = APIClient.shared
    private var pollingTasks: [Int: Task<Void, Never>] = [:]

    // MARK: - Load

    @MainActor
    func loadBatches() async {
        isLoading = true
        errorMessage = nil

        do {
            let summaries = try await api.fetchBatches()
            // Load full batch details to get images
            var loaded: [Batch] = []
            for summary in summaries {
                if let batch = try? await api.fetchBatch(id: summary.id) {
                    loaded.append(batch)
                }
            }
            batches = loaded.sorted { $0.createdAt > $1.createdAt }

            // Check if any batch is currently processing
            for batch in batches {
                if batch.readingStatus == "processing" {
                    classifyingBatchIds.insert(batch.id)
                    startPolling(batchId: batch.id)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Delete

    @MainActor
    func deleteBatch(id: Int) async {
        do {
            try await api.deleteBatch(id: id)
            stopPolling(batchId: id)
            batches.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Classification

    @MainActor
    func startClassification(batchId: Int) async {
        errorMessage = nil
        do {
            try await api.startClassification(batchId: batchId)
            classifyingBatchIds.insert(batchId)
            startPolling(batchId: batchId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func cancelClassification(batchId: Int) async {
        do {
            try await api.cancelClassification(batchId: batchId)
        } catch {
            errorMessage = error.localizedDescription
        }
        stopPolling(batchId: batchId)
        classifyingBatchIds.remove(batchId)
        classificationProgress.removeValue(forKey: batchId)
    }

    func stopAllPolling() {
        for (_, task) in pollingTasks {
            task.cancel()
        }
        pollingTasks.removeAll()
    }

    // MARK: - Polling

    @MainActor
    private func startPolling(batchId: Int) {
        stopPolling(batchId: batchId)
        pollingTasks[batchId] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self else { break }

                do {
                    let status = try await self.api.fetchClassificationStatus(batchId: batchId)

                    await MainActor.run {
                        self.classificationProgress[batchId] = status.imageProgress
                    }

                    if status.status == "completed" || status.status == "failed" {
                        if let updatedBatch = try? await self.api.fetchBatch(id: batchId) {
                            await MainActor.run {
                                if let index = self.batches.firstIndex(where: { $0.id == batchId }) {
                                    self.batches[index] = updatedBatch
                                }
                                self.classifyingBatchIds.remove(batchId)
                                self.classificationProgress.removeValue(forKey: batchId)
                            }
                        }
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                            self.classifyingBatchIds.remove(batchId)
                        }
                    }
                    break
                }
            }
        }
    }

    private func stopPolling(batchId: Int) {
        pollingTasks[batchId]?.cancel()
        pollingTasks.removeValue(forKey: batchId)
    }
}
