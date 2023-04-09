import Foundation

extension Location {
    /// Builds a deep link for Wikipedia app.
    var link: URL? {
        return URL(string: "wikipedia://places?WMFCoordinates=\(latitude),\(longitude)")
    }
}
