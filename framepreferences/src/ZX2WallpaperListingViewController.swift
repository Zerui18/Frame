import UIKit

open class ZX2WallpaperListingViewController : UIViewController {

  /// The segmentedControl displaying the available categories.
  private let segmentedControl = PinterestSegment(frame: .zero)

  /// The collectionView displaying the thumbnail images for the videos.
  private let collectionView: UICollectionView = {
    let layout = UICollectionViewFlowLayout()
    layout.minimumLineSpacing = 8
    layout.minimumInteritemSpacing = 8
    let dim = (min(UIScreen.main.bounds.width, UIScreen.main.bounds.height) - 3 * 8) / 2
    layout.itemSize = CGSize(width: dim, height: dim)
    return UICollectionView(frame: .zero, layout: layout)
  }()

  private let refreshControl = UIRefreshControl()

  /// The current Index api response.
  fileprivate var indexAPIResponse: IndexAPIResponse? {
    didSet {
      if indexAPIResponse != nil {
        segmentedControl.titles = indexAPIResponse!.items.map { $0.name }
        segmentedControl.setSelectedIndex(index: 0)
      }
    }
  }

  /// The list of Listing api responses, with the same number of elements as indexAPIResponse.items.
  fileprivate lazy var listingAPIResponses = Array(repeating: nil, count: self.indexAPIResponse.items.count)

  override open func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    loadIndex()
  }

  private func setupUI() {
    segmentedControl.translatesAutoresizingMasksIntoConstraints = false
    segmentedControl.valueChange = { [weak self] _ in
      self?.refreshControl.beginRefreshing()
    }
    view.addSubview(segmentedControl)
    segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
    segmentedControl.height.constraint(equalToConstant: 48).isActive = true
    segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    segmentedControl.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true

    collectionView.translatesAutoresizingMasksIntoConstraints = false
    collectionView.alwaysBounceVertical = true
    collectionView.register(ZX2WallpaperListingCell.class, forCellWithReuseIdentifier: "cell")
    collectionView.dataSource = self
    collectionView.delegate = self
    view.addSubview(collectionView)

    refreshControl.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)
    collectionView.refreshControl = refreshControl
  }

  // Loads the root index, presenting a alert HUD while loading.
  private func loadIndex() {
    // Use alert as loading HUD.
    let alertVC = UIAlertController(title: "Loading", message: "in one moment", preferredStyle: .alert)
    present(alertVC, animated: true)

    // Perform the actual fetch.
    indexAPIResponse = IndexAPIResponse.fetchListing { response, error
      DispatchQueue.main.async {
        if error != nil {
          alertVC.title = "Load Failed"
          alertVC.message = error!.localizedDescription

          alertVC.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            alertVC.dismiss(animated: true, completion: self.loadIndex)
          })

          alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        }
        else {
          self.indexAPIResponse = response!
        }
      }
    }
  }

  /// Action for the pull to refresh control.
  @objc private func refreshRequested(_ sender: UIRefreshControl) {
    if indexAPIResponse == nil {
      sender.endRefreshing()
    }
    else {
      indexAPIResponse!.fetchListing { response, error in

      }
    }
  }

}

open extension ZX2WallpaperListingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    listingAPIResponses?.items.count ?? 0
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withIndentifier: "cell", for: indexPath) as! ZX2WallpaperListingCell
    cell.videoItem = listingAPIResponses!.items[indexPath.item]
    return cell
  }

}