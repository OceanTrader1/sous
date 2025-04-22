// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

struct ImageCacheData: Cacheable, Codable {
  let imageData: Data
  let timestamp: Date
}

class ImageService {
  static let shared = ImageService()

  private let urlSession: URLSession = .shared
  private let cacheManager: CacheManaging = CacheManager.shared
  private let cacheLogger = AppLogger.cache
  private let networkLogger = AppLogger.network

  init() {}

  // MARK: - Image Caching and Preloading

  func getLargeImage(for recipe: Recipe) async {
    guard let imageURL = recipe.photoURLLarge else {
      cacheLogger.debug(
        "Skipping image preload for '\(recipe.name, privacy: .public)'."
      )
      return
    }
    await getCachedImage(for: imageURL)
  }

  func getSmallImage(for recipe: Recipe) async {
    guard let imageURL = recipe.photoURLSmall else {
      cacheLogger.debug(
        "Skipping image preload for '\(recipe.name, privacy: .public)'."
      )
      return
    }
    await getCachedImage(for: imageURL)
  }

  /// Initiates fetching and caching for a recipe's image if it's not already cached.
  /// Prefers the large image URL, falls back to the small one.
  /// - Parameter recipe: The `Recipe` object containing image URLs.
  private func getCachedImage(for url: URL) async {
    guard let httpsImageURL = url.convertToHTTPS() else {
      return
    }

    let imageCacheKey = httpsImageURL.absoluteString
    await getImage(url: httpsImageURL, cacheKey: imageCacheKey)
  }

  /// Fetches an image from the network and caches it, but only if it's not already in the cache.
  /// - Parameters:
  ///   - url: The HTTPS URL of the image to fetch.
  ///   - cacheKey: The key to use for caching (typically the URL string).
  private func getImage(url: URL, cacheKey: String) async {
    if self.cacheManager.getData(for: cacheKey, as: ImageCacheData.self) != nil {
      cacheLogger.trace(
        "Image already cached for key: \(cacheKey, privacy: .public)."
      )
      return
    }

    networkLogger.debug(
      "Fetch and cache image from URL: \(url.absoluteString)"
    )
    do {
      let (data, response) = try await self.urlSession.data(from: url)
      try validateHTTPResponse(
        response,
        context: "fetching image \(url.lastPathComponent)"
      )
      guard !data.isEmpty else {
        networkLogger.warning(
          "Received empty data for image: \(url.absoluteString)"
        )
        throw RecipeServiceError.missingData
      }

      let cacheEntry = ImageCacheData(imageData: data, timestamp: Date())
      self.cacheManager.saveData(cacheEntry, for: cacheKey)
      cacheLogger.debug(
        "Successfully fetched and cached image for key: \(cacheKey, privacy: .public)"
      )

    } catch let error as RecipeServiceError {
      networkLogger.error(
        "RecipeServiceError fetching image \(url.absoluteString): \(error.localizedDescription)"
      )
    } catch let error as URLError {
      networkLogger.error(
        "Network error fetching image \(url.absoluteString): \(error.localizedDescription)"
      )
    } catch {
      networkLogger.error(
        "Unexpected error fetching image \(url.absoluteString): \(error.localizedDescription)"
      )
    }
  }

  /// Validates the HTTP response status code.
  /// - Parameters:
  ///   - response: The `URLResponse` received from the network request.
  ///   - context: A string describing the operation for logging purposes.
  /// - Throws: `RecipeServiceError.invalidResponse` if the status code is not in the 200-299 range.
  private func validateHTTPResponse(_ response: URLResponse, context: String) throws {
    guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode)
    else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode
      networkLogger.error(
        "Invalid server response \(context). Status: \(statusCode ?? -1)"
      )
      throw RecipeServiceError.invalidResponse(statusCode)
    }
  }
}
