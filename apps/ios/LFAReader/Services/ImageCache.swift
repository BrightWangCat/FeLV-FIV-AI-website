import UIKit

/// In-memory image cache backed by NSCache.
actor ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSNumber, UIImage>

    private init() {
        cache = NSCache()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024
    }

    func image(for id: Int) -> UIImage? {
        cache.object(forKey: NSNumber(value: id))
    }

    func store(_ image: UIImage, for id: Int) {
        cache.setObject(image, forKey: NSNumber(value: id))
    }

    func clear() {
        cache.removeAllObjects()
    }
}
