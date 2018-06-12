import CoreVideo
import Foundation
import QuartzCore

class VideoFeeder {
  private var displayLink: CADisplayLink?
  private var frameHandler: ((CVPixelBuffer, UInt) -> Void)?
  private var errorHandler: ((Error) -> Void)?
  private let videoReader: VideoReader
  private var framesCounter: UInt = 0

  init(reader: VideoReader) {
    self.videoReader = reader
  }

  var isActive: Bool {
    return self.displayLink != nil
  }

  func start(frameHandler: @escaping (CVPixelBuffer, UInt) -> Void, errorHandler: @escaping (Error) -> Void) {
    assert(!self.isActive)

    self.frameHandler = frameHandler
    self.errorHandler = errorHandler
    self.framesCounter = 0

    let displayLink = CADisplayLink(target: self, selector: #selector(tick))
    displayLink.preferredFramesPerSecond = 10
    displayLink.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
    self.displayLink = displayLink

    if let firstFrame = self.videoReader.fisrtFrame() {
      self.frameHandler?(firstFrame, self.framesCounter)
    }
  }

  func stop() {
    self.displayLink?.invalidate()
    self.displayLink = nil
    self.frameHandler = nil
    self.errorHandler = nil
  }

  // MARK: - Private

  @objc
  func tick() {
    self.feedNextFrame()
  }

  private func feedNextFrame() {
    if let frame = self.videoReader.nextFrame() {
      self.framesCounter = self.framesCounter + 1
      self.frameHandler?(frame, self.framesCounter)
    } else if self.videoReader.restartReading(), let firstFrame = self.videoReader.nextFrame() {
      self.framesCounter = 0
      self.frameHandler?(firstFrame, self.framesCounter)
    } else {
      let error = NSError(domain: "video.feeder", code: 0, userInfo: [NSLocalizedDescriptionKey : NSLocalizedString("Failed to obtain next video frame", comment: "")])
      self.errorHandler?(error)
      self.stop()
    }
  }
}
