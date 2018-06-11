import AVFoundation
import UIKit
import Vision

class VideoObjectsTrackingViewController: UIViewController {
  private lazy var importVideoFlow = ImportVideoFlow()
  private lazy var imageFeaturesDetector = ImageFeaturesDetector()
  private var latestDetectionResult: DetectionResult?
  private var videoFeeder: VideoFeeder?
  private var objectsTracker: ObjectsTracker?

  lazy var infoLabel: UILabel = {
    let label = UILabel()
    label.text = NSLocalizedString("Choose video to track faces or rectangles", comment: "")
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

  lazy var imageView: UIImageView = {
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
    self.title = NSLocalizedString("Tracking", comment: "")
    self.setUpNavigationItems()
    self.setUpInfoLabel()
    self.setUpImageView()
    self.setUpActivityIndicator()
    self.setUpResultsLabel()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    self.cleanUpVideoFeederIfNeeded()
  }

  // MARK: - Setup

  func setUpNavigationItems() {
    self.navigationItem.rightBarButtonItems = [
      UIBarButtonItem(title: NSLocalizedString("Open...", comment: ""), style: .plain, target: self, action: #selector(importVideo)),
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
    self.imageView.frame = self.view.bounds
    self.view.addSubview(self.imageView)
  }

  func setUpActivityIndicator() {
    self.activityIndicator.center = CGPoint(x: self.view.bounds.width / 2, y: self.view.bounds.height / 2)
    self.view.addSubview(self.activityIndicator)
    self.activityIndicator.isHidden = true
  }

  // MARK: - Actions

  @objc
  func importVideo() {
    guard !self.importVideoFlow.isPresented else { return }
    self.importVideoFlow.present(from: self) { result in
      self.setCurrentVideo(result)
    }
  }

  private func setCurrentVideo(_ video: AVAsset?) {
    self.cleanUpVideoFeederIfNeeded()
    self.imageView.image = nil
    self.resultsLabel.attributedText = nil

    guard let asset = video, let videoReader = VideoReader(videoAsset: asset) else { return }
    let videoOrientation = videoReader.orientation
    self.videoFeeder = VideoFeeder(reader: videoReader)
    self.videoFeeder?.start(frameHandler: { [weak self] framePixelBuffer, frameIndex in
      self?.handleCurrentFrame(framePixelBuffer, orientation: videoOrientation, frameIndex: frameIndex)
    }, errorHandler: { [weak self] error in
      self?.showError(error)
      self?.cleanUpVideoFeederIfNeeded()
    })
  }

  private func handleCurrentFrame(_ framePixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, frameIndex: UInt) {
    let ciImage = CIImage(cvPixelBuffer: framePixelBuffer)
    let image = UIImage(ciImage: ciImage)
    if let detectionResult = self.latestDetectionResult {
      let renderer = ImageFeaturesRenderer()
      self.imageView.image = renderer.imageWithFeatures(rectangles: Array(detectionResult.rectangles),
                                                        faces: Array(detectionResult.faces),
                                                        text: Array(detectionResult.text),
                                                        barcodes: Array(detectionResult.barcodes),
                                                        objects: Array(detectionResult.objects),
                                                        originalImage: image)
    } else {
      self.imageView.image = image
    }

    if frameIndex == 0 {
      self.imageFeaturesDetector.detect(features: [.faces, .rectangles], in: framePixelBuffer, orientation: orientation) { [weak self] result in
        self?.handleDetectedResults(result)
        self?.resetObjectsTracker(result)
      }
    } else {
      self.objectsTracker?.track(in: framePixelBuffer, orientation: orientation) { [weak self] result in
        self?.handleDetectedResults(result)
      }
    }
  }

  private func cleanUpVideoFeederIfNeeded() {
    self.videoFeeder?.stop()
    self.videoFeeder = nil
  }

  private func handleDetectedResults(_ result: DetectionResult) {
    if let error = result.error {
      self.latestDetectionResult = nil
      self.updateResultsLabel(text: error.localizedDescription)
    } else {
      self.latestDetectionResult = result
      self.updateResultsLabel(text: nil)
    }
  }

  private func resetObjectsTracker(_ result: DetectionResult) {
    self.objectsTracker = ObjectsTracker(initialObservations: Array(result.allObservations))
  }

  private func updateResultsLabel(text: String?) {
    if let text = text {
      self.resultsLabel.attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.foregroundColor: UIColor.red])
    } else {
      self.resultsLabel.attributedText = nil
    }
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
