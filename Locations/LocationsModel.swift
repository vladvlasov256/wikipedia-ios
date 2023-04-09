import Foundation

/// Holds place data.
struct Location: Decodable {
    let name: String?
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case name
        case latitude = "lat"
        case longitude = "long"
    }
}

/// Helper class to parse remote data.
private struct Locations: Decodable {
    let locations: [Location]
}

/// Delegate for `LocationsModel`.
protocol LocationsModelDelegate: AnyObject {
    /// Notifies delegate that model is refreshing data.
    func didStartRefreshing()
    /// Notifies delegate that model finished refreshing data.
    func didEndRefreshing(_ result: Result<Void, Error>)
}

/// Main model, fetches and stores remote and user places.
final class LocationsModel {
    /// Holds the list of places.
    private(set) var locations = [Location]()
    /// Holds the delegate.
    weak var delegate: LocationsModelDelegate?
    
    private var isFetching = false
    private let remoteLocationsUrl = URL(string: "https://raw.githubusercontent.com/abnamrocoesd/assignment-ios/main/locations.json")
    
    /// Refreshes data if no data fetched yet or does nothing otherwise.
    func refreshIfNecessary() {
        if locations.isEmpty {
            refresh()
        }
    }
    
    /// Forcefully refreshes data.
    func refresh() {
        guard !isFetching else { return }
        isFetching = true
        delegate?.didStartRefreshing()
        DispatchQueue.global().async { [self] in
            self.fetchLocations { [weak self] result in
                DispatchQueue.main.async {
                    self?.process(result: result)
                }
            }
        }
    }

    private func fetchLocations(completion: (Result<[Location], Error>) -> Void) {
        do {
            let data = try remoteLocationsUrl.map { try Data(contentsOf: $0) } ?? Data()
            let json = try JSONDecoder().decode(Locations.self, from: data)
            completion(.success(json.locations))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func process(result: Result<[Location], Error>) {
        isFetching = false
        switch result {
        case .success(let locations):
            self.locations = locations
            delegate?.didEndRefreshing(.success(()))
        case .failure(let error):
            delegate?.didEndRefreshing(.failure(error))
        }
    }
}
