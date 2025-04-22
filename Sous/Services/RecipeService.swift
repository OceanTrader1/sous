// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

struct RecipeListCache: Cacheable, Codable {
  let recipes: [Recipe]
  let timestamp: Date
}

struct RecipeDescriptionCache: Cacheable, Codable {
  let recipeId: String
  let description: String
  let timestamp: Date
}

class RecipeService {
  static let shared = RecipeService()

  private let cacheManager: CacheManaging = CacheManager.shared
  private let urlSession: URLSession = .shared
  private let htmlParser: HTMLParsing = DefaultHTMLParser()
  private let networkLogger = AppLogger.network
  private let cacheLogger = AppLogger.cache
  private let generalLogger = AppLogger.general

  init() {}

  // MARK: - Fetch Recipes

  /// Fetches a list of recipes, utilizing cache first.
  /// - Returns: An array of `Recipe` objects.
  /// - Throws: `RecipeServiceError` if fetching or decoding fails.
  func fetchRecipes() async throws -> [Recipe] {
    let cacheKey = AppConfig.Cache.Keys.recipeList

    if let cachedData = self.cacheManager.getData(
      for: cacheKey,
      as: RecipeListCache.self
    ) {
      self.cacheLogger.info("Retrieving recipes from cache.")
      return cachedData.recipes
    }

    do {
      let data = try await fetchRecipesDataFromUrl()
      let recipes = try decodeRecipes(from: data)
      cacheRecipes(recipes, forKey: cacheKey)
      return recipes
    } catch {
      self.generalLogger.error(
        "Failed to fetch, decode, or cache recipes: \(error.localizedDescription)"
      )
      if let recipeError = error as? RecipeServiceError {
        throw recipeError
      } else {
        throw error
      }
    }
  }

  private func fetchRecipesDataFromUrl() async throws -> Data {
    let url = AppConfig.API.recipesURL
    self.networkLogger.info(
      "Fetching recipes from URL: \(url.absoluteString)"
    )
    do {
      let (data, response) = try await self.urlSession.data(
        for: URLRequest(url: url)
      )
      try validateHTTPResponse(response, context: "fetching recipes")
      guard !data.isEmpty else {
        networkLogger.warning(
          "Received empty data when fetching recipes."
        )
        throw RecipeServiceError.missingData
      }
      return data
    } catch let error as URLError {
      self.networkLogger.error(
        "Network error fetching recipes: \(error.localizedDescription)"
      )
      throw RecipeServiceError.networkError(error)
    } catch {
      self.networkLogger.error(
        "Unexpected error fetching recipes: \(error.localizedDescription)"
      )
      throw error
    }
  }

  private func decodeRecipes(from data: Data) throws -> [Recipe] {
    let decoder = JSONDecoder()
    do {
      let recipesContainer = try decoder.decode(
        Recipes.self,
        from: data
      )
      return recipesContainer.recipes
    } catch let error as DecodingError {
      self.generalLogger.error(
        "Decoding error for recipes: \(error.detailDescription)"
      )
      throw RecipeServiceError.decodingError(error)
    } catch {
      self.generalLogger.error(
        "Unexpected error during recipe decoding: \(error.localizedDescription)"
      )
      throw RecipeServiceError.decodingError(error)
    }
  }

  private func cacheRecipes(_ recipes: [Recipe], forKey key: String) {
    let cacheEntry = RecipeListCache(recipes: recipes, timestamp: Date())
    self.cacheManager.saveData(cacheEntry, for: key)
    self.cacheLogger.info("Saved fetched recipes to cache.")
  }

  // MARK: - Fetch Recipe Description

  /// Fetches the description for a specific recipe, utilizing cache first.
  /// - Parameter recipe: The `Recipe` object.
  /// - Returns: The recipe description string.
  /// - Throws: `RecipeServiceError` if fetching, parsing, or caching fails.
  func getRecipeDescription(for recipe: Recipe) async throws -> String {
    let cacheKey = AppConfig.Cache.Keys.recipeDescription(id: recipe.id)
    let recipeName = recipe.name  // For logging context

    if let cachedData = self.cacheManager.getData(
      for: cacheKey,
      as: RecipeDescriptionCache.self
    ) {
      self.cacheLogger.info(
        "Retrieved description for '\(recipeName, privacy: .public)' from cache."
      )
      return cachedData.description
    }

    self.cacheLogger.debug(
      "No valid description found in cache for key: \(cacheKey, privacy: .public). Fetching from network."
    )

    do {
      let description = try await getDescriptionFromURL(for: recipe)
      cacheDescription(
        description,
        forKey: cacheKey,
        recipeId: recipe.id,
        recipeName: recipeName
      )
      return description
    } catch {
      self.generalLogger.error(
        "Failed to get description for '\(recipeName, privacy: .public)': \(error.localizedDescription)"
      )
      if let recipeError = error as? RecipeServiceError {
        throw recipeError
      } else {
        throw error
      }
    }
  }

