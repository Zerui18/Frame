import UIKit
import AVKit

/// Execute once dlopen for libwebpdecoder.a which is linked to our code.
fileprivate let loadWebpOnce : Void = {
  let bundle = Bundle(for: ZX2WallpaperListingViewController.self)
  if let libwebpPath = bundle.path(forResource: "libwebpdecoder", ofType: "dylib") {
    dlopen(libwebpPath, RTLD_NOW)
    WebPImageDecoder.enable()
  }
  else {
    print("[Frame Preferences] : Unable to find libwebpdecoder.")
  }
}()

/// FlowLayout subclass that implements columns per row.
class ColumnFlowLayout: UICollectionViewFlowLayout {

    let cellsPerRow: Int
    let cellHeightRatio: CGFloat

    init(cellsPerRow: Int, cellHeightRatio: CGFloat, minimumInteritemSpacing: CGFloat = 0, minimumLineSpacing: CGFloat = 0, sectionInset: UIEdgeInsets = .zero) {
        self.cellsPerRow = cellsPerRow
        self.cellHeightRatio = cellHeightRatio
        super.init()

        self.minimumInteritemSpacing = minimumInteritemSpacing
        self.minimumLineSpacing = minimumLineSpacing
        self.sectionInset = sectionInset
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else { return }
        let marginsAndInsets = sectionInset.left + sectionInset.right + collectionView.safeAreaInsets.left + collectionView.safeAreaInsets.right + minimumInteritemSpacing * CGFloat(cellsPerRow - 1)
        let itemWidth = ((collectionView.bounds.size.width - marginsAndInsets) / CGFloat(cellsPerRow)).rounded(.down)
        itemSize = CGSize(width: itemWidth, height: itemWidth * cellHeightRatio)
    }

    override func invalidationContext(forBoundsChange newBounds: CGRect) -> UICollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds) as! UICollectionViewFlowLayoutInvalidationContext
        context.invalidateFlowLayoutDelegateMetrics = newBounds.size != collectionView?.bounds.size
        return context
    }

}

@objc(ZX2WallpaperListingViewController)
public class ZX2WallpaperListingViewController : PSViewController {

  @objc public var chooseVC: ZX2ChooseWallpaperViewController!

  /// The segmentedControl displaying the available categories.
  private let segmentedControl = PinterestSegment(frame: .zero)

  /// The collectionView displaying the wallpapers.
  private lazy var collectionView: UICollectionView = {
    let isPad = UIDevice.current.userInterfaceIdiom == .pad
    let spacing: CGFloat = isPad ? 16.0 : 8.0
    let layout = ColumnFlowLayout(cellsPerRow: isPad ? 4 : 2, cellHeightRatio: 1.779, minimumInteritemSpacing: spacing, minimumLineSpacing: spacing)
    return UICollectionView(frame: .zero, collectionViewLayout: layout)
  }()

  private let refreshControl = UIRefreshControl()

  /// State of whether the initial index load has been completed.
  private var loadIndexTriggered = false

  /// The current Index api response.
  fileprivate var indexAPIResponse: IndexAPIResponse? {
    didSet {
      // this will not be set to nil
      segmentedControl.titles = indexAPIResponse!.items.map { $0.displayName }
    }
  }
    
  /// The currently displayed listing api response.
  fileprivate var listingAPIResponse: ListingAPIResponse? {
    didSet {
      collectionView.reloadData()
    }
  }

  // Lifecycle Methods
  override open func viewDidLoad() {
    super.viewDidLoad()
    _ = loadWebpOnce
    setupUI()
  }

