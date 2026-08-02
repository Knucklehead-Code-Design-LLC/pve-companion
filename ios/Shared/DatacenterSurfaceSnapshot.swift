import Foundation

enum DatacenterSurfaceDestination: String {
  case overview = "datacenter"
  case guests
  case nodes
  case storage
  case tasks
}

struct DatacenterSurfaceSnapshot: Codable, Equatable {
  static let appGroupIdentifier = "group.com.knuckleheadcodedesign.pvecompanion"
  static let storageKey = "datacenter-surface-snapshot-v1"
  static let widgetKind = "DatacenterStatusWidget"
  static let staleInterval: TimeInterval = 60 * 60

  static let deepLink = deepLink(for: .overview)

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
  let cpuFraction: Double?
  let memoryFraction: Double?
  let rootDiskFraction: Double?

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
    cpuFraction = Self.fraction(dictionary["cpuFraction"])
    memoryFraction = Self.fraction(dictionary["memoryFraction"])
    rootDiskFraction = Self.fraction(dictionary["rootDiskFraction"])

    guard isValid else {
      return nil
    }
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
    updatedAt: Date,
    cpuFraction: Double? = nil,
    memoryFraction: Double? = nil,
    rootDiskFraction: Double? = nil
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
    self.cpuFraction = cpuFraction
    self.memoryFraction = memoryFraction
    self.rootDiskFraction = rootDiskFraction
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
    updatedAt: Date(),
    cpuFraction: 0.42,
    memoryFraction: 0.47,
    rootDiskFraction: 0.40
  )

  var staleDate: Date {
    updatedAt.addingTimeInterval(Self.staleInterval)
  }

  func isStale(at date: Date) -> Bool {
    date >= staleDate
  }

  func widgetTimelineDates(now: Date) -> [Date] {
    isStale(at: now) ? [now] : [now, staleDate]
  }

  static func deepLink(for destination: DatacenterSurfaceDestination) -> URL {
    URL(string: "pvecompanion://\(destination.rawValue)")!
  }

  static func load() -> DatacenterSurfaceSnapshot? {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = defaults.data(forKey: storageKey)
    else {
      return nil
    }
    guard
      let snapshot = try? JSONDecoder().decode(
        DatacenterSurfaceSnapshot.self,
        from: data
      ),
      snapshot.isValid
    else {
      return nil
    }
    return snapshot
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

  private static func fraction(_ value: Any?) -> Double? {
    guard let value = double(value), value.isFinite, value >= 0 else {
      return nil
    }
    return min(value, 1)
  }

  private var isValid: Bool {
    ["healthy", "warning", "critical"].contains(healthCode)
      && issueCount >= 0
      && onlineNodeCount >= 0
      && nodeCount >= onlineNodeCount
      && runningGuestCount >= 0
      && guestCount >= runningGuestCount
      && runningTaskCount >= 0
      && failedTaskCount >= 0
  }
}

enum DatacenterSurfaceError: Error {
  case appGroupUnavailable
  case invalidArguments
}
