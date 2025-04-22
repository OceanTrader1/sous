// Copyright © 2025 Samuel K. All rights reserved.

import SwiftUI

struct HomeView: View {

  @StateObject var viewModel = RecipeViewModel()

  var body: some View {
    NavigationView {
      recipeList
        .searchable(
          text: $viewModel.searchText,
          prompt: "Search Recipes"
        )
        .navigationTitle("Recipes")
        .task {
          if viewModel.recipes.isEmpty {
            await viewModel.getRecipes()
          }
        }
        .alert(
          "Error",
          isPresented: .constant(viewModel.errorMessage != nil)
        ) {
          Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
          Text("The recipes could not be loaded. Try again later.")
        }
    }
  }

  var recipeList: some View {
    List {
      ForEach(viewModel.sortedCuisineKeys, id: \.self) { cuisine in
        if let recipesForCuisine = viewModel.groupedAndSortedRecipes[
          cuisine
        ] {
          Section(
            header: Text(cuisine).font(.title2).foregroundColor(
              Color("TextColorPrimary")
            )
          ) {
            ForEach(recipesForCuisine) { recipe in
              NavigationLink(
                destination: RecipeDetailView(recipe: recipe)
              ) {
                RecipeRowView(recipe: recipe)
              }
              .onAppear {
                Task {
                  // Preload the large image for the recipe
                  await viewModel.getLargeImage(for: recipe)
                }
              }
            }
          }
        } else {
          EmptyView()
        }
      }
    }
    .refreshable {
      await viewModel.refreshRecipes()
    }
  }
}

#Preview {
  HomeView(
    viewModel: {
      let viewModel = RecipeViewModel()
      viewModel.previewData = true
      return viewModel
    }())
}
