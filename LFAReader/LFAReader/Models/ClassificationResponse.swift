import Foundation

/// Response from GET /api/readings/batch/{id}/status
struct ClassificationStatus: Codable {
    let batchId: Int
    let readingStatus: String?
    let readingError: String?
    let totalImages: Int
    let classifiedImages: Int
    let progress: Double

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case readingStatus = "reading_status"
        case readingError = "reading_error"
        case totalImages = "total_images"
        case classifiedImages = "classified_images"
        case progress
    }

    /// Convenience: the status string, defaulting to "idle"
    var status: String {
        readingStatus ?? "idle"
    }

    /// Convenience: progress as completed/total for UI
    var imageProgress: ClassificationProgress {
        ClassificationProgress(completed: classifiedImages, total: totalImages)
    }
}

/// Progress info for UI display
struct ClassificationProgress: Codable {
    let completed: Int
    let total: Int
}

/// Response from GET /api/readings/categories
struct CategoriesResponse: Codable {
    let categories: [String]
}
