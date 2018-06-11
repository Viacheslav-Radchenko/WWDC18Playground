import CoreGraphics
import UIKit
import Vision

struct DetectableFeatures: OptionSet {
  let rawValue: Int

  static let rectangles = DetectableFeatures(rawValue: 1 << 0)
  static let faces = DetectableFeatures(rawValue: 1 << 1)
  static let faceLandmarks = DetectableFeatures(rawValue: 1 << 2)
  static let text = DetectableFeatures(rawValue: 1 << 3)
  static let barcodes = DetectableFeatures(rawValue: 1 << 4)

  static let allSupported: DetectableFeatures = [rectangles, faceLandmarks, text, barcodes]
}

struct DetectionResult {
  var rectangles: Set<VNRectangleObservation>
  var faces: Set<VNFaceObservation>
  var text: Set<VNTextObservation>
  var barcodes: Set<VNBarcodeObservation>
  var objects: Set<VNDetectedObjectObservation>
  var error: Error?

  init(rectangles: Set<VNRectangleObservation>,
       faces: Set<VNFaceObservation>,
       text: Set<VNTextObservation>,
       barcodes: Set<VNBarcodeObservation>,
       objects: Set<VNDetectedObjectObservation>,
       error: Error?) {
    self.rectangles = rectangles
    self.faces = faces
    self.text = text
    self.barcodes = barcodes
    self.objects = objects
    self.error = error
  }

  init(error: Error) {
    self.init(rectangles: Set(),
              faces: Set(),
              text: Set(),
              barcodes: Set(),
              objects: Set(),
              error: error)
  }

  init() {
    self.init(rectangles: Set(),
              faces: Set(),
              text: Set(),
              barcodes: Set(),
              objects: Set(),
              error: nil)
  }

  var allObservations: Set<VNDetectedObjectObservation> {
    var results = Set<VNDetectedObjectObservation>()
    results.formUnion(self.rectangles)
    results.formUnion(self.faces)
    results.formUnion(self.text)
    results.formUnion(self.barcodes)
    results.formUnion(self.objects)
    return results
  }
}

class ImageFeaturesDetector {
  func detect(features: DetectableFeatures, in cvPixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, completion: @escaping (DetectionResult) -> Void) {
    let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: cvPixelBuffer,
                                                    orientation: orientation,
                                                    options: [:])
    self.detect(features: features, imageRequestHandler: imageRequestHandler, completion: completion)
  }
  
  func detect(features: DetectableFeatures, in image: UIImage, completion: @escaping (DetectionResult) -> Void) {
    guard let cgImage = image.cgImage else {
      let error = NSError(domain: "image.features.detector", code: 1, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("Invalid image format", comment: "")])
      completion(DetectionResult(error: error))
      return
    }

    let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage,
                                                    orientation: CGImagePropertyOrientation(image.imageOrientation),
                                                    options: [:])
    self.detect(features: features, imageRequestHandler: imageRequestHandler, completion: completion)
  }

  private func detect(features: DetectableFeatures, imageRequestHandler: VNImageRequestHandler, completion: @escaping (DetectionResult) -> Void) {
    guard !features.isEmpty else {
      let error = NSError(domain: "image.features.detector", code: 0, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("No features requested", comment: "")])
      completion(DetectionResult(error: error))
      return
    }

    let imageRequests = self.makeVisionRequests(for: features)

    DispatchQueue.global(qos: .userInitiated).async {
      var result = DetectionResult()
      do {
        try imageRequestHandler.perform(imageRequests)
        for request in imageRequests {
          if let faces = request.results as? [VNFaceObservation] {
            result.faces.formUnion(faces)
          } else if let text = request.results as? [VNTextObservation] {
            result.text.formUnion(text)
          } else if let barcodes = request.results as? [VNBarcodeObservation] {
            result.barcodes.formUnion(barcodes)
          } else if let rectangles = request.results as? [VNRectangleObservation] {
            result.rectangles.formUnion(rectangles)
          } else if let objects = request.results as? [VNDetectedObjectObservation] {
            result.objects.formUnion(objects)
          }
        }
      } catch {
        result.error = error
      }

      DispatchQueue.main.async {
        completion(result)
      }
    }
  }

  private func makeVisionRequests(for features: DetectableFeatures) -> [VNRequest] {
    var requests: [VNRequest] = []

    if features.contains(.rectangles) {
      requests.append(self.rectangleDetectionRequest)
    }
    if features.contains(.faces) {
      requests.append(self.faceDetectionRequest)
    }
    if features.contains(.faceLandmarks) {
      requests.append(self.faceLandmarkRequest)
    }
    if features.contains(.text) {
      requests.append(self.textDetectionRequest)
    }
    if features.contains(.barcodes) {
      requests.append(self.barcodeDetectionRequest)
    }

    return requests
  }

  // MARK: - Vision requests

  private lazy var rectangleDetectionRequest: VNDetectRectanglesRequest = {
    let rectDetectRequest = VNDetectRectanglesRequest(completionHandler: self.handleDetectedObjects)
    // Customize & configure the request to detect only certain rectangles.
    rectDetectRequest.maximumObservations = 8 // Vision currently supports up to 16.
    rectDetectRequest.minimumConfidence = 0.7 // Be confident.
    rectDetectRequest.minimumAspectRatio = 0.3 // height / width
    return rectDetectRequest
  }()

  private lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: self.handleDetectedObjects)

  private lazy var faceLandmarkRequest = VNDetectFaceLandmarksRequest(completionHandler: self.handleDetectedObjects)

  private lazy var textDetectionRequest: VNDetectTextRectanglesRequest = {
    let textDetectRequest = VNDetectTextRectanglesRequest(completionHandler: self.handleDetectedObjects)
    // Tell Vision to report bounding box around each character.
    textDetectRequest.reportCharacterBoxes = true
    return textDetectRequest
  }()

  private lazy var barcodeDetectionRequest: VNDetectBarcodesRequest = {
    let barcodeDetectRequest = VNDetectBarcodesRequest(completionHandler: self.handleDetectedObjects)
    // Restrict detection to most common symbologies.
    barcodeDetectRequest.symbologies = [.QR, .Aztec, .UPCE]
    return barcodeDetectRequest
  }()

  // MARK: - Request completion

  private func handleDetectedObjects(request: VNRequest?, error: Error?) {
    if let request = request, let numberOfDetectedObjects = request.results?.count {
      print("Detected \(numberOfDetectedObjects) objects. \(String(describing: type(of: request)))")
    } else if let error = error {
      print("Vision request failed with error \(error)")
    }
  }
}
