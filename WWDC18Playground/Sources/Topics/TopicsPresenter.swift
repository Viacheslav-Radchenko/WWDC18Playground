import UIKit

struct Topic: TopicProtocol {
  let name: String
  let controllerProvider: () -> UIViewController
}

class TopicsPresenter: TopicsPresenterProtocol {
  private let topicItems: [Topic]

  var topics: [TopicProtocol] {
    return self.topicItems
  }

  weak var view: TopicsViewProtocol?

  init(topics: [Topic]) {
    self.topicItems = topics
  }

  func openTopic(at index: Int, from controller: UIViewController) {
    let topic = self.topicItems[index]
    let topicController = topic.controllerProvider()
    controller.navigationController?.pushViewController(topicController, animated: true)
  }
}

extension TopicsPresenter {
  static func makeDefault() -> TopicsPresenter {
    return TopicsPresenter(topics: [
      Topic(name: "Vision: detecting objects in still images", controllerProvider: { ImageFeaturesDetectionViewController() }),
      Topic(name: "CoreML", controllerProvider: { CoreMLViewController() }),
      Topic(name: "ARKit", controllerProvider: { ARKitViewController() }),
    ])
  }
}
