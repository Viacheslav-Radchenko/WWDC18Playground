import AVFoundation
import Foundation
import UIKit

class VideoTrackingProcessor {
  private lazy var imageFeaturesDetector = ImageFeaturesDetector()
  private var videoFeeder: VideoFeeder?
  private var objectsTracker: ObjectsTracker?
  private var frameHandler: ((CVPixelBuffer, DetectionResult?, UInt) -> Void)?
  private var errorHandler: ((Error) -> Void)?

  func startProcessing(videoAsset: AVAsset,
                       frameHandler: @escaping (CVPixelBuffer, DetectionResult?, UInt) -> Void,
                       errorHandler: @escaping (Error) -> Void) {
    guard
      let videoReader = VideoReader(videoAsset: videoAsset),
      let firstFrame = videoReader.fisrtFrame()
    else {
      let error = NSError(domain: "video.processor",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("Failed to obtain first video frame", comment: "")])
      errorHandler(error)
      return
    }

    frameHandler(firstFrame, nil, 0)

    self.frameHandler = frameHandler
    self.errorHandler = errorHandler

    let videoOrientation = videoReader.orientation
    self.imageFeaturesDetector.detect(features: [.faces, .rectangles], in: firstFrame, orientation: videoOrientation) { [weak self] result in
      if result.allObservations.isEmpty {
        let error = NSError(domain: "video.processor",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("No trackable objects detected", comment: "")])
        self?.errorHandler?(error)
        self?.stopProcessing()
      } else {
        self?.frameHandler?(firstFrame, result, 0)
        self?.trackDetectedObjects(result, videoFeeder: VideoFeeder(reader: videoReader), orientation: videoOrientation)
      }
    }
  }

  func stopProcessing() {
    self.videoFeeder?.stop()
    self.videoFeeder = nil
    self.objectsTracker = nil
    self.frameHandler = nil
    self.errorHandler = nil
  }

  private func trackDetectedObjects(_ detectionResult: DetectionResult, videoFeeder: VideoFeeder, orientation: CGImagePropertyOrientation) {
    self.videoFeeder = videoFeeder
    self.objectsTracker = ObjectsTracker(initialObservations: Array(detectionResult.allObservations))
    self.videoFeeder?.start(frameHandler: { [weak self] framePixelBuffer, frameIndex in
      self?.handleCurrentFrame(framePixelBuffer, orientation: orientation, frameIndex: frameIndex)
    }, errorHandler: { [weak self] error in
      self?.errorHandler?(error)
      self?.stopProcessing()
    })
  }

  private func handleCurrentFrame(_ framePixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, frameIndex: UInt) {
    self.objectsTracker?.track(in: framePixelBuffer, orientation: orientation) { [weak self] result in
      self?.frameHandler?(framePixelBuffer, result, frameIndex)
    }
  }
}
