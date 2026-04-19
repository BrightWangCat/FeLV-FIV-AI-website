import Foundation

/// Response from the single-image upload endpoint (POST /api/upload/single)
struct SingleUploadResponse: Codable {
    let batchId: Int
    let imageId: Int
    let patientInfo: PatientInfo?

    enum CodingKeys: String, CodingKey {
        case batchId = "batch_id"
        case imageId = "image_id"
        case patientInfo = "patient_info"
    }
}

/// Response from PUT /api/readings/image/{id}/correct
struct CorrectionResponse: Codable {
    let id: Int
    let originalFilename: String
    let cvResult: String?
    let manualCorrection: String

    enum CodingKeys: String, CodingKey {
        case id
        case originalFilename = "original_filename"
        case cvResult = "cv_result"
        case manualCorrection = "manual_correction"
    }
}
