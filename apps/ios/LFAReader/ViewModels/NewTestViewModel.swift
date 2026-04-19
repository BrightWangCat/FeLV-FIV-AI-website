import Foundation
import UIKit

@Observable
class NewTestViewModel {
    // MARK: - Image source

    var showCamera = false
    var showPhotoPicker = false

    // MARK: - Selected image

    var selectedImage: UIImage?

    // MARK: - Patient info

    var shareInfo = false
    var species = ""
    var age = ""
    var sex = ""
    var breed = ""
    var zipCode = ""

    // MARK: - Upload state

    var isUploading = false
    var uploadError: String?
    var uploadComplete = false
    var uploadResult: SingleUploadResponse?

    private let api = APIClient.shared

    // MARK: - Image selection

    func handleCapturedImage(_ image: UIImage) {
        selectedImage = image
    }

    func handlePickedImages(_ images: [UIImage]) {
        guard let first = images.first else { return }
        selectedImage = first
    }

    // MARK: - Upload

    @MainActor
    func upload() async {
        guard let image = selectedImage,
              let data = image.jpegData(compressionQuality: 0.85) else {
            uploadError = "No image selected"
            return
        }

        isUploading = true
        uploadError = nil

        let filename = "photo_\(Int(Date().timeIntervalSince1970)).jpg"

        do {
            uploadResult = try await api.uploadSingle(
                imageData: data,
                filename: filename,
                shareInfo: shareInfo,
                species: shareInfo ? species : nil,
                age: shareInfo ? age : nil,
                sex: shareInfo ? sex : nil,
                breed: shareInfo ? breed : nil,
                zipCode: shareInfo ? zipCode : nil
            )
            uploadComplete = true
        } catch {
            uploadError = error.localizedDescription
        }

        isUploading = false
    }

    // MARK: - Reset

    func reset() {
        selectedImage = nil
        shareInfo = false
        species = ""
        age = ""
        sex = ""
        breed = ""
        zipCode = ""
        isUploading = false
        uploadError = nil
        uploadComplete = false
        uploadResult = nil
    }
}
