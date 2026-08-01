import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct DatacenterWatchAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
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

    init(snapshot: DatacenterSurfaceSnapshot) {
      healthCode = snapshot.healthCode
      healthLabel = snapshot.healthLabel
      issueCount = snapshot.issueCount
      onlineNodeCount = snapshot.onlineNodeCount
      nodeCount = snapshot.nodeCount
      runningGuestCount = snapshot.runningGuestCount
      guestCount = snapshot.guestCount
      runningTaskCount = snapshot.runningTaskCount
      failedTaskCount = snapshot.failedTaskCount
      updatedAt = snapshot.updatedAt
    }
  }

  let startedAt: Date
  let endsAt: Date
}
