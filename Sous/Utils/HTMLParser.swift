// Copyright © 2025 Samuel K. All rights reserved.

import Foundation

protocol HTMLParsing {
  func parseMetaDescription(fromHTML html: String) throws -> String
}

enum HTMLParserError: Error, LocalizedError {
  case parsingFailed(Error)
  case descriptionMetaTagNotFound

  var errorDescription: String? {
    switch self {
    case .parsingFailed(let error):
      return "Failed to parse HTML: \(error.localizedDescription)"
    case .descriptionMetaTagNotFound:
      return "Could not find description meta tag in HTML."
    }
  }
}

struct DefaultHTMLParser: HTMLParsing {
  func parseMetaDescription(fromHTML html: String) throws -> String {
    let pattern = #"<meta\s+name=["']description["']\s+content=["'](.*?)["']"#
    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    let range = NSRange(html.startIndex..<html.endIndex, in: html)

    if let match = regex.firstMatch(in: html, options: [], range: range),
      let contentRange = Range(match.range(at: 1), in: html)
    {
      let content = html[contentRange].trimmingCharacters(in: .whitespacesAndNewlines)
      if !content.isEmpty {
        return content
      }
    }

    throw HTMLParserError.descriptionMetaTagNotFound
  }
}
