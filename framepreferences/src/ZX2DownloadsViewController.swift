import UIKit
import AVKit

class ZX2DownloadsViewController : PSViewController {

  var chooseVC: ZX2ChooseWallpaperViewController!

  lazy fileprivate var listing = CachedWallpaper.getListing()

  /// The collectionView displaying the wallpapers.
  private lazy var collectionView: UICollectionView = {
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    let spacing: CGFloat = isPad ? 16.0 : 8.0
    let layout = ColumnFlowLayout(cellsPerRow: isPad ? 4 : 2, cellHeightRatio: 1.779, minimumInteritemSpacing: spacing, minimumLineSpacing: spacing)
    layout.sectionInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
    return UICollectionView(frame: .zero, collectionViewLayout: layout)
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.title = "Downloaded"

    if #available(iOS 13, *) {
      view.backgroundColor = .systemBackground
    }
    else {
      view.backgroundColor = .white
    }

    // Setup collectionView.
    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.alwaysBounceVertical = true
    collectionView.register(ZX2WallpaperListingCell.self, forCellWithReuseIdentifier: "cell")
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.backgroundColor = nil
    view.addSubview(collectionView)
    collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
    collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    collectionView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true
  }

}

extension ZX2DownloadsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    listing.count
  }

  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ZX2WallpaperListingCell
    cell.wpItem = listing[indexPath.item]
    return cell
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let wpItem = listing[indexPath.item]
    let videoURL = wpItem.videoURL
    // Ask the user which action to take.
    let alertVC = UIAlertController(title: wpItem.name, message: wpItem.sizeString, preferredStyle: .alert)
    // 1. Preview in an AVPlayerViewController.
    alertVC.addAction(UIAlertAction(title: "Preview", style: .default) { _ in
      // Use cached video file if available.
      let player = AVPlayer(url: videoURL)
      let playerVC = AVPlayerViewController()
      playerVC.player = player
      self.present(playerVC, animated: true)
    })
    // 2. Set as wallpaper.
    let setAction = UIAlertAction(title: "Set", style: .default) { _ in
      self.chooseVC.didSelectVideo(videoURL)
    }
    alertVC.addAction(setAction)
    // 3. Delete.
    let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
      // Delete the files.
      wpItem.deleteFiles()
      // Remove from listing.
      self.listing.firstIndex(of: wpItem).flatMap { self.listing.remove(at: $0) }
      // Remove from collectionView.
      collectionView.deleteItems(at: [indexPath])
    }
    alertVC.addAction(deleteAction)
    // 4. Cancel.
    alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    // Present alert.
    self.present(alertVC, animated: true)
  }
}