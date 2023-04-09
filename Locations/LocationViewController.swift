import UIKit

final class LocationViewController: UIViewController {
    @IBOutlet weak var latitudeTextField: UITextField?
    @IBOutlet weak var longitudeTextField: UITextField?
    @IBOutlet weak var nameTextField: UITextField?
    @IBOutlet weak var submitButton: UIButton?
    
    var model: LocationsModel?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let resultSize = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.preferredContentSize = resultSize
        updateSubmitButton()
    }
    
    @IBAction func onLatitudeChanged() {
        updateSubmitButton()
    }
    
    @IBAction func onLongitudeChanged() {
        updateSubmitButton()
    }
    
    @IBAction func onNameChanged() {
        updateSubmitButton()
    }
    
    @IBAction func submit() {
        guard
            let latitude = Double(latitudeTextField?.text ?? ""),
            let longitude = Double(longitudeTextField?.text ?? "")
        else {
            return
        }
        
        let location = Location(name: nameTextField?.text, latitude: latitude, longitude: longitude)
        dismiss(animated: true) { [weak model] in
            model?.add(userLocation: location)
        }
    }
    
    private func updateSubmitButton() {
        if let _ = Double(latitudeTextField?.text ?? ""), let _ = Double(longitudeTextField?.text ?? "") {
            submitButton?.isEnabled = true
        } else {
            submitButton?.isEnabled = false
        }
    }
}
