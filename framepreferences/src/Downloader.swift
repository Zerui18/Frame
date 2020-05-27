/// Helper function to create a directory and the intermediate directories at the give URL if not existing.
func createDirectory(at url: URL) -> Error? {
  if !FileManager.default.fileExists(atPath: url.path) {
    do {
      try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true, attributes: [.posixPermissions : 511])
    }
    catch {
      return error
    }
  }
  return nil
}

/// Very simply downloader that handles single downloads.
public final class Downloader : NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {

  // MARK: Properties
  private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
  private var currentTask: URLSessionDownloadTask?
  private var dstURL: URL?

  // MARK: Public API
  public static let shared = Downloader()

  public typealias ProgressCallback = (Float) -> Void
  public typealias CompletionCallback = (Error?) -> Void

  public var onProgress: ProgressCallback?
  public var onCompletion: CompletionCallback?

  /// Downloads a file form the srcURL to the dstURL.
  public func download(_ srcURL: URL, to dstURL: URL) {
    if self.currentTask != nil {
      self.currentTask!.cancel()
    }
    self.dstURL = dstURL
    // Create the dstURL's containing folder(s) if necessary.
    let dstFolder = dstURL.deletingLastPathComponent()
    if let error = createDirectory(at: dstFolder) {
      self.onCompletion?(error)
      return
    }
    
    let request = URLRequest(url: srcURL)
    currentTask = session.downloadTask(with: request)
    currentTask!.resume()
  }

  /// Cancels the current download, if any.
  public func cancel() {
    currentTask?.cancel()
    currentTask = nil
    dstURL = nil
  }

  // MARK: URLSessionTaskDelegate Conformance
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if (task !== self.currentTask) { return }
    // Pass errors to the registered callback.
    if (error != nil) {
      self.onCompletion?(error)
      self.onCompletion = nil
      self.currentTask = nil
    }
    self.onProgress = nil
  }

  // MARK: URLSessionDownloadDelegate Conformance
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    if (downloadTask !== self.currentTask) { return }
    do {
      try FileManager.default.replaceItem(at: self.dstURL!, withItemAt: location, backupItemName: nil, resultingItemURL: nil)
      self.onCompletion?(nil)
    }
    catch {
      self.onCompletion?(error)
    }
    self.onCompletion = nil
    self.currentTask = nil
  }

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    if (downloadTask !== self.currentTask) { return }
    let ratio = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    self.onProgress?(ratio)
  }

}

// ZX2XKAPI Integration
extension Downloader {

  // MARK: Public API
  public func download(_ item: ListingAPIResponse.Item, onProgress: @escaping ProgressCallback, onCompletion: @escaping CompletionCallback) {
    DispatchQueue.global().async {
      // Download thumbnail.
      let srcURL = item.imageURL
      let dstURL = item.imageCacheURL
      // Create directory if necessary.
      if let error = createDirectory(at: dstURL.deletingLastPathComponent()) {
        onCompletion(error)
        return
      }

      // Download image.
      do {
        let data = try Data(contentsOf: srcURL)
        try data.write(to: dstURL)
      }
      catch {
        onCompletion(error)
        return
      }

      // Download video.
      self.onProgress = onProgress
      self.onCompletion = { error in
        // Remove thumbnail if video download errors out.
        if error != nil {
          try? FileManager.default.removeItem(atPath: item.imageCacheURL.path)
        }
        onCompletion(error)
      }
      self._downloadVideo(item)
    }
  }

  // MARK: Private
  fileprivate func _downloadVideo(_ item: ListingAPIResponse.Item) {
    let srcURL = item.videoURL
    let dstURL = item.videoCacheURL
    
    // Initiate download.
    self.download(srcURL, to: dstURL)
  }

}