import UIKit

class ZX2WallpaperListingCell: UICollectionViewCell {

  /// The wpItem that is represented by this cell.
  var wpItem: ListingItemRepresentable! {
    didSet {
      let options = ImageLoadingOptions(
          transition: .fadeIn(duration: 0.33)
        )
      loadImage(with: wpItem.imageURL, options: options, into: self.thumbnailView)
      self.nameLabel.text = wpItem.name
      self.authorLabel.text = wpItem.sizeString
    }
  }
  
  /// The imageView that displays the video's thumbnail.
  private let thumbnailView: UIImageView = {
    let imgView = UIImageView()
    imgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    imgView.contentMode = .scaleAspectFill
    imgView.layer.masksToBounds = true
    imgView.layer.cornerRadius = 8
    if #available(iOS 13, *) {
      imgView.layer.backgroundColor = UIColor.tertiarySystemFill.cgColor
    }
    else {
      imgView.layer.backgroundColor = UIColor.lightGray.cgColor
    }
    return imgView
  }()

  /// The label that displays the video's name.
  private let nameLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 2
    label.textAlignment = .center
    label.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
    label.layer.masksToBounds = true
    label.layer.cornerRadius = 8
    if #available(iOS 13, *) {
      label.textColor = .label
      label.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.8)
    }
    else {
      label.textColor = .darkText
      label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    }
    return label
  }()

  /// The label that displays the video's author.
  private let authorLabel: UILabel = {
    let label = UILabel()
    label.numberOfLines = 1
    label.textAlignment = .center
    label.autoresizingMask = [.flexibleBottomMargin, .flexibleWidth]
    label.layer.masksToBounds = true
    label.layer.cornerRadius = 8
    if #available(iOS 13, *) {
      label.textColor = .label
      label.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.8)
    }
    else {
      label.textColor = .darkText
      label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
    }
    return label
  }()
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    // Add UI elements.
    thumbnailView.frame = contentView.bounds
    contentView.addSubview(thumbnailView)
    // 4pt margin around the label and a height of 48pt.
    nameLabel.frame = CGRect(x: 4, y: frame.size.height - 48 - 4, width: frame.size.width - 8, height: 48)
    contentView.addSubview(nameLabel)
    // 4 pt margin and top right.
    authorLabel.frame = CGRect(x: 4, y: 4, width: frame.size.width - 8, height: 32)
    contentView.addSubview(authorLabel)
  }
  
  required init?(coder: NSCoder) {
    fatalError("ZX2WallpaperListingCell required init is not implemented!")
  }

}