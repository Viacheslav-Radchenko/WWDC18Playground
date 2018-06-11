import AVFoundation
import MobileCoreServices
import UIKit

class ImportVideoFlow: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private var completionHandler: ((AVAsset?) -> Void)?

  var isPresented: Bool {
    return self.completionHandler != nil
  }

  func present(from controller: UIViewController, completion: @escaping (AVAsset?) -> Void) {
    assert(!self.isPresented)

    self.completionHandler = completion

    let prompt = UIAlertController(title: NSLocalizedString("Choose a Video", comment: ""),
                                   message: nil,
                                   preferredStyle: .actionSheet)

    let libraryAction = UIAlertAction(title: NSLocalizedString("Photo Library", comment: ""),
                                      style: .default,
                                      handler: { _ in self.presentVideoPicker(from: controller) })

    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
                                     style: .cancel,
                                     handler: { _ in self.complete(with: nil) })

    prompt.addAction(libraryAction)
    prompt.addAction(cancelAction)

    controller.present(prompt, animated: true, completion: nil)
  }

  private func presentVideoPicker(from controller: UIViewController) {
    let imagePicker = UIImagePickerController()
    imagePicker.sourceType = .photoLibrary
    imagePicker.mediaTypes = [kUTTypeMovie as String]
    imagePicker.delegate = self
    controller.present(imagePicker, animated: true, completion: nil)
  }

  private func complete(with video: AVAsset?) {
    completionHandler?(video)
    completionHandler = nil
  }

  // MARK: - UIImagePickerControllerDelegate

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.presentingViewController?.dismiss(animated: true, completion: nil)

    if let videoURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL {
      self.complete(with: AVAsset(url: videoURL))
    } else {
      self.complete(with: nil)
    }
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.presentingViewController?.dismiss(animated: true, completion: nil)

    self.complete(with: nil)
  }
}
