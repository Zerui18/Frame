import Foundation

protocol ListingItemRepresentable {
    var imageURL: URL { get }
    var name: String { get }
    var sizeString: String { get }
}

/// Struct representing the api response of a category's listing.
public struct ListingAPIResponse: Codable {
    
    /// Struct representing each item (video) in the category.
    public struct Item: Codable, ListingItemRepresentable {
        let vpath: String
        let ipath: String
        
        /// Display name.
        public let name: String
        /// Formatted size string.
        public let size: String

        public var sizeString: String {
            size.split(separator: "\n").first.flatMap(String.init) ?? ""
        }
        
        /// URL to the video file.
        public var videoURL: URL {
            URL(string: vpath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        }
        
        /// URL to the webp thumbnail image.
        public var imageURL: URL { 
            URL(string: ipath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        }

        public var videoCacheURL: URL {
            URL(fileURLWithPath: "/var/mobile/Documents/com.ZX02.Frame/Cache/Videos/\(name).mp4")
        }

        public var imageCacheURL: URL {
            URL(fileURLWithPath: "/var/mobile/Documents/com.ZX02.Frame/Cache/Thumbs/\(name).webp")
        }

        /// Save the thumbnail image and then downloads the video to the cache path.
        /// Performs cleanup if fails at any stage.
        public func save(onProgress block: @escaping (Float) -> Void, onCompletion callback: @escaping (Error?) -> Void) {
            Downloader.shared.download(self, onProgress: block, onCompletion: callback)
        }

        /// Checks if this item has been saved.
        public var isSaved: Bool {
            FileManager.default.fileExists(atPath: videoCacheURL.path)
        }

        /// Delete the item from cache.
        public func delete() {
            try? FileManager.default.removeItem(atPath: videoCacheURL.path)
            try? FileManager.default.removeItem(atPath: imageCacheURL.path)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case items = "wdata"
    }
    
    /// All items in this category.
    public var items: [Item]
    
}

/// The english translation for the important category names.
fileprivate let englishNames = ["最新" : "Latest", "推荐" : "Recommended", "景观" : "Landscapes", "动漫" : "Anime", "游戏" : "Games", "其它" : "Abstract"]

/// The categories to be filtered out.
fileprivate let filteredNames = ["小姐姐", "再淘一下", "公告"]

/// Struct representing the api response of the root/index categories.
public struct IndexAPIResponse: Codable {
    
    /// Struct representing each category.
    public struct Item: Codable {
        public let name: String
        let path: String

        /// The property that should be accessed for the displayed name.
        public var displayName: String {
            return englishNames[name] ?? name
        }
        
        /// The URL to this category's listing.
        public var url: URL? {
            return URL(string: path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        }
        
        /// Fetch the listing of this category with a completion handler.
        public func fetchListing(completion: @escaping (ListingAPIResponse?, Error?)-> Void) {
            URLSession.shared.dataTask(with: url!) { (data, _, error) in
                if error != nil {
                    completion(nil, error)
                }
                else {
                    do {
                        var response = try JSONDecoder().decode(ListingAPIResponse.self, from: data!)
                        // Remove the update notice.
                        if response.items.first?.size == "32.78MB" {
                            response.items.remove(at: 0)
                        }
                        completion(response, nil)
                    }
                    catch {
                        completion(nil, error)
                    }
                }
            }.resume()
        }
    }
    
    public enum CodingKeys: String, CodingKey {
        case items = "item", allURL = "all"
    }
    
    /// All categories.
    public private(set) var items: [Item]
    /// URL to the "all" category's listing.
    public let allURL: String
    
    /// Convenience method to fetch a new response given a completion callback, optionally specifying an overriding api url.
    public static func fetch(from url: URL = URL(string: "https://api-20200209.xkspbz.com/index.json")!,
                            completion: @escaping (IndexAPIResponse?, Error?)-> Void) {
        URLSession.shared.dataTask(with: url) { (data, _, error) in
            if error != nil {
                completion(nil, error)
            }
            else {
                do {
                    var response = try JSONDecoder().decode(IndexAPIResponse.self, from: data!)
                    response.items.removeAll { filteredNames.contains($0.name) }
                    completion(response, nil)
                }
                catch {
                    completion(nil, error)
                }
            }
        }.resume()
    }
    
}

// MARK: CachedWallpaper
struct CachedWallpaper : Equatable, ListingItemRepresentable {
  let name: String
  let size: UInt64

  var imageURL: URL {
    URL(fileURLWithPath: "/var/mobile/Documents/com.ZX02.Frame/Cache/Thumbs/\(name).webp")
  }
  var videoURL: URL {
    URL(fileURLWithPath: "/var/mobile/Documents/com.ZX02.Frame/Cache/Videos/\(name).mp4")
  }
  var sizeString: String {
    ByteCountFormatter.string(fromByteCount: Int64(self.size), countStyle: .file)
  }

  /// Delete the files for this wallpaper.
  func deleteFiles() {
      try? FileManager.default.removeItem(atPath: imageURL.path)
      try? FileManager.default.removeItem(atPath: videoURL.path)
  }

  /// Retrieve a listing of all the video files.
  static func getListing() -> [CachedWallpaper] {
    // Get all the video files, along with the desired attributes.
    guard let urls = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: "/var/mobile/Documents/com.ZX02.Frame/Cache/Videos/"),
                                                                        includingPropertiesForKeys: Array(allocatedSizeResourceKeys))
    else { return [] }
    return urls.map { url in
      // Get display name.
      var name = url.lastPathComponent
      name.removeLast(4)
      // Get size.
      let size = (try? url.regularFileAllocatedSize()) ?? 0
      return CachedWallpaper(name: name, size: size)
    }
  }

  // MARK: Equatable
  static func ==(_ lhs: CachedWallpaper, _ rhs: CachedWallpaper) -> Bool {
      return lhs.name == rhs.name
  }
}

// MARK: URL Extension
fileprivate let allocatedSizeResourceKeys: Set<URLResourceKey> = [
    .isRegularFileKey,
    .fileAllocatedSizeKey,
    .totalFileAllocatedSizeKey,
]

fileprivate extension URL {

    func regularFileAllocatedSize() throws -> UInt64 {
        let resourceValues = try self.resourceValues(forKeys: allocatedSizeResourceKeys)

        // We only look at regular files.
        guard resourceValues.isRegularFile ?? false else {
            return 0
        }

        // To get the file's size we first try the most comprehensive value in terms of what
        // the file may use on disk. This includes metadata, compression (on file system
        // level) and block size.
        // In case totalFileAllocatedSize is unavailable we use the fallback value (excluding
        // meta data and compression) This value should always be available.
        return UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
    }
}