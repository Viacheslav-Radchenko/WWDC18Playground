import UIKit
import Vision

class ImageFeaturesDetectionViewController: UIViewController {
  lazy var imageFeaturesDetector = ImageFeaturesDetector()
  lazy var importPhotoFlow = ImportPhotoFlow()

  lazy var infoLabel: UILabel = {
    let label = UILabel()
    label.text = NSLocalizedString("Choose photo to detect faces, face landmarks, rectangle areas, text or barcodes", comment: "")
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: 16)
    label.textColor = .lightGray
    label.textAlignment = .center
    label.autoresizingMask = [ .flexibleWidth , .flexibleHeight ]
    return label
  }()
  lazy var resultsLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: 10)
    label.textColor = .red
    label.textAlignment = .left
    label.autoresizingMask = [ .flexibleWidth , .flexibleTopMargin ]
    return label
  }()
  lazy var originalImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .clear
    imageView.contentMode = .scaleAspectFit
    imageView.autoresizingMask = [ .flexibleWidth , .flexibleHeight ]
    return imageView
  }()
  lazy var overlayImageView: UIImageView = {
    let imageView = UIImageView()
    imageView.backgroundColor = .clear
    imageView.contentMode = .scaleAspectFit
    imageView.autoresizingMask = [ .flexibleWidth , .flexibleHeight ]
    return imageView
  }()

  lazy var activityIndicator: UIActivityIndicatorView  = {
    let indicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    indicator.autoresizingMask = [ .flexibleLeftMargin , .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin ]
    return indicator
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .white
    self.title = NSLocalizedString("Vision", comment: "")
    self.setUpNavigationItems()
    self.setUpInfoLabel()
    self.setUpImageView()
    self.setUpActivityIndicator()
    self.setUpResultsLabel()
  }

  // MARK: - Setup

  func setUpNavigationItems() {
    self.navigationItem.rightBarButtonItems = [
      UIBarButtonItem(title: NSLocalizedString("Open...", comment: ""), style: .plain, target: self, action: #selector(importPhoto)),
    ]
  }

  func setUpInfoLabel() {
    self.infoLabel.frame = self.view.bounds.insetBy(dx: 30, dy: 30)
    self.view.addSubview(self.infoLabel)
  }

  func setUpResultsLabel() {
    let height: CGFloat = 70
    let offset: CGFloat = 10
    self.resultsLabel.frame = CGRect(x: offset, y: self.view.bounds.height - height, width: self.view.bounds.width - 2 * offset, height: height)
    self.view.addSubview(self.resultsLabel)
  }

  func setUpImageView() {
    self.originalImageView.frame = self.view.bounds
    self.view.addSubview(self.originalImageView)
    self.overlayImageView.frame = self.view.bounds
    self.view.addSubview(self.overlayImageView)
  }

  func setUpActivityIndicator() {
    self.activityIndicator.center = CGPoint(x: self.view.bounds.width / 2, y: self.view.bounds.height / 2)
    self.view.addSubview(self.activityIndicator)
    self.activityIndicator.isHidden = true
  }

  // MARK: - Actions

  @objc
  func importPhoto() {
    guard !self.importPhotoFlow.isPresented else { return }
    self.importPhotoFlow.present(from: self) { result in
      self.setCurrentImage(result)
    }
  }

  private func setCurrentImage(_ image: UIImage?) {
    self.originalImageView.image = image
    self.overlayImageView.image = nil
    self.resultsLabel.attributedText = nil

    guard let originalImage = image else { return }
    self.navigationItem.rightBarButtonItem?.isEnabled = false
    self.activityIndicator.isHidden = false
    self.activityIndicator.startAnimating()
    self.imageFeaturesDetector.detect(features: .allSupported, in: originalImage) { [weak self] result in
      self?.activityIndicator.stopAnimating()
      self?.navigationItem.rightBarButtonItem?.isEnabled = true
      self?.handleDetectedResults(result, originalImage: originalImage)
    }
  }

  private func handleDetectedResults(_ result: DetectionResult, originalImage: UIImage) {
    if let error = result.error {
      self.showError(error)
      return
    }

    let renderer = ImageFeaturesRenderer()
    self.overlayImageView.image = renderer.imageWithFeatures(rectangles: Array(result.rectangles),
                                                             faces: Array(result.faces),
                                                             text: Array(result.text),
                                                             barcodes: Array(result.barcodes),
                                                             originalImage: originalImage)

    self.updateResultsLabel(with: result)
  }

  private func updateResultsLabel(with result: DetectionResult) {
    let rectsAttributedText = NSAttributedString(
      string: "Rects: \(result.rectangles.count)\(self.confidenceString(for: result.rectangles))\n",
      attributes: [NSAttributedString.Key.foregroundColor: UIColor.orange])
    let facesAttributedText = NSAttributedString(
      string: "Faces: \(result.faces.count)\(self.confidenceString(for: result.faces))\n",
      attributes: [NSAttributedString.Key.foregroundColor: UIColor.green])
    let textAttributedText = NSAttributedString(
      string: "Text: \(result.text.count)\(self.confidenceString(for: result.text))\n",
      attributes: [NSAttributedString.Key.foregroundColor: UIColor.red])
    let barcodesAttributedText = NSAttributedString(
      string: "Barcodes: \(result.barcodes.count)\(self.confidenceString(for: result.barcodes))\(self.payloadString(for: result.barcodes))\n",
      attributes: [NSAttributedString.Key.foregroundColor: UIColor.blue])

    let attributedText = NSMutableAttributedString()
    attributedText.append(rectsAttributedText)
    attributedText.append(facesAttributedText)
    attributedText.append(textAttributedText)
    attributedText.append(barcodesAttributedText)
    self.resultsLabel.attributedText = attributedText
  }

  private func confidenceString(for observations: Set<VNObservation>) -> String {
    guard !observations.isEmpty else { return "" }
    let confidences: [String] = observations.map { "\($0.confidence)" }
    return ", confidence: " + confidences.joined(separator: ", ")
  }

  private func payloadString(for barcodes: Set<VNBarcodeObservation>) -> String {
    guard !barcodes.isEmpty else { return "" }
    let barcodePayloads: [String] = barcodes.compactMap { $0.payloadStringValue }
    return ", payload: " + barcodePayloads.joined(separator: ", ")
  }

  // MARK: - Error alert

  private func showError(_ error: Error) {
    let alertController = UIAlertController(title: title,
                                            message: error.localizedDescription,
                                            preferredStyle: .alert)
    let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                 style: .default,
                                 handler: nil)
    alertController.addAction(okAction)
    self.present(alertController, animated: true, completion: nil)
  }
}
