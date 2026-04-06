import Foundation

@Observable
class StatisticsViewModel {
    var stats: GlobalStats?
    var isLoading = false
    var errorMessage: String?

    private let api = APIClient.shared

    @MainActor
    func loadStats() async {
        isLoading = true
        errorMessage = nil

        do {
            stats = try await api.fetchGlobalStats()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