  override open func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if !loadIndexTriggered {
      loadIndex()
      loadIndexTriggered = true
    }
  }

  private func setupUI() {
    if #available(iOS 13, *) {
      view.backgroundColor = .systemBackground
    }
    else {
      view.backgroundColor = .white
    }
    navigationItem.title = "Catalogue"
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(self.organizeTapped(_:)))

    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    // Refresh upon selection changed.
    segmentedControl.valueChange = { [weak self] _ in
      guard let strongSelf = self else {
        return
      }
      strongSelf.collectionView.endRefreshing()
      strongSelf.collectionView.beginRefreshing()
    }
    view.addSubview(segmentedControl)
    segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
    segmentedControl.heightAnchor.constraint(equalToConstant: 36).isActive = true
    segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    segmentedControl.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true

    collectionView.translatesAutoresizingMaskIntoConstraints = false
    collectionView.alwaysBounceVertical = true
    collectionView.register(ZX2WallpaperListingCell.self, forCellWithReuseIdentifier: "cell")
    collectionView.dataSource = self
    collectionView.delegate = self
    collectionView.backgroundColor = nil
    view.addSubview(collectionView)
    collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8).isActive = true
    collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
    collectionView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor).isActive = true

    refreshControl.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)
    collectionView.refreshControl = refreshControl
  }

  // Loads the root index, presenting a alert HUD while loading.
  private func loadIndex() {
    // Use alert as loading HUD.
    let alertVC = UIAlertController(title: "Loading", message: "in one moment", preferredStyle: .alert)
    present(alertVC, animated: true)

    // Perform the actual fetch.
    IndexAPIResponse.fetch { response, error in
      DispatchQueue.main.async {
        if error != nil {
          alertVC.title = "Index Load Failed"
          alertVC.message = error!.localizedDescription

          alertVC.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
            alertVC.dismiss(animated: true, completion: self.loadIndex)
          })
          // Pop self if user cancels retry.
          alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.navigationController!.popViewController(animated: true)
          })
        }
        else {
          // Successful, store response and trigger refresh.
          alertVC.dismiss(animated: true) {
            self.indexAPIResponse = response!
            self.collectionView.beginRefreshing()
          }
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
      // Clear current response and trigger reloadData.
      listingAPIResponse = nil
      let categoryIndex = segmentedControl.selectIndex
      indexAPIResponse!.items[categoryIndex].fetchListing { response, error in
        DispatchQueue.main.async {
          // Don't do anything if the user has switched to another category.
          if self.segmentedControl.selectIndex != categoryIndex {
            return
          }

          // Else check for error / update listingApiResponse.
          if error != nil {
            let alert = UIAlertController(title: "Listing Load Failed", message: error!.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel))
            self.present(alert, animated: true)
          }
          else {
            self.listingAPIResponse = response!
          }
          sender.endRefreshing()
        }
      }
    }
  }

  @objc private func organizeTapped(_ sender: UIBarButtonItem) {
    let vc = ZX2DownloadsViewController()
    vc.chooseVC = self.chooseVC
    push(vc, animate: true)
  }

}

extension ZX2WallpaperListingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

  public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    listingAPIResponse?.items.count ?? 0
  }

  public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ZX2WallpaperListingCell
    cell.wpItem = listingAPIResponse!.items[indexPath.item]
    return cell
  }

  public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let wpItem = listingAPIResponse!.items[indexPath.item]
    let remoteVideoURL = wpItem.videoURL
    // Ask the user which action to take.
    let alertVC = UIAlertController(title: wpItem.name, message: wpItem.sizeString, preferredStyle: .alert)
    // 1. Preview in an AVPlayerViewController.
    alertVC.addAction(UIAlertAction(title: "Preview", style: .default) { _ in
      // Use cached video file if available.
      let videoURL = wpItem.isSaved ? wpItem.videoCacheURL : remoteVideoURL
      let player = AVPlayer(url: videoURL)
      let playerVC = AVPlayerViewController()
      playerVC.player = player
      self.present(playerVC, animated: true)
    })
    // 2. Download.
    if (wpItem.isSaved) {
      let action = UIAlertAction(title: "Set", style: .default) { _ in
        self.chooseVC.didSelectVideo(wpItem.videoCacheURL)
      }
      alertVC.addAction(action)
    }
    else {
      alertVC.addAction(UIAlertAction(title: "Download", style: .default) { _ in
        self.downloadVideo(forItem: wpItem)
      })
    }
    // 3. Cancel.
    alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    // Present alert.
    self.present(alertVC, animated: true)
  }

  // The action for when the user chooses to download a video.
  // Here we download the video, displaying the progress, and directs the user to set it as wallpaper.
  func downloadVideo(forItem item: ListingAPIResponse.Item) {
    // Present the alert first.
    let progressAlert = UIAlertController(title: "Downloading", message: "preparing...", preferredStyle: .alert)
    present(progressAlert, animated: true)

    // Add cancel option.
    progressAlert.addAction(UIAlertAction(title: "Cancel", style: .destructive) { _ in
      Downloader.shared.cancel()
    })

    // Now begin download.
    // Hold only a weak ref to the alert as it may be dismissed early.
    item.save(onProgress: { [weak progressAlert] progress in
      DispatchQueue.main.async {
        progressAlert?.message = "\(Int(progress * 100))%"
      }
    }) { [weak progressAlert] error in
      DispatchQueue.main.async {
        if error != nil {
          progressAlert?.title = "Download Failed"
          progressAlert?.message = error!.localizedDescription
        }
        else {
          progressAlert!.dismiss(animated: true) {
            self.chooseVC.didSelectVideo(item.videoCacheURL)
          }
        }
      }
    }
    
  }

}

// Extension to implement the correct begin/end refreshing of refresh control on collectionViews.
public extension UICollectionView {

  func beginRefreshing() {
    // Make sure that a refresh control to be shown was actually set on the view
    // controller and the it is not already animating. Otherwise there's nothing
    // to refresh.
    guard let refreshControl = refreshControl, !refreshControl.isRefreshing else {
      return
    }

    // Start the refresh animation
    refreshControl.beginRefreshing()

    // Make the refresh control send action to all targets as if a user executed
    // a pull to refresh manually
    refreshControl.sendActions(for: .valueChanged)

    // Apply some offset so that the refresh control can actually be seen
    let contentOffset = CGPoint(x: 0, y: -refreshControl.frame.height)
    setContentOffset(contentOffset, animated: true)
  }

  func endRefreshing() {
    refreshControl?.endRefreshing()
  }
}