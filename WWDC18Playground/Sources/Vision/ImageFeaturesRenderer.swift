import Vision
import UIKit

class ImageFeaturesRenderer {
  func imageWithFeatures(rectangles: [VNRectangleObservation],
                         faces: [VNFaceObservation],
                         text: [VNTextObservation],
                         barcodes: [VNBarcodeObservation],
                         originalImage: UIImage) -> UIImage {
    let imageSize = originalImage.size
    return UIGraphicsImageRenderer(size: imageSize).image { rendererContext in
      // Invert Y-axis. Observations use lower-left corner as an origin
      rendererContext.cgContext.scaleBy(x: 1, y: -1)
      rendererContext.cgContext.translateBy(x: 0, y: -imageSize.height)

      rendererContext.cgContext.setStrokeColor(UIColor.orange.cgColor)
      self.render(rectangles: rectangles, in: rendererContext, imageSize: imageSize)

      rendererContext.cgContext.setStrokeColor(UIColor.green.cgColor)
      self.render(faces: faces, in: rendererContext, imageSize: imageSize)

      rendererContext.cgContext.setStrokeColor(UIColor.red.cgColor)
      self.render(text: text, in: rendererContext, imageSize: imageSize)

      rendererContext.cgContext.setStrokeColor(UIColor.blue.cgColor)
      self.render(barcodes: barcodes, in: rendererContext, imageSize: imageSize)
    }
  }

  // MARK: - Helpers

  private func render(rectangles: [VNRectangleObservation], in context: UIGraphicsImageRendererContext, imageSize: CGSize) {
    for observation in rectangles {
      let rectPath = UIBezierPath()
      rectPath.move(to: CGPoint(x: observation.bottomLeft.x * imageSize.width,
                                y: observation.bottomLeft.y * imageSize.height))
      rectPath.addLine(to: CGPoint(x: observation.bottomRight.x * imageSize.width,
                                   y: observation.bottomRight.y * imageSize.height))
      rectPath.addLine(to: CGPoint(x: observation.topRight.x * imageSize.width,
                                   y: observation.topRight.y * imageSize.height))
      rectPath.addLine(to: CGPoint(x: observation.topLeft.x * imageSize.width,
                                   y: observation.topLeft.y * imageSize.height))
      rectPath.addLine(to: CGPoint(x: observation.bottomLeft.x * imageSize.width,
                                   y: observation.bottomLeft.y * imageSize.height))
      rectPath.lineWidth = Constants.lineWidth
      rectPath.stroke()
    }
  }

  private func render(faces: [VNFaceObservation], in context: UIGraphicsImageRendererContext, imageSize: CGSize) {
    for faceObservation in faces {
      // Render face bounding box
      let faceRect = CGRect(x: faceObservation.boundingBox.minX * imageSize.width,
                            y: faceObservation.boundingBox.minY * imageSize.height,
                            width: faceObservation.boundingBox.width * imageSize.width,
                            height: faceObservation.boundingBox.height * imageSize.height)
      let facePath = UIBezierPath(rect: faceRect)
      facePath.lineWidth = Constants.lineWidth
      facePath.stroke()

      // Render landmarks
      guard let landmarks = faceObservation.landmarks else {
        continue
      }

      // Treat eyebrows and lines as open-ended regions when drawing paths.
      let openLandmarkRegions = [
        landmarks.leftEyebrow,
        landmarks.rightEyebrow,
        landmarks.faceContour,
        landmarks.noseCrest,
        landmarks.medianLine
      ].compactMap { $0 } // Filter out missing regions.

      // Draw eyes, lips, and nose as closed regions.
      let closedLandmarkRegions = [
        landmarks.leftEye,
        landmarks.rightEye,
        landmarks.outerLips,
        landmarks.innerLips,
        landmarks.nose
      ].compactMap { $0 } // Filter out missing regions.

      let landmarkPath = UIBezierPath()

      // Draw paths for the open regions.
      for openLandmarkRegion in openLandmarkRegions {
        landmarkPath.addPolyline(for: openLandmarkRegion,
                                 in: faceRect,
                                 closed: false)
      }

      // Draw paths for the closed regions.
      for closedLandmarkRegion in closedLandmarkRegions {
        landmarkPath.addPolyline(for: closedLandmarkRegion,
                                 in: faceRect,
                                 closed: true)
      }

      landmarkPath.lineWidth = Constants.narrowLineWidth
      landmarkPath.stroke()
    }
  }

  private func render(text: [VNTextObservation], in context: UIGraphicsImageRendererContext, imageSize: CGSize) {
    self.render(rectangles: text.flatMap({ $0.characterBoxes ?? [] }), in: context, imageSize: imageSize)
  }

  private func render(barcodes: [VNBarcodeObservation], in context: UIGraphicsImageRendererContext, imageSize: CGSize) {
    self.render(rectangles: barcodes, in: context, imageSize: imageSize)
  }

  struct Constants {
    static let boldLineWidth: CGFloat = 5
    static let lineWidth: CGFloat = 3
    static let narrowLineWidth: CGFloat = 2
    static let textFontSize: CGFloat = 12
  }
}

private extension UIBezierPath {
  func addPolyline(for landmarkRegion: VNFaceLandmarkRegion2D,
                   in frame: CGRect,
                   closed: Bool) {
    guard landmarkRegion.pointCount > 1 else { return }

    for i in 0..<landmarkRegion.pointCount {
      let normPoint = landmarkRegion.normalizedPoints[i]
      let point = CGPoint(x: frame.minX + normPoint.x * frame.width,
                          y: frame.minY + normPoint.y * frame.height)
      if i == 0 {
        self.move(to: point)
      } else {
        self.addLine(to: point)
      }
    }

    if closed {
      let normPoint = landmarkRegion.normalizedPoints[0]
      let point = CGPoint(x: frame.minX + normPoint.x * frame.width,
                          y: frame.minY + normPoint.y * frame.height)
      self.addLine(to: point)
    }
  }
}
