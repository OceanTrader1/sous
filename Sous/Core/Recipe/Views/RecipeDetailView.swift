// Copyright © 2025 Samuel K. All rights reserved.

import SwiftUI

struct RecipeDetailView: View {
  @StateObject private var viewModel: RecipeDetailViewModel
  @State private var cachedImageData: Data? = nil

  private let cacheManager = CacheManager.shared
  private let cacheLogger = AppLogger.cache

  init(recipe: Recipe) {
    _viewModel = StateObject(
      wrappedValue: RecipeDetailViewModel(
        recipe: recipe,
      )
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        recipeImage(url: viewModel.recipe.photoURLLarge)
          .padding(.bottom)

        Text("Description")
          .font(.title2)
          .padding(.bottom, 2)
          .foregroundColor(Color("TextColorPrimary"))

        Text(viewModel.description)
          .font(.body)
          .foregroundColor(Color("TextColorSecondary"))
          .frame(maxWidth: .infinity, alignment: .leading)

        if let youtubeURL = viewModel.recipe.youtubeURL {
          Divider()
            .padding(.vertical)

          Link(destination: youtubeURL) {
            HStack {
              Image(systemName: "play.rectangle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(.red)

              Text("See how it's made...")
                .font(.headline)
                .foregroundColor(.accentColor)
            }
          }
          .padding(.bottom)
        }
        Spacer()
      }
      .padding()
    }
    .navigationTitle(viewModel.recipe.name)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      async let descriptionLoad: () = viewModel.getRecipeDescription()
      async let imageCacheLoad: () = loadImageFromCache()

      await descriptionLoad
      await imageCacheLoad
    }
  }

  private func recipeImage(url: URL?) -> some View {
    Group {
      if let data = cachedImageData, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity)
      } else {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            Rectangle()
              .fill(Color.gray.opacity(0.1))
              .aspectRatio(1.0, contentMode: .fit)
              .overlay(ProgressView())
              .frame(maxWidth: .infinity)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: .infinity)
          case .failure:
            Rectangle()
              .fill(Color.gray.opacity(0.1))
              .aspectRatio(1.0, contentMode: .fit)
              .overlay(
                Image(systemName: "photo.fill")
                  .foregroundColor(.gray)
                  .font(.largeTitle)
              )
              .frame(maxWidth: .infinity)
          @unknown default:
            Rectangle()
              .fill(Color.gray.opacity(0.1))
              .aspectRatio(1.0, contentMode: .fit)
              .overlay(
                Image(systemName: "photo.fill")
                  .foregroundColor(.gray)
                  .font(.largeTitle)
              )
          }
        }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  @MainActor
  private func loadImageFromCache() async {
    guard let url = viewModel.recipe.photoURLLarge else { return }
    let cacheKey = url.absoluteString
    let cachedEntry = await Task.detached {
      await cacheManager.getData(for: cacheKey, as: ImageCacheData.self)
    }.value

    if let entry = cachedEntry {
      if self.cachedImageData != entry.imageData {
        self.cachedImageData = entry.imageData
        cacheLogger.trace(
          "Loaded large image from cache for \(viewModel.recipe.name)"
        )
      }
    } else {
      cacheLogger.trace(
        "Large image not in cache for \(viewModel.recipe.name)"
      )
      if self.cachedImageData != nil {
        self.cachedImageData = nil
      }
    }
  }
}

#Preview {
  NavigationView {
    RecipeDetailView(
      recipe: Recipe(
        id: "123",
        name: "Preview Recipe",
        cuisine: "Preview Cuisine",
        photoURLSmall: URL(
          string:
            "https://d3jbb8n5wk0qxi.cloudfront.net/photos/b9ab0071-b281-4bee-b361-ec340d405320/small.jpg"
        ),
        photoURLLarge: URL(
          string: "https://www.nyonyacooking.com/recipes/apam-balik~SJ5WuvsDf9WQ"
        ),
        sourceURL: URL(
          string: "https://www.nyonyacooking.com/recipes/apam-balik~SJ5WuvsDf9WQ"
        ),
        youtubeURL: URL(
          string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
      )
    )
  }
}
