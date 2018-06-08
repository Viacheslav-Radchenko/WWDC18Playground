import UIKit

protocol TopicProtocol {
  var name: String { get }
}

protocol TopicsViewProtocol: class {
}

protocol TopicsPresenterProtocol: class {
  var view: TopicsViewProtocol? { get set }
  var topics: [TopicProtocol] { get }
  func openTopic(at index: Int, from controller: UIViewController)
}