  private func getDescriptionFromURL(for recipe: Recipe) async throws
    -> String
  {
    let recipeName = recipe.name
    let sourceURL = try validateSourceURL(for: recipe)
    let htmlData = try await fetchHTMLData(
      from: sourceURL,
      recipeName: recipeName
    )
    let htmlString = try decodeHTMLData(htmlData, recipeName: recipeName)
    let description = try parseDescription(
      fromHTML: htmlString,
      recipeName: recipeName
    )

    return description
  }

  private func validateSourceURL(for recipe: Recipe) throws -> URL {
    guard let sourceURL = recipe.sourceURL?.convertToHTTPS() else {
      self.generalLogger.warning(
        "No valid source URL for recipe: \(recipe.name, privacy: .public)"
      )
      throw RecipeServiceError.invalidSourceURL
    }
    return sourceURL
  }

  private func fetchHTMLData(from url: URL, recipeName: String) async throws
    -> Data
  {
    self.networkLogger.info(
      "Fetching description for '\(recipeName, privacy: .public)' from network: \(url.absoluteString)"
    )
    do {
      // Apple's URLSession on the simulator has a known issue with TLS versions.
      // https://developer.apple.com/forums/thread/777999
      let (data, response) = try await self.urlSession.data(from: url)
      try validateHTTPResponse(
        response,
        context: "fetching description for \(recipeName)"
      )
      guard !data.isEmpty else {
        self.networkLogger.warning(
          "Received empty data when fetching description for \(recipeName, privacy: .public)."
        )
        throw RecipeServiceError.missingData
      }
      return data
    } catch let error as URLError {
      self.networkLogger.error(
        "Network error fetching description for \(recipeName, privacy: .public): \(error.localizedDescription)"
      )
      throw RecipeServiceError.networkError(error)
    } catch let error as RecipeServiceError {
      throw error
    } catch {
      self.networkLogger.error(
        "Unexpected error fetching description HTML for \(recipeName, privacy: .public): \(error.localizedDescription)"
      )
      throw error
    }
  }

  private func decodeHTMLData(_ data: Data, recipeName: String) throws
    -> String
  {
    if let html = String(data: data, encoding: .utf8)
      ?? String(data: data, encoding: .isoLatin1)
    {
      return html
    } else {
      self.generalLogger.error(
        "Cannot decode description HTML data to String for \(recipeName, privacy: .public)."
      )
      let error = NSError(
        domain: NSCocoaErrorDomain,
        code: NSFileReadCorruptFileError,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Failed to decode HTML data using common encodings."
        ]
      )
      throw RecipeServiceError.decodingError(error)
    }
  }

  private func parseDescription(fromHTML html: String, recipeName: String)
    throws -> String
  {
    do {
      let description = try htmlParser.parseMetaDescription(
        fromHTML: html
      )
      guard !description.isEmpty else {
        generalLogger.warning(
          "Parsed description meta tag content is empty for \(recipeName, privacy: .public)."
        )
        throw RecipeServiceError.descriptionNotFound
      }
      return description
    } catch let error as HTMLParserError {
      self.generalLogger.error(
        "HTMLParserError for \(recipeName, privacy: .public): \(error.localizedDescription)"
      )
      switch error {
      case .descriptionMetaTagNotFound:
        throw RecipeServiceError.descriptionNotFound
      case .parsingFailed(let underlyingError):
        throw RecipeServiceError.htmlParsingError(underlyingError)
      }
    } catch let error as RecipeServiceError {
      throw error
    } catch {
      self.generalLogger.error(
        "Unexpected error during HTML parsing for \(recipeName, privacy: .public): \(error.localizedDescription)"
      )
      throw RecipeServiceError.htmlParsingError(error)
    }
  }

  private func cacheDescription(
    _ description: String,
    forKey key: String,
    recipeId: String,
    recipeName: String
  ) {
    let cacheEntry = RecipeDescriptionCache(
      recipeId: recipeId,
      description: description,
      timestamp: Date()
    )
    self.cacheManager.saveData(cacheEntry, for: key)
    self.cacheLogger.info(
      "Saved description for '\(recipeName, privacy: .public)' to cache."
    )
  }

  private func validateHTTPResponse(_ response: URLResponse, context: String)
    throws
  {
    guard let httpResponse = response as? HTTPURLResponse else {
      networkLogger.error(
        "Invalid response type received \(context). Expected HTTPURLResponse."
      )
      throw RecipeServiceError.invalidResponse(nil)
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      self.networkLogger.error(
        "Invalid server response \(context). Status: \(httpResponse.statusCode)"
      )
      throw RecipeServiceError.invalidResponse(httpResponse.statusCode)
    }
  }
}
