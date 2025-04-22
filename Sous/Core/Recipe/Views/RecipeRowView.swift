// Copyright © 2025 Samuel K. All rights reserved.

import SwiftUI

struct RecipeRowView: View {
  @State private var cachedImageData: Data? = nil

  let recipe: Recipe

  private let cacheManager = CacheManager.shared
  private let cacheLogger = AppLogger.cache

  var body: some View {
    HStack {
      Group {
        if let data = cachedImageData, let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
        } else {
          AsyncImage(url: recipe.photoURLSmall) { image in
            image.resizable()
          } placeholder: {
            ProgressView()
          }
        }
      }
      .frame(width: 50, height: 50)
      .clipShape(Circle())

      VStack(alignment: .leading) {
        Text(recipe.name)
          .font(.headline)
          .foregroundColor(Color("TextColorPrimary"))
        Text(recipe.cuisine)
          .font(.subheadline)
          .foregroundColor(Color("TextColorSecondary"))
      }
    }
    .listRowBackground(Color("RowBackground"))
    .task {
      await loadImageFromCache()
    }
  }

  @MainActor
  private func loadImageFromCache() async {
    guard let url = recipe.photoURLSmall else { return }
    let cacheKey = url.absoluteString
    let cachedEntry = await Task.detached {
      await cacheManager.getData(for: cacheKey, as: ImageCacheData.self)
    }.value

    if let entry = cachedEntry {
      if self.cachedImageData != entry.imageData {
        self.cachedImageData = entry.imageData
        cacheLogger.trace(
          "Loaded small image from cache for \(recipe.name)"
        )
      }
    } else {
      cacheLogger.trace("Small image not in cache for \(recipe.name)")
      if self.cachedImageData != nil {
        self.cachedImageData = nil
      }
      // Load the image from the URL and cache it
      await ImageService.shared.getSmallImage(for: recipe)
    }
  }
}

#Preview {
  RecipeRowView(
    recipe: Recipe(
      id: "123",
      name: "Preview Recipe",
      cuisine: "Preview Cuisine",
      photoURLSmall: URL(
        string:
          "https://d3jbb8n5wk0qxi.cloudfront.net/photos/b9ab0071-b281-4bee-b361-ec340d405320/small.jpg"
      ),
      photoURLLarge: URL(
        string:
          "https://www.nyonyacooking.com/recipes/apam-balik~SJ5WuvsDf9WQ"
      ),
      sourceURL: URL(
        string:
          "https://www.nyonyacooking.com/recipes/apam-balik~SJ5WuvsDf9WQ"
      ),
      youtubeURL: URL(
        string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      )
    )
  )
  .padding()
}
