// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

struct AppConfig {

  struct API {
    static let recipesBaseURL = "https://d3jbb8n5wk0qxi.cloudfront.net"
    // Alternate endpoints:
    //   - /recipes-malformed.json
    //   - /recipes-empty.json
    static let recipesPath = "/recipes.json"
    static var recipesURL: URL {
      URL(string: recipesBaseURL + recipesPath)!
    }
  }

  struct Cache {
    static let defaultTTL: TimeInterval = 600  // 10 minutes
    static let defaultCacheItemLimit: Int = 100

    struct Keys {
      static let recipeList = "all-recipes-list"
      static func recipeDescription(id: String) -> String {
        "recipe-description-\(id)"
      }
    }
  }
}
