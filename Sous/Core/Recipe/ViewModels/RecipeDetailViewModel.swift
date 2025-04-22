// Copyright © 2025 Samuel K. All rights reserved.

import Foundation
import SwiftUI

@MainActor
class RecipeDetailViewModel: ObservableObject {
  @Published var description: String = "Loading..."
  @Published var errorMessage: String?
  @Published var isLoading: Bool = false

  let recipe: Recipe

  var previewData: Bool = false

  private let recipeService = RecipeService.shared
  private let logger = AppLogger.viewModel

  init(recipe: Recipe) {
    self.recipe = recipe
    logger.debug(
      "Initialized RecipeDetailViewModel for recipe: \(recipe.name, privacy: .public)"
    )
  }

  func getRecipeDescription() async {
    if previewData {
      description = "This is a preview description for \(recipe.name)."
      return
    }
    logger.info(
      "Loading description for recipe: \(self.recipe.name, privacy: .public)"
    )
    self.errorMessage = nil
    self.isLoading = true
    if self.description != "Loading..." {
      self.description = "Loading..."
      logger.debug(
        "Reset description to 'Loading...' for \(self.recipe.name, privacy: .public)"
      )
    }

    do {
      let fetchedDescription =
        try await recipeService.getRecipeDescription(
          for: recipe
        )
      guard !Task.isCancelled else {
        logger.debug(
          "Task cancelled before description could be set for \(self.recipe.name, privacy: .public)."
        )
        self.isLoading = false
        return
      }
      self.description = fetchedDescription
      self.isLoading = false
      logger.info(
        "Successfully loaded description for \(self.recipe.name, privacy: .public)."
      )
    } catch let error as RecipeServiceError {
      guard !Task.isCancelled else {
        logger.debug(
          "Task cancelled during RecipeServiceError handling for \(self.recipe.name, privacy: .public)."
        )
        self.isLoading = false
        return
      }
      logger.error(
        "RecipeServiceError loading description for \(self.recipe.name, privacy: .public): \(error.localizedDescription)"
      )
      self.description = "Description not available."
      self.errorMessage = error.localizedDescription
      self.isLoading = false
    } catch {
      guard !Task.isCancelled else {
        logger.debug(
          "Task cancelled during generic error handling for \(self.recipe.name, privacy: .public)."
        )
        self.isLoading = false
        return
      }
      logger.error(
        "Unexpected error loading recipe description for \(self.recipe.name, privacy: .public): \(error.localizedDescription)"
      )
      self.description = "Description not available."
      self.errorMessage = "An unexpected error occurred."
      self.isLoading = false
    }
  }
}
