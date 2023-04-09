import Foundation

/// Holds place data.
struct Location: Codable {
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
private struct Locations: Codable {
    let locations: [Location]
}

/// Delegate for `LocationsModel`.
protocol LocationsModelDelegate: AnyObject {
    /// The model is starting fetching data.
    func didStartRefreshing()
    /// The model has finished fetching data.
    func didEndRefreshing()
    /// The model has updated data.
    func didUpdate()
    /// A fetching error occured.
    func didFail(_ error: Error)
}

/// Main model, fetches and stores remote and user places.
final class LocationsModel {
    /// Holds the list of places.
    private(set) var locations = [Location]()
    /// Holds the delegate.
    weak var delegate: LocationsModelDelegate?
    
    private var isFetching = false
    private let remoteLocationsUrl = URL(string: "https://raw.githubusercontent.com/abnamrocoesd/assignment-ios/main/locations.json")
    private let userLocationsKey = "LocationsModel.userLocations"
    
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
    
    /// Adds new user location.
    func add(userLocation location: Location) {
        userLocations = [location] + (userLocations ?? [])
        locations = [location] + locations
        delegate?.didUpdate()
    }

    private func fetchLocations(completion: (Result<[Location], Error>) -> Void) {
        do {
            let data = try remoteLocationsUrl.map { try Data(contentsOf: $0) } ?? Data()
            let json = try JSONDecoder().decode(Locations.self, from: data)
            let userLocations = userLocations ?? []
            completion(.success(userLocations + json.locations))
        } catch {
            completion(.failure(error))
        }
    }
    
    private func process(result: Result<[Location], Error>) {
        isFetching = false
        delegate?.didEndRefreshing()
        switch result {
        case .success(let locations):
            self.locations = locations
            delegate?.didUpdate()
        case .failure(let error):
            // An workaround for offline mode
            if locations.isEmpty {
                locations = userLocations ?? []
                delegate?.didUpdate()
            }
            delegate?.didFail(error)
        }
    }
    
    private var userLocations: [Location]? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userLocationsKey) else { return nil }
            return try? JSONDecoder().decode([Location].self, from: data)
        }
        set {
            var data: Data? = nil
            if let locations = newValue {
                data = try? JSONEncoder().encode(locations)
            }
            UserDefaults.standard.set(data, forKey: userLocationsKey)
        }
    }
}
