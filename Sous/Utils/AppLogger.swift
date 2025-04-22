// Copyright © 2025 Samuel K. All rights reserved.

import Foundation
import OSLog

enum AppLogger {
  private static let subsystem = Bundle.main.bundleIdentifier ?? "com.fetchmobile.default"

  /// Logger for network-related operations. Use for requests, responses, errors.
  static let network = Logger(subsystem: subsystem, category: "Network")

  /// Logger for caching operations. Use for hits, misses, saves, expirations, errors.
  static let cache = Logger(subsystem: subsystem, category: "Cache")

  /// Logger for ViewModel operations and lifecycle events. Use for state changes, data loading.
  static let viewModel = Logger(subsystem: subsystem, category: "ViewModel")

  /// Logger for general application events or unclassified messages.
  static let general = Logger(subsystem: subsystem, category: "General")
}
