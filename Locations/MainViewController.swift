import UIKit


// MARK: - ViewController

final class MainViewController: UIViewController {
    private let locationCellReuseIdentifier = "LocationCell"
    
    @IBOutlet weak var tableView: UITableView?
    
    var model: LocationsModel?
    
    private let refreshControl = UIRefreshControl()
    
    // MARK: Overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView?.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        model?.refreshIfNecessary()
    }
    
    // MARK: Private
    
    @objc private func refreshData() {
        model?.refresh()
    }
    
    private func open(link: URL?) {
        guard let link = link else { return }
        if UIApplication.shared.canOpenURL(link) {
            UIApplication.shared.open(link)
        }
    }
    
    private func presentError() {
        let alert = UIAlertController(title: "Something went wrong", message: "Please, try again", preferredStyle: .alert)
        alert.addAction(.init(title: "Ok", style: .cancel))
        alert.addAction(.init(title: "Retry", style: .default) { [weak self] _ in
            self?.refreshData()
        })
        present(alert, animated: true)
    }
}

// MARK: - LocationsModelDelegate

extension MainViewController: LocationsModelDelegate {
    func didStartRefreshing() {
        if !refreshControl.isRefreshing {
            refreshControl.beginRefreshing()
        }
    }
    
    func didEndRefreshing(_ result: Result<Void, Error>) {
        refreshControl.endRefreshing()
        switch result {
        case .success:
            tableView?.reloadData()
        case .failure:
            presentError()
        }
    }
}

// MARK: - LocationsModelDelegate

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model?.locations.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: locationCellReuseIdentifier, for: indexPath)
        cell.configure(with: model?.locations[indexPath.row])
        return cell
    }
}

// MARK: - LocationsModelDelegate

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let location = model?.locations[indexPath.row] {
            open(link: location.link)
        }
    }
}

// MARK: - Helpers

private extension UITableViewCell {
    func configure(with location: Location?) {
        var content = defaultContentConfiguration()
        content.text = "\(location?.latitude ?? 0.0) \(location?.longitude ?? 0.0)"
        content.secondaryText = location?.name ?? ""
        contentConfiguration = content
    }
}
