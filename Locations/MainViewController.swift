import UIKit

class MainViewController: UIViewController {
    @IBOutlet weak var linkTextField: UITextField?

    @IBAction func openLink() {
        guard let link = URL(string: linkTextField?.text ?? "") else { return }
        UIApplication.shared.open(link)
    }
}

