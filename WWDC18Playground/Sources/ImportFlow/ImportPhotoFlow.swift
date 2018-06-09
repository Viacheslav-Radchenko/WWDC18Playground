import UIKit

class ImportPhotoFlow: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  private var completionHandler: ((UIImage?) -> Void)?

  var isPresented: Bool {
    return self.completionHandler != nil
  }

  func present(from controller: UIViewController, completion: @escaping (UIImage?) -> Void) {
    assert(!self.isPresented)

    self.completionHandler = completion

    let prompt = UIAlertController(title: "Choose a Photo",
                                   message: "Please choose an image",
                                   preferredStyle: .actionSheet)

    let cameraAction = UIAlertAction(title: "Camera",
                                     style: .default,
                                     handler: { _ in self.presentImagePicker(for: .camera, from: controller) })

    let libraryAction = UIAlertAction(title: "Photo Library",
                                      style: .default,
                                      handler: { _ in self.presentImagePicker(for: .photoLibrary, from: controller) })

    let cancelAction = UIAlertAction(title: "Cancel",
                                     style: .cancel,
                                     handler: { _ in self.complete(with: nil) })

    prompt.addAction(cameraAction)
    prompt.addAction(libraryAction)
    prompt.addAction(cancelAction)

    controller.present(prompt, animated: true, completion: nil)
  }

  private func presentImagePicker(for sourceType: UIImagePickerController.SourceType, from controller: UIViewController) {
    let imagePicker = UIImagePickerController()
    imagePicker.sourceType = sourceType
    imagePicker.delegate = self
    controller.present(imagePicker, animated: true, completion: nil)
  }

  private func complete(with photo: UIImage?) {
    completionHandler?(photo)
    completionHandler = nil
  }

  // MARK: - UIImagePickerControllerDelegate

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.presentingViewController?.dismiss(animated: true, completion: nil)

    let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
    self.complete(with: originalImage)
  }

  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.presentingViewController?.dismiss(animated: true, completion: nil)

    self.complete(with: nil)
  }
}
