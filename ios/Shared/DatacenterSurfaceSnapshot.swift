import Foundation

struct DatacenterSurfaceSnapshot: Codable, Equatable {
  static let appGroupIdentifier = "group.com.knuckleheadcodedesign.pvecompanion"
  static let storageKey = "datacenter-surface-snapshot-v1"
  static let deepLink = URL(string: "pvecompanion://datacenter")!

  let healthCode: String
  let healthLabel: String
  let issueCount: Int
  let onlineNodeCount: Int
  let nodeCount: Int
  let runningGuestCount: Int
  let guestCount: Int
  let runningTaskCount: Int
  let failedTaskCount: Int
  let updatedAt: Date

  init?(dictionary: [String: Any]) {
    guard
      let healthCode = dictionary["healthCode"] as? String,
      let healthLabel = dictionary["healthLabel"] as? String,
      let issueCount = Self.integer(dictionary["issueCount"]),
      let onlineNodeCount = Self.integer(dictionary["onlineNodeCount"]),
      let nodeCount = Self.integer(dictionary["nodeCount"]),
      let runningGuestCount = Self.integer(dictionary["runningGuestCount"]),
      let guestCount = Self.integer(dictionary["guestCount"]),
      let runningTaskCount = Self.integer(dictionary["runningTaskCount"]),
      let failedTaskCount = Self.integer(dictionary["failedTaskCount"]),
      let updatedAtSeconds = Self.double(dictionary["updatedAt"])
    else {
      return nil
    }
    self.healthCode = healthCode
    self.healthLabel = healthLabel
    self.issueCount = issueCount
    self.onlineNodeCount = onlineNodeCount
    self.nodeCount = nodeCount
    self.runningGuestCount = runningGuestCount
    self.guestCount = guestCount
    self.runningTaskCount = runningTaskCount
    self.failedTaskCount = failedTaskCount
    updatedAt = Date(timeIntervalSince1970: updatedAtSeconds)
  }

  init(
    healthCode: String,
    healthLabel: String,
    issueCount: Int,
    onlineNodeCount: Int,
    nodeCount: Int,
    runningGuestCount: Int,
    guestCount: Int,
    runningTaskCount: Int,
    failedTaskCount: Int,
    updatedAt: Date
  ) {
    self.healthCode = healthCode
    self.healthLabel = healthLabel
    self.issueCount = issueCount
    self.onlineNodeCount = onlineNodeCount
    self.nodeCount = nodeCount
    self.runningGuestCount = runningGuestCount
    self.guestCount = guestCount
    self.runningTaskCount = runningTaskCount
    self.failedTaskCount = failedTaskCount
    self.updatedAt = updatedAt
  }

  static let placeholder = DatacenterSurfaceSnapshot(
    healthCode: "healthy",
    healthLabel: "Healthy",
    issueCount: 0,
    onlineNodeCount: 3,
    nodeCount: 3,
    runningGuestCount: 12,
    guestCount: 14,
    runningTaskCount: 1,
    failedTaskCount: 0,
    updatedAt: Date()
  )

  static func load() -> DatacenterSurfaceSnapshot? {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = defaults.data(forKey: storageKey)
    else {
      return nil
    }
    return try? JSONDecoder().decode(DatacenterSurfaceSnapshot.self, from: data)
  }

  func save() throws {
    guard let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) else {
      throw DatacenterSurfaceError.appGroupUnavailable
    }
    defaults.set(try JSONEncoder().encode(self), forKey: Self.storageKey)
  }

  private static func integer(_ value: Any?) -> Int? {
    if let number = value as? NSNumber {
      return number.intValue
    }
    return value as? Int
  }

  private static func double(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return value as? Double
  }
}

enum DatacenterSurfaceError: Error {
  case appGroupUnavailable
  case invalidArguments
}
