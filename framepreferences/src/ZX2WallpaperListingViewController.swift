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

  /// A list of the root categories.
  

  override open func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
  }

  private func setupUI() {
    segmentedControl.translatesAutoresizingMasksIntoConstraints = false
    view.addSubview(segmentedControl)
    segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
    segmentedControl.height.constraint(equalToConstant: 48).isActive = true
    segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    segmentedControl.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true

    collectionView.translatesAutoresizingMasksIntoConstraints = false
    collectionView.register(ZX2WallpaperListingCell.class, forCellWithReuseIdentifier: "cell")
    collectionView.dataSource = self
    collectionView.delegate = self
    view.addSubview(collectionView)
  }

}

open extension ZX2WallpaperListingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {

  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

  }

}