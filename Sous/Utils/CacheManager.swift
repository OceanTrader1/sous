// Copyright © 2025 Samuel K. All rights reserved.

import CryptoKit
import Foundation

// MARK: - Caching Protocols

/// Represents an item that can be stored in the cache.
/// Requires a timestamp to manage expiration.
protocol Cacheable: Codable {
  var timestamp: Date { get }
}

/// Defines the interface for a cache manager.
/// Allows saving and retrieving `Cacheable` items.
protocol CacheManaging {
  /// Retrieves data from the cache for a specific key and type.
  /// - Parameters:
  ///   - key: The unique identifier for the cached item.
  ///   - type: The type of the item to retrieve (must conform to `Cacheable`).
  /// - Returns: The cached item if found and not expired, otherwise `nil`.
  func getData<T: Cacheable>(for key: String, as type: T.Type) -> T?

  /// Saves data to the cache.
  /// - Parameters:
  ///   - data: The item to save (must conform to `Cacheable`).
  ///   - key: The unique identifier for the item.
  func saveData<T: Cacheable>(_ data: T, for key: String)

  /// Invalidates the cache for a specific type.
  /// - Parameter type: The type of items to remove from the cache.
  func invalidateCache<T: Cacheable>(for type: T.Type)

  /// Invalidates the entire cache, removing all items.
  func invalidateAllCaches()

}

private struct CacheEntry<T: Cacheable>: Codable {
  let item: T
  let timestamp: Date

  init(item: T) {
    self.item = item
    self.timestamp = item.timestamp
  }

  private enum CodingKeys: String, CodingKey {
    case item, timestamp
  }
}

private struct CacheEntryTimestamp: Decodable {
  let timestamp: Date
}

class CacheManager: CacheManaging {
  static let shared = CacheManager()

  private let fileManager = FileManager.default
  private lazy var baseCacheDirectory: URL = {
    guard
      let url = fileManager.urls(
        for: .cachesDirectory,
        in: .userDomainMask
      ).first?
      .appendingPathComponent("AppCacheData", isDirectory: true)
    else {
      fatalError("Could not determine cache directory.")
    }
    do {
      try fileManager.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
      logger.info("Cache base directory initialized at: \(url.path)")
    } catch {
      logger.critical(
        "Failed to create base cache directory at \(url.path): \(error.localizedDescription)"
      )
    }
    return url
  }()

  let cacheQueue = DispatchQueue(
    label: "com.fetchmobile.cachemanager.queue",
    attributes: .concurrent
  )

  private let logger = AppLogger.cache

  private var timeToLive: TimeInterval = AppConfig.Cache.defaultTTL
  private var countLimit: Int = AppConfig.Cache.defaultCacheItemLimit

  private init() {
    logger.debug(
      "CacheManager initialized with TTL: \(self.timeToLive)s, Count Limit: \(self.countLimit)"
    )
  }

  // MARK: - Configuration

  func setTimeToLive(_ ttl: TimeInterval) {
    cacheQueue.async(flags: .barrier) {
      guard ttl >= 0 else {
        self.logger.warning(
          "Attempted to set invalid TTL: \(ttl). Keeping current value: \(self.timeToLive)"
        )
        return
      }
      self.logger.info("Cache TTL updated to: \(ttl)s")
      self.timeToLive = ttl
    }
  }

  func setCountLimit(_ limit: Int) {
    cacheQueue.async(flags: .barrier) {
      guard limit >= 0 else {
        self.logger.warning(
          "Attempted to set invalid count limit: \(limit). Keeping current value: \(self.countLimit)"
        )
        return
      }
      self.logger.info("Cache count limit updated to: \(limit)")
      self.countLimit = limit
    }
  }

  // MARK: - Helper Functions for File Paths

  private func directoryURL<T>(for type: T.Type) -> URL {
    let directoryName = String(describing: T.self)
    let url = baseCacheDirectory.appendingPathComponent(
      directoryName,
      isDirectory: true
    )
    if !fileManager.fileExists(atPath: url.path) {
      do {
        try fileManager.createDirectory(
          at: url,
          withIntermediateDirectories: true,
          attributes: nil
        )
        logger.debug(
          "Created cache directory for type \(directoryName, privacy: .public) at: \(url.path)"
        )
      } catch {
        logger.error(
          "Failed to create cache directory for type \(directoryName, privacy: .public) at \(url.path): \(error.localizedDescription)"
        )
      }
    }
    return url
  }

