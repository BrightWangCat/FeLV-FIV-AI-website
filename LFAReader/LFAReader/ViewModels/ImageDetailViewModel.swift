import Foundation
import UIKit

@Observable
class ImageDetailViewModel {
    let imageId: Int
    var testImage: TestImage
    var loadedImage: UIImage?
    var isLoadingImage = false
    var isSavingCorrection = false
    var selectedCorrection: String
    var isReclassifying = false
    var reclassifyProgress: ClassificationProgress?

    // Separate error fields so they don't interfere
    var classificationError: String?
    var correctionError: String?

    private let api = APIClient.shared

    init(testImage: TestImage) {
        self.imageId = testImage.id
        self.testImage = testImage
        self.selectedCorrection = testImage.manualCorrection ?? testImage.cvResult ?? ""
    }

    @MainActor
    func loadImage() async {
        isLoadingImage = true

        if let cached = await ImageCache.shared.image(for: imageId) {
            loadedImage = cached
            isLoadingImage = false
            return
        }

        do {
            let data = try await api.fetchImageData(imageId: imageId)
            if let image = UIImage(data: data) {
                await ImageCache.shared.store(image, for: imageId)
                loadedImage = image
            }
        } catch {
            classificationError = error.localizedDescription
        }

        isLoadingImage = false
    }

    @MainActor
    func reclassify() async {
        guard !isReclassifying else { return }

        let batchId = testImage.batchId
        isReclassifying = true
        reclassifyProgress = nil
        classificationError = nil

        do {
            try await api.startClassification(batchId: batchId)
            // Poll until done
            while true {
                try await Task.sleep(for: .seconds(2))
                let status = try await api.fetchClassificationStatus(batchId: batchId)
                reclassifyProgress = status.imageProgress
                if status.status == "completed" || status.status == "failed" {
                    if status.status == "failed" {
                        classificationError = status.readingError ?? "Classification failed"
                    }
                    break
                }
            }
            // Reload the batch to get updated image data
            let batch = try await api.fetchBatch(id: batchId)
            if let updated = batch.images.first(where: { $0.id == imageId }) {
                testImage = updated
                selectedCorrection = updated.manualCorrection ?? updated.cvResult ?? ""
            }
        } catch {
            classificationError = error.localizedDescription
        }

        isReclassifying = false
        reclassifyProgress = nil
    }

    @MainActor
    func saveCorrection() async {
        guard !selectedCorrection.isEmpty, !isSavingCorrection else { return }
        isSavingCorrection = true
        correctionError = nil

        do {
            let response = try await api.correctImage(imageId: imageId, correction: selectedCorrection)
            testImage.manualCorrection = response.manualCorrection
            testImage.cvResult = response.cvResult
        } catch {
            correctionError = error.localizedDescription
        }

        isSavingCorrection = false
    }
}
