// Copyright © 2025 Samuel K. All rights reserved.

import Testing
import XCTest

@testable import Sous

// MARK: - Test Cacheable

private struct TestCacheItem: Cacheable, Codable, Equatable {
  let id: String
  let value: String
  var timestamp: Date = Date()

  init(id: String, value: String, timestamp: Date = Date()) {
    self.id = id
    self.value = value
    self.timestamp = timestamp
  }
}

private struct AnotherTestCacheItem: Cacheable, Codable, Equatable {
  let name: String
  var timestamp: Date = Date()
}

// MARK: - CacheManager Tests

@Suite("CacheManagerTests", .serialized)
class CacheManagerTests {

  @Test
  func cacheSavesDataToFileSystem() throws {
    let cacheManager = CacheManager.shared
    let key = "testKey"
    let item = TestCacheItem(id: key, value: "testValue")

    cacheManager.saveData(item, for: key)
    let retrievedItem: TestCacheItem? = cacheManager.getData(
      for: key,
      as: TestCacheItem.self
    )

    #expect(
      retrievedItem == item,
      "Item should be retrieved correctly from the cache."
    )
  }

  @Test
  func cacheIsNilWhenRetrievesExpiredData() throws {
    let cacheManager = CacheManager.shared
    let key = "testKey"
    let item = TestCacheItem(id: key, value: "testValue")
    cacheManager.saveData(item, for: key)
    cacheManager.setTimeToLive(1)
    sleep(2)
    let retrievedItem: TestCacheItem? = cacheManager.getData(
      for: key,
      as: TestCacheItem.self
    )

    #expect(retrievedItem == nil, "Expired data should not be retrievable.")
  }

  @Test
  func cacheRetrievesNonExpiredData() throws {
    let cacheManager = CacheManager.shared
    let key = "testKey"
    let item = TestCacheItem(id: key, value: "testValue")
    cacheManager.saveData(item, for: key)
    cacheManager.setTimeToLive(5)
    sleep(1)
    let retrievedItem: TestCacheItem? = cacheManager.getData(
      for: key,
      as: TestCacheItem.self
    )

    #expect(
      retrievedItem == item,
      "Non-expired data should still be retrievable."
    )
  }

  @Test
  func cacheIsNilWhenInvalidateData() throws {
    let cacheManager = CacheManager.shared
    let key = "testKey"
    let item = TestCacheItem(id: key, value: "testValue")
    cacheManager.saveData(item, for: key)
    cacheManager.invalidateCache(for: TestCacheItem.self)

    let retrievedItem: TestCacheItem? = cacheManager.getData(
      for: key,
      as: TestCacheItem.self
    )

    #expect(
      retrievedItem == nil,
      "Cache should be invalidated and not retrievable."
    )
  }

  @Test
  func cacheIsNilWhenInvalidateAllData() throws {
    let cacheManager = CacheManager.shared
    let key = "testKey"
    let item = TestCacheItem(id: key, value: "testValue")
    cacheManager.saveData(item, for: key)

    let key2 = "anotherTestKey"
    let item2 = AnotherTestCacheItem(name: "testName")
    cacheManager.saveData(item2, for: key2)

    cacheManager.invalidateAllCaches()
    let retrievedItem: TestCacheItem? = cacheManager.getData(
      for: key,
      as: TestCacheItem.self
    )

    #expect(
      retrievedItem == nil,
      "Cache should be invalidated and not retrievable."
    )

    let retrievedItem2: AnotherTestCacheItem? = cacheManager.getData(
      for: key2,
      as: AnotherTestCacheItem.self
    )

    #expect(
      retrievedItem2 == nil,
      "Cache should be invalidated and not retrievable."
    )
  }
}
