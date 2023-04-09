import UIKit

// MARK: - ViewController

final class MainViewController: UIViewController {
    private let locationCellReuseIdentifier = "LocationCell"
    private let pullToRefreshDelay = 0.25
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var pullToRefreshInfo: UILabel?
    
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let locationViewController = segue.destination as? LocationViewController {
            locationViewController.model = model
            locationViewController.popoverPresentationController?.delegate = self
        }
    }
    
    // MARK: Private
    
    @objc private func refreshData() {
        // Delay refreshing to avoid infinite activity indicator spinning when fetching fails fast
        DispatchQueue.main.asyncAfter(deadline: .now() + pullToRefreshDelay) { [self] in
            self.model?.refresh()
        }
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
            self?.model?.refresh()
        })
        present(alert, animated: true)
    }
}

// MARK: - LocationsModelDelegate

extension MainViewController: LocationsModelDelegate {
    func didStartRefreshing() {
        pullToRefreshInfo?.isHidden = true
        if !refreshControl.isRefreshing {
            refreshControl.beginRefreshing()
        }
    }
    
    func didEndRefreshing() {
        refreshControl.endRefreshing()
    }
    
    func didUpdate() {
        pullToRefreshInfo?.isHidden = model?.locations.count != 0
        tableView?.reloadData()
    }
    
    func didFail(_ error: Error) {
        presentError()
    }
}

extension MainViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
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
