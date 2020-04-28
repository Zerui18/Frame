import Foundation

/// Struct representing the api response of a category's listing.
public struct ListingAPIResponse: Codable {
    
    /// Struct representing each item (video) in the category.
    public struct Item: Codable {
        let vpath: String
        let ipath: String
        
        /// Display name.
        public let name: String
        /// Formatted size string.
        public let size: String
        
        /// URL to the video file.
        public var videoURL: URL? {
            return URL(string: vpath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        }
        
        /// URL to the webp thumbnail image.
        public var imageURL: URL? {
            return URL(string: ipath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case items = "wdata"
    }
    
    /// All items in this category.
    public let items: [Item]
    
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
                        completion(try JSONDecoder().decode(ListingAPIResponse.self, from: data!), nil)
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