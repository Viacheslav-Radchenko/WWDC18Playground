import UIKit

class TopicsViewController: UITableViewController, TopicsViewProtocol {
  let presenter: TopicsPresenterProtocol

  init(presenter: TopicsPresenterProtocol) {
    self.presenter = presenter
    super.init(style: .plain)
    self.presenter.view = self
    self.title = NSLocalizedString("Topics", comment: "")
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.setUpTableView()
  }

  func setUpTableView() {
    self.tableView.rowHeight = 40
    self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.topicCellIdentifier)
  }

  // MARK: - UITableViewDelegate

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    self.presenter.openTopic(at: indexPath.row, from: self)
  }

  // MARK: - UITableViewDataSource

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return self.presenter.topics.count
  }


  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let topic = self.presenter.topics[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: Constants.topicCellIdentifier, for: indexPath)
    cell.textLabel?.text = topic.name
    cell.accessoryType = .disclosureIndicator
    return cell
  }

  // MARK: - Constants

  struct Constants {
    static let topicCellIdentifier = "topic-cell"
  }
}

