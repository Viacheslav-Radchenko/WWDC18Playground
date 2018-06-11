import AVFoundation
import UIKit
import Vision

class ObjectsTracker {
  let initialObservations: [VNDetectedObjectObservation]
  let trackingLevel: VNRequestTrackingLevel

  private lazy var sequenceRequestHandler = VNSequenceRequestHandler()
  private var latestObservations: [UUID: VNDetectedObjectObservation] = [:]

  init(initialObservations: [VNDetectedObjectObservation], trackingLevel: VNRequestTrackingLevel = .accurate) {
    self.initialObservations = initialObservations
    self.trackingLevel = trackingLevel

    for observation in initialObservations {
      self.latestObservations[observation.uuid] = observation
    }
  }

  func track(in cvPixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, completion: @escaping (DetectionResult) -> Void) {
    let trackingRequests: [VNTrackingRequest] = self.latestObservations.values.compactMap { observation in
      var request: VNTrackingRequest?
      if let rectObservation = observation as? VNRectangleObservation {
        request = VNTrackRectangleRequest(rectangleObservation: rectObservation)
      } else {
        request = VNTrackObjectRequest(detectedObjectObservation: observation)
      }
      request?.trackingLevel = trackingLevel
      return request
    }

    let requestHandler = self.sequenceRequestHandler

    DispatchQueue.global(qos: .userInitiated).async {
      var result = DetectionResult()
      do {
        try requestHandler.perform(trackingRequests, on: cvPixelBuffer, orientation: orientation)
        for request in trackingRequests {
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

      DispatchQueue.main.async { [weak self] in
        for observation in result.allObservations {
          self?.latestObservations[observation.uuid] = observation
        }
        completion(result)
      }
    }
  }
}
