// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

enum RecipeServiceError: Error, LocalizedError {
  case networkError(URLError)
  case decodingError(Error)
  case invalidResponse(Int?)
  case missingData
  case htmlParsingError(Error)
  case invalidSourceURL
  case descriptionNotFound

  var errorDescription: String? {
    switch self {
    case .networkError(let urlError):
      return "Network error: \(urlError.localizedDescription)"
    case .decodingError(let error):
      if let decodingError = error as? DecodingError {
        return
          "Failed to decode data: \(decodingError.localizedDescription) - \(decodingError.detailDescription)"
      }
      return "Failed to decode data: \(error.localizedDescription)"
    case .invalidResponse(let statusCode):
      let statusString = statusCode != nil ? "\(statusCode!)" : "N/A"
      return "Invalid server response (Status: \(statusString))"
    case .missingData:
      return "No data received from server."
    case .htmlParsingError(let error):
      if let parserError = error as? HTMLParserError {
        return "HTML Parsing Error: \(parserError.localizedDescription)"
      }
      return "Failed to parse HTML: \(error.localizedDescription)"
    case .invalidSourceURL:
      return "Recipe source URL is invalid or missing."
    case .descriptionNotFound:
      return "Could not find recipe description."
    }
  }
}

extension DecodingError {
  var detailDescription: String {
    switch self {
    case .typeMismatch(let type, let context):
      return
        "Type mismatch for type \(type) at \(context.codingPath.debugDescription): \(context.debugDescription)"
    case .valueNotFound(let type, let context):
      return
        "Value not found for type \(type) at \(context.codingPath.debugDescription): \(context.debugDescription)"
    case .keyNotFound(let key, let context):
      return
        "Key not found: \(key.stringValue) at \(context.codingPath.debugDescription): \(context.debugDescription)"
    case .dataCorrupted(let context):
      return "Data corrupted at \(context.codingPath.debugDescription): \(context.debugDescription)"
    @unknown default:
      return "An unknown decoding error occurred."
    }
  }
}
