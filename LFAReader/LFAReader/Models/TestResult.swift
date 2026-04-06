import Foundation
import SwiftUI

/// Classification categories matching the backend CV pipeline
enum ClassificationCategory: String, Codable, CaseIterable {
    case negative = "Negative"
    case positiveL = "Positive L"
    case positiveI = "Positive I"
    case positiveLI = "Positive L+I"
    case invalid = "Invalid"

    var color: Color {
        switch self {
        case .negative: .green
        case .positiveL, .positiveI, .positiveLI: .red
        case .invalid: .orange
        }
    }
}

/// Returns the display color for a classification result string.
func resultColor(for result: String) -> Color {
    if let category = ClassificationCategory(rawValue: result) {
        return category.color
    }
    return .secondary
}

/// Represents a single test image and its classification result
struct TestImage: Codable, Identifiable {
    let id: Int
    let batchId: Int
    let originalFilename: String
    let storedFilename: String
    let fileSize: Int
    let isPreprocessed: Bool
    var cvResult: String?
    var cvConfidence: String?
    var manualCorrection: String?
    var patientInfo: PatientInfo?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case batchId = "batch_id"
        case originalFilename = "original_filename"
        case storedFilename = "stored_filename"
        case fileSize = "file_size"
        case isPreprocessed = "is_preprocessed"
        case cvResult = "cv_result"
        case cvConfidence = "cv_confidence"
        case manualCorrection = "manual_correction"
        case patientInfo = "patient_info"
        case createdAt = "created_at"
    }

    /// The final result: manual correction takes priority over CV result
    var finalResult: String {
        manualCorrection ?? cvResult ?? "Unclassified"
    }
}

/// Patient metadata attached to a test image
struct PatientInfo: Codable, Identifiable {
    let id: Int
    var species: String?
    var age: String?
    var sex: String?
    var breed: String?
    var zipCode: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, species, age, sex, breed
        case zipCode = "zip_code"
        case createdAt = "created_at"
    }
}

/// A batch of uploaded test images
struct Batch: Codable, Identifiable {
    let id: Int
    let userId: Int
    var name: String?
    let totalImages: Int
    let createdAt: String
    var readingStatus: String?
    var classificationModel: String?
    var readingError: String?
    var images: [TestImage]

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case totalImages = "total_images"
        case createdAt = "created_at"
        case readingStatus = "reading_status"
        case classificationModel = "classification_model"
        case readingError = "reading_error"
        case images
    }
}

/// Lightweight batch info for list views
struct BatchSummary: Codable, Identifiable {
    let id: Int
    let userId: Int
    var name: String?
    let totalImages: Int
    let createdAt: String
    var username: String?
    var readingStatus: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case totalImages = "total_images"
        case createdAt = "created_at"
        case username
        case readingStatus = "reading_status"
    }
}
