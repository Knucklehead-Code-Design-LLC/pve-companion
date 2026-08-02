import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testDatacenterSurfaceSnapshotParsesFlutterArguments() throws {
    let snapshot = try XCTUnwrap(
      DatacenterSurfaceSnapshot(
        dictionary: [
          "healthCode": "warning",
          "healthLabel": "Attention",
          "issueCount": 2,
          "onlineNodeCount": 2,
          "nodeCount": 3,
          "runningGuestCount": 11,
          "guestCount": 14,
          "runningTaskCount": 1,
          "failedTaskCount": 1,
          "updatedAt": 1_785_616_200.0,
        ]
      )
    )

    XCTAssertEqual(snapshot.healthCode, "warning")
    XCTAssertEqual(snapshot.onlineNodeCount, 2)
    XCTAssertEqual(snapshot.guestCount, 14)
    XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_785_616_200)
  }
}
