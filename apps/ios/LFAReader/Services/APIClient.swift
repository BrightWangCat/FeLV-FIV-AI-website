import Foundation

/// Errors from API calls
enum APIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, detail: String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code, let detail):
            return "Server error (\(code)): \(detail)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

#if DEBUG
/// URLSession delegate that trusts the self-signed certificate on the dev server.
/// WARNING: This bypasses TLS validation and must NEVER be used in production builds.
/// Uses the completion-handler based method for reliable callback on real devices.
final class SelfSignedCertDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
#endif

/// Centralized API client for communicating with the LFA Reader backend.
actor APIClient {
    static let shared = APIClient()

    let baseURL = "https://16.59.11.102:8080/api"

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30

        #if DEBUG
        session = URLSession(configuration: config, delegate: SelfSignedCertDelegate(), delegateQueue: nil)
        #else
        session = URLSession(configuration: config)
        #endif

        decoder = JSONDecoder()
    }

    // MARK: - Token storage (Keychain)

    private static let tokenKey = "auth_token"

    nonisolated var token: String? {
        get { KeychainService.load(key: APIClient.tokenKey) }
        set {
            if let newValue {
                KeychainService.save(key: APIClient.tokenKey, value: newValue)
            } else {
                KeychainService.delete(key: APIClient.tokenKey)
            }
        }
    }

    // MARK: - Generic request

    /// Perform a JSON-decoded request. Attaches JWT Bearer token if available.
    func request<T: Decodable>(
        _ method: String,
        path: String,
        body: Data? = nil,
        contentType: String = "application/json"
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = body
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = parseErrorDetail(from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, detail: detail)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Auth endpoints

    /// Login with username/password. Backend expects OAuth2 form-encoded body.
    func login(username: String, password: String) async throws -> TokenResponse {
        let formBody = "username=\(formEncode(username))&password=\(formEncode(password))"
        let bodyData = Data(formBody.utf8)

        let response: TokenResponse = try await request(
            "POST",
            path: "/users/login",
            body: bodyData,
            contentType: "application/x-www-form-urlencoded"
        )

        token = response.accessToken
        return response
    }

    /// Register a new user account.
    func register(username: String, email: String, password: String) async throws -> UserResponse {
        let body = RegisterRequest(email: email, username: username, password: password)
        let bodyData = try JSONEncoder().encode(body)

        return try await request("POST", path: "/users/register", body: bodyData)
    }

    /// Fetch the current user's profile.
    func fetchCurrentUser() async throws -> UserResponse {
        try await request("GET", path: "/users/me")
    }

    /// Clear stored token.
    func logout() {
        token = nil
    }

    // MARK: - Upload endpoints

    /// Upload a single image with optional patient info.
    func uploadSingle(
        imageData: Data,
        filename: String,
        shareInfo: Bool,
        species: String?,
        age: String?,
        sex: String?,
        breed: String?,
        zipCode: String?
    ) async throws -> SingleUploadResponse {
        var form = MultipartFormData()
        form.addFile(name: "file", filename: filename, mimeType: "image/jpeg", data: imageData)
        form.addField(name: "share_info", value: shareInfo ? "true" : "false")

        if shareInfo {
            if let species, !species.isEmpty { form.addField(name: "species", value: species) }
            if let age, !age.isEmpty { form.addField(name: "age", value: age) }
            if let sex, !sex.isEmpty { form.addField(name: "sex", value: sex) }
            if let breed, !breed.isEmpty { form.addField(name: "breed", value: breed) }
            if let zipCode, !zipCode.isEmpty { form.addField(name: "zip_code", value: zipCode) }
        }

        return try await uploadRequest(path: "/upload/single", form: form)
    }

    /// Upload multiple images as a batch.
    func uploadBatch(
        images: [(data: Data, filename: String)],
        batchName: String?
    ) async throws -> Batch {
        var form = MultipartFormData()
        for image in images {
            form.addFile(name: "files", filename: image.filename, mimeType: "image/jpeg", data: image.data)
        }
        if let batchName, !batchName.isEmpty {
            form.addField(name: "batch_name", value: batchName)
        }
        return try await uploadRequest(path: "/upload/batch", form: form)
    }

    /// List the current user's batches.
    func fetchBatches() async throws -> [BatchSummary] {
        try await request("GET", path: "/upload/batches")
    }

    /// Get a single batch with all its images.
    func fetchBatch(id: Int) async throws -> Batch {
        try await request("GET", path: "/upload/batch/\(id)")
    }

    /// Delete a batch and its associated files.
    func deleteBatch(id: Int) async throws {
        guard let url = URL(string: baseURL + "/upload/batch/\(id)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = parseErrorDetail(from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, detail: detail)
        }
    }

    // MARK: - Classification endpoints

    /// Start CV classification for a batch.
    func startClassification(batchId: Int) async throws {
        try await rawDataRequest("POST", path: "/readings/batch/\(batchId)/classify")
    }

    /// Poll classification progress for a batch.
    func fetchClassificationStatus(batchId: Int) async throws -> ClassificationStatus {
        try await request("GET", path: "/readings/batch/\(batchId)/status")
    }

    /// Cancel a running classification.
    func cancelClassification(batchId: Int) async throws {
        try await rawDataRequest("POST", path: "/readings/batch/\(batchId)/cancel")
    }

    /// Submit a manual correction for an image.
    func correctImage(imageId: Int, correction: String) async throws -> CorrectionResponse {
        let body = try JSONEncoder().encode(["manual_correction": correction])
        return try await request("PUT", path: "/readings/image/\(imageId)/correct", body: body)
    }

    /// Fetch valid classification categories.
    func fetchCategories() async throws -> [String] {
        let response: CategoriesResponse = try await request("GET", path: "/readings/categories")
        return response.categories
    }

    // MARK: - Statistics

    /// Fetch global statistics across all users.
    func fetchGlobalStats() async throws -> GlobalStats {
        try await request("GET", path: "/stats/global")
    }

    // MARK: - Image download

    /// Download image data for a given image ID.
    func fetchImageData(imageId: Int, original: Bool = false) async throws -> Data {
        let query = original ? "?original=true" : ""
        return try await rawDataRequest("GET", path: "/upload/image/\(imageId)\(query)")
    }

    // MARK: - Raw data request helper

    /// Perform a request that returns raw Data (no JSON decoding).
    @discardableResult
    private func rawDataRequest(_ method: String, path: String, body: Data? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = parseErrorDetail(from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, detail: detail)
        }

        return data
    }

    /// Generic multipart upload helper.
    private func uploadRequest<T: Decodable>(path: String, form: MultipartFormData) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalize()

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let detail = parseErrorDetail(from: data)
            throw APIError.httpError(statusCode: httpResponse.statusCode, detail: detail)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Helpers

    private func formEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        // Per RFC, these must be percent-encoded in form values
        allowed.remove(charactersIn: "+&=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    private func parseErrorDetail(from data: Data) -> String {
        // Backend returns {"detail": "..."} on errors
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = json["detail"] as? String {
            return detail
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Multipart form-data builder

/// Builds a multipart/form-data body for file uploads.
struct MultipartFormData {
    let boundary = "Boundary-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")
    }

    func finalize() -> Data {
        var result = body
        result.append("--\(boundary)--\r\n")
        return result
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Request body types

private struct RegisterRequest: Encodable {
    let email: String
    let username: String
    let password: String
}
