// MARK: Crypto Configs
fileprivate let iv = Data(repeating: 0, count: 16)
fileprivate let key = sha256(data: "9i98X0OxViK1oJhyHnOAUKRMAdHy8jy2Ik8Xv6xJ5A4oRDLD".data(using: .ascii)!)
fileprivate let aes = AES(key: key, iv: iv)

fileprivate func decryptAndUnzip(data: Data) -> Data? {
    Data(base64Encoded: data)
        .flatMap {
            aes.decrypt(data: $0)
        }
        .flatMap {
            Data(base64Encoded: $0)
        }.flatMap {
            try? $0.gunzipped()
        }
}

fileprivate func fetchAndDecode<T: Codable>(from url: URL, completion: @escaping (T?, Error?) -> Void) {
    URLSession.shared.dataTask(with: url) { (data, _, error) in
        if error != nil {
            completion(nil, error)
        }
        else {
            do {
                // First decrypt the data.
                guard let decryptedData = decryptAndUnzip(data: data!) else {
                    let err = NSError(domain: "com.zx02.frameprefs", code: 0, userInfo: [NSLocalizedDescriptionKey : "Failed to decrypt data."])
                    completion(nil, err)
                    return
                }
                // Then decode as object.
                let object = try JSONDecoder().decode(T.self, from: decryptedData)
                completion(object, nil)
            }
            catch {
                completion(nil, error)
            }
        }
    }.resume()
}

// MARK: Actual API
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

        /// Intelligently extract the actual size from the long desc.
        public var sizeString: String {
            let parts = size.split(separator: "\n")
            if parts.count == 0 {
                return "??"
            }
            else if parts.count == 1 {
                return String(parts[0])
            }
            // Find the segment containing "MB", or default to the first segment.
            else {
                return String(parts.first(where: { $0.contains("MB") }) ?? parts[0])
            }
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
            fetchAndDecode(from: url!) { (data: ListingAPIResponse?, error) in
                guard error == nil else {
                    completion(nil, error)
                    return
                }
                var response = data!
                // Remove the update notice.
                if response.items.first?.size == "32.78MB" {
                    response.items.remove(at: 0)
                }
                completion(response, nil)
            }
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
    public static func fetch(from url: URL = URL(string: "http://api-20200527.xkspbz.com/admin.json")!,
                            completion: @escaping (IndexAPIResponse?, Error?)-> Void) {
        fetchAndDecode(from: url) { (object: IndexAPIResponse?, error) in
            guard error == nil else {
                completion(nil, error)
                return
            }
            var response = object!
            response.items.removeAll { filteredNames.contains($0.name) }
            completion(response, nil)
        }
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