  private func hashedKey(_ key: String) -> String {
    let inputData = Data(key.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
  }

  private func fileURL<T>(for key: String, type: T.Type) -> URL {
    let dirURL = directoryURL(for: type)
    let filename = hashedKey(key)  // Use hashed key as filename
    return dirURL.appendingPathComponent(filename).appendingPathExtension(
      "cache"
    )
  }

  // MARK: - Cache Access

  func saveData<T: Cacheable>(_ data: T, for key: String) {
    let url = fileURL(for: key, type: T.self)
    let entry = CacheEntry(item: data)  // Wrap the data
    let cacheTypeName = String(describing: T.self)

    cacheQueue.async(flags: .barrier) {
      do {
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(entry)
        try encodedData.write(to: url, options: .atomic)
        self.logger.debug(
          "Saved data for key '\(key, privacy: .public)' to file \(url.lastPathComponent) in cache \(cacheTypeName, privacy: .public)"
        )
        self.enforceCountLimit(for: T.self)

      } catch {
        self.logger.error(
          "Failed to save cache entry for key '\(key, privacy: .public)' in cache \(cacheTypeName, privacy: .public): \(error.localizedDescription)"
        )
      }
    }
  }

  func getData<T: Cacheable>(for key: String, as type: T.Type) -> T? {
    let url = fileURL(for: key, type: T.self)
    let cacheTypeName = String(describing: T.self)
    var retrievedItem: T? = nil

    cacheQueue.sync {
      guard fileManager.fileExists(atPath: url.path) else {
        logger.debug(
          "Cache miss for key '\(key, privacy: .public)' in cache \(cacheTypeName, privacy: .public)"
        )
        return
      }

      do {
        let fileData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let entry = try decoder.decode(
          CacheEntry<T>.self,
          from: fileData
        )

        let now = Date()
        let timePassed = now.timeIntervalSince(entry.timestamp)
        let currentTTL = self.timeToLive

        if timePassed <= currentTTL {
          logger.debug(
            "Cache hit for key '\(key, privacy: .public)' in cache \(cacheTypeName, privacy: .public) (Age: \(Int(timePassed))s / \(Int(currentTTL))s)"
          )
          retrievedItem = entry.item
        } else {
          logger.debug(
            "Cache expired for key '\(key, privacy: .public)' in cache \(cacheTypeName, privacy: .public) (Age: \(Int(timePassed))s > \(Int(currentTTL))s)"
          )
          self.removeFileAsync(
            at: url,
            key: key,
            cacheTypeName: cacheTypeName
          )
        }
      } catch {
        logger.error(
          "Failed to read or decode cache entry for key '\(key, privacy: .public)' in cache \(cacheTypeName, privacy: .public): \(error.localizedDescription). Removing corrupted file."
        )
        self.removeFileAsync(
          at: url,
          key: key,
          cacheTypeName: cacheTypeName
        )
      }
    }

    return retrievedItem
  }

  private func removeFileAsync(
    at url: URL,
    key: String,
    cacheTypeName: String
  ) {
    cacheQueue.async(flags: .barrier) {
      do {
        try self.fileManager.removeItem(at: url)
        self.logger.debug(
          "Removed expired/corrupted file for key '\(key, privacy: .public)' from cache \(cacheTypeName, privacy: .public)"
        )
      } catch let error as NSError
        where error.code == NSFileNoSuchFileError
      {
        self.logger.debug(
          "File for key '\(key, privacy: .public)' already removed from cache \(cacheTypeName, privacy: .public)."
        )
      } catch {
        self.logger.error(
          "Failed to remove file \(url.lastPathComponent) for key '\(key, privacy: .public)' from cache \(cacheTypeName, privacy: .public): \(error.localizedDescription)"
        )
      }
    }
  }

  // MARK: - Count Limit Enforcement

  private func enforceCountLimit<T: Cacheable>(for type: T.Type) {
    let dirURL = directoryURL(for: type)
    let cacheTypeName = String(describing: T.self)
    let currentCountLimit = self.countLimit

    guard currentCountLimit > 0 else {
      logger.trace(
        "Count limit is 0 for \(cacheTypeName, privacy: .public), skipping pruning."
      )
      return
    }

    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: dirURL,
        includingPropertiesForKeys: [.creationDateKey],
        options: .skipsHiddenFiles
      )

      guard fileURLs.count > currentCountLimit else {
        return
      }

      logger.debug(
        "Cache count limit (\(currentCountLimit)) exceeded for \(cacheTypeName, privacy: .public). Found \(fileURLs.count) items. Pruning..."
      )

      var entriesWithTimestamps: [(url: URL, timestamp: Date)] = []
      let decoder = JSONDecoder()
      for url in fileURLs {
        do {
          let fileData = try Data(contentsOf: url)
          let entryTimestamp = try decoder.decode(
            CacheEntryTimestamp.self,
            from: fileData
          )
          entriesWithTimestamps.append(
            (url: url, timestamp: entryTimestamp.timestamp)
          )
        } catch {
          logger.warning(
            "Could not read timestamp from cache file \(url.lastPathComponent) for \(cacheTypeName, privacy: .public) during pruning. Using file creation date as fallback. Error: \(error.localizedDescription)"
          )
          if let creationDate = try? url.resourceValues(forKeys: [
            .creationDateKey
          ]).creationDate {
            entriesWithTimestamps.append(
              (url: url, timestamp: creationDate)
            )
          } else {
            logger.error(
              "Could not get creation date either for \(url.lastPathComponent). Skipping file in pruning sort."
            )
          }
        }
      }

      entriesWithTimestamps.sort { $0.timestamp < $1.timestamp }

      let itemsToRemoveCount =
        entriesWithTimestamps.count - currentCountLimit
      guard itemsToRemoveCount > 0 else { return }

      logger.debug(
        "Pruning \(itemsToRemoveCount) oldest items from cache \(cacheTypeName, privacy: .public)..."
      )
      for i in 0..<itemsToRemoveCount {
        let itemToRemove = entriesWithTimestamps[i]
        do {
          try fileManager.removeItem(at: itemToRemove.url)
          logger.debug(
            "Pruned old cache file: \(itemToRemove.url.lastPathComponent) from cache \(cacheTypeName, privacy: .public) (Timestamp: \(itemToRemove.timestamp))"
          )
        } catch {
          logger.error(
            "Failed to prune cache file \(itemToRemove.url.lastPathComponent) from cache \(cacheTypeName, privacy: .public): \(error.localizedDescription)"
          )
        }
      }

    } catch let error as NSError where error.code == NSFileNoSuchFileError {
      logger.debug(
        "Cache directory for \(cacheTypeName, privacy: .public) not found during pruning, likely already invalidated."
      )
    } catch {
      logger.error(
        "Failed to enforce count limit for cache \(cacheTypeName, privacy: .public): \(error.localizedDescription)"
      )
    }
  }

  // MARK: - Cache Invalidation (Conforming to CacheManaging)

  func invalidateCache<T: Cacheable>(for type: T.Type) {
    let dirURL = directoryURL(for: type)
    let cacheTypeName = String(describing: T.self)

    cacheQueue.async(flags: .barrier) {
      do {
        try self.fileManager.removeItem(at: dirURL)
        try self.fileManager.createDirectory(
          at: dirURL,
          withIntermediateDirectories: true,
          attributes: nil
        )
        self.logger.info(
          "Invalidated cache for type \(cacheTypeName, privacy: .public)"
        )
      } catch let error as NSError
        where error.code == NSFileNoSuchFileError
      {
        self.logger.debug(
          "Cache directory for \(cacheTypeName, privacy: .public) did not exist during invalidation attempt."
        )
        try? self.fileManager.createDirectory(
          at: dirURL,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        self.logger.error(
          "Failed to invalidate cache for type \(cacheTypeName, privacy: .public): \(error.localizedDescription)"
        )
      }
    }
  }

  func invalidateAllCaches() {
    cacheQueue.async(flags: .barrier) {
      do {
        try self.fileManager.removeItem(at: self.baseCacheDirectory)
        try self.fileManager.createDirectory(
          at: self.baseCacheDirectory,
          withIntermediateDirectories: true,
          attributes: nil
        )
        self.logger.info(
          "Invalidated all caches at \(self.baseCacheDirectory.path)"
        )
      } catch let error as NSError
        where error.code == NSFileNoSuchFileError
      {
        self.logger.debug(
          "Base cache directory did not exist during invalidation attempt."
        )
        try? self.fileManager.createDirectory(
          at: self.baseCacheDirectory,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        self.logger.error(
          "Failed to invalidate all caches: \(error.localizedDescription)"
        )
      }
    }
  }
}
