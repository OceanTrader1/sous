// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

@MainActor
class RecipeViewModel: ObservableObject {
  @Published var recipes: [Recipe] = []
  @Published var errorMessage: String?
  @Published var searchText = ""

  var previewData: Bool = false

  private let recipeService: RecipeService = RecipeService.shared
  private let imageService: ImageService = ImageService.shared
  private let cacheManager: CacheManaging = CacheManager.shared
  private let logger = AppLogger.viewModel

  func getRecipes() async {
    if previewData {
      loadMockRecipes()
    }
    logger.info("Attempting to load recipes.")
    self.errorMessage = nil
    do {
      let recipes = try await recipeService.fetchRecipes()
      self.recipes = recipes.sorted { $0.name < $1.name }
      logger.info(
        "Successfully loaded and sorted \(recipes.count) recipes."
      )
    } catch let error as LocalizedError {
      logger.error("Error loading recipes: \(error.localizedDescription)")
      errorMessage = error.localizedDescription
    } catch {
      logger.error(
        "An unexpected error occurred while loading recipes: \(error.localizedDescription)"
      )
      errorMessage = "An unexpected error occurred while loading recipes."
    }
  }

  func getUrlDescription(for recipe: Recipe) async {
    logger.debug(
      "Preloading description for \(recipe.name, privacy: .public)"
    )
    do {
      _ = try await recipeService.getRecipeDescription(for: recipe)
      logger.debug(
        "Successfully preloaded and cached description for \(recipe.name, privacy: .public)"
      )
    } catch {
      logger.warning(
        "Failed to preload description for \(recipe.name, privacy: .public): \(error.localizedDescription)"
      )
    }
  }

  func getLargeImage(for recipe: Recipe) async {
    logger.debug("Loading image for \(recipe.name, privacy: .public)")
    await imageService.getLargeImage(for: recipe)
  }

  func refreshRecipes() async {
    logger.info("Refreshing recipes list.")
    cacheManager.invalidateCache(for: RecipeListCache.self)
    logger.debug("Recipe list cache invalidated.")
    await getRecipes()
  }

  private func loadMockRecipes() {
    recipes = [
      Recipe(id: "1", name: "Spaghetti Carbonara", cuisine: "Italian"),
      Recipe(id: "2", name: "Chicken Tikka Masala", cuisine: "Indian"),
      Recipe(id: "3", name: "Sushi Roll", cuisine: "Japanese"),
      Recipe(id: "4", name: "Tacos", cuisine: "Mexican"),
    ]
  }

  var groupedAndSortedRecipes: [String: [Recipe]] {
    let filteredRecipes: [Recipe]
    if searchText.isEmpty {
      filteredRecipes = recipes
    } else {
      filteredRecipes = recipes.filter {
        $0.name.localizedCaseInsensitiveContains(searchText)
      }
    }

    let grouped = Dictionary(grouping: filteredRecipes, by: { $0.cuisine })
    let sortedGroups = grouped.mapValues { recipesInGroup in
      recipesInGroup.sorted { $0.name < $1.name }
    }

    return sortedGroups
  }

  var sortedCuisineKeys: [String] {
    groupedAndSortedRecipes.keys.sorted()
  }

}
