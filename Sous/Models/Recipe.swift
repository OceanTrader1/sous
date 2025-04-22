// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

struct Recipes: Codable {
  let recipes: [Recipe]
}

struct Recipe: Identifiable, Codable, Hashable {
  let id: String
  let name: String
  let cuisine: String
  let photoURLSmall: URL?
  let photoURLLarge: URL?
  let sourceURL: URL?
  let youtubeURL: URL?

  enum CodingKeys: String, CodingKey {
    case id = "uuid"
    case name
    case cuisine
    case photoURLSmall = "photo_url_small"
    case photoURLLarge = "photo_url_large"
    case sourceURL = "source_url"
    case youtubeURL = "youtube_url"
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    cuisine = try container.decode(String.self, forKey: .cuisine)

    photoURLSmall = try container.decodeIfPresent(
      URL.self,
      forKey: .photoURLSmall
    )?.convertToHTTPS()
    photoURLLarge = try container.decodeIfPresent(
      URL.self,
      forKey: .photoURLLarge
    )?.convertToHTTPS()
    sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)?
      .convertToHTTPS()
    youtubeURL = try container.decodeIfPresent(
      URL.self,
      forKey: .youtubeURL
    )?.convertToHTTPS()
  }

  init(
    id: String,
    name: String,
    cuisine: String,
    photoURLSmall: URL? = nil,
    photoURLLarge: URL? = nil,
    sourceURL: URL? = nil,
    youtubeURL: URL? = nil
  ) {
    self.id = id
    self.name = name
    self.cuisine = cuisine
    self.photoURLSmall = photoURLSmall?.convertToHTTPS()
    self.photoURLLarge = photoURLLarge?.convertToHTTPS()
    self.sourceURL = sourceURL?.convertToHTTPS()
    self.youtubeURL = youtubeURL?.convertToHTTPS()
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Recipe, rhs: Recipe) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - URL Extension for HTTPS Conversion

extension URL {
  /// Attempts to convert the URL scheme to HTTPS.
  /// - Returns: A new URL with the HTTPS scheme, or the original URL if conversion fails or is unnecessary.
  ///            Returns `nil` if the original URL was fundamentally invalid for components.
  func convertToHTTPS() -> URL? {
    guard
      var components = URLComponents(
        url: self,
        resolvingAgainstBaseURL: true
      )
    else {
      print(
        "Warning: Could not create URLComponents for URL: \(self.absoluteString)"
      )
      return self
    }

    if components.scheme?.lowercased() == "https" {
      return self
    }

    if components.scheme?.lowercased() == "http" || components.scheme == nil
      || components.scheme?.isEmpty == true
    {
      components.scheme = "https"
      guard let httpsURL = components.url else {
        print(
          "Warning: Failed to convert URL to HTTPS after setting scheme: \(self.absoluteString)"
        )
        return self
      }
      return httpsURL
    } else {
      print(
        "Info: URL scheme is neither HTTP nor HTTPS, retaining original: \(self.absoluteString)"
      )
      return self
    }
  }
}
