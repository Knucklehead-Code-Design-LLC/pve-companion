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
          "cpuFraction": 1.4,
          "memoryFraction": 0.72,
          "rootDiskFraction": -0.2,
        ]
      )
    )

    XCTAssertEqual(snapshot.healthCode, "warning")
    XCTAssertEqual(snapshot.onlineNodeCount, 2)
    XCTAssertEqual(snapshot.guestCount, 14)
    XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, 1_785_616_200)
    XCTAssertEqual(snapshot.cpuFraction, 1)
    XCTAssertEqual(snapshot.memoryFraction, 0.72)
    XCTAssertNil(snapshot.rootDiskFraction)
  }

  func testDatacenterSurfaceSnapshotRejectsImpossibleCounts() {
    let snapshot = DatacenterSurfaceSnapshot(
      dictionary: [
        "healthCode": "healthy",
        "healthLabel": "Healthy",
        "issueCount": 0,
        "onlineNodeCount": 3,
        "nodeCount": 2,
        "runningGuestCount": 1,
        "guestCount": 1,
        "runningTaskCount": 0,
        "failedTaskCount": 0,
        "updatedAt": 1_785_616_200.0,
      ]
    )

    XCTAssertNil(snapshot)
  }

  func testLegacyStoredSnapshotDecodesWithoutPressureValues() throws {
    let data = try XCTUnwrap(
      """
      {
        "healthCode": "healthy",
        "healthLabel": "Healthy",
        "issueCount": 0,
        "onlineNodeCount": 2,
        "nodeCount": 2,
        "runningGuestCount": 4,
        "guestCount": 5,
        "runningTaskCount": 0,
        "failedTaskCount": 0,
        "updatedAt": 0
      }
      """.data(using: .utf8)
    )

    let snapshot = try JSONDecoder().decode(
      DatacenterSurfaceSnapshot.self,
      from: data
    )

    XCTAssertNil(snapshot.cpuFraction)
    XCTAssertNil(snapshot.memoryFraction)
    XCTAssertNil(snapshot.rootDiskFraction)
  }

  func testWidgetTimelineTransitionsOnceWhenSnapshotBecomesStale() throws {
    let updatedAt = Date(timeIntervalSince1970: 1_785_616_200)
    let snapshot = DatacenterSurfaceSnapshot(
      healthCode: "healthy",
      healthLabel: "Healthy",
      issueCount: 0,
      onlineNodeCount: 2,
      nodeCount: 2,
      runningGuestCount: 4,
      guestCount: 5,
      runningTaskCount: 0,
      failedTaskCount: 0,
      updatedAt: updatedAt
    )
    let freshNow = updatedAt.addingTimeInterval(30 * 60)

    XCTAssertEqual(
      snapshot.widgetTimelineDates(now: freshNow),
      [freshNow, updatedAt.addingTimeInterval(60 * 60)]
    )

    let staleNow = updatedAt.addingTimeInterval(2 * 60 * 60)
    XCTAssertEqual(snapshot.widgetTimelineDates(now: staleNow), [staleNow])
  }

  func testWidgetDeepLinksAddressEachWorkspaceDestination() {
    XCTAssertEqual(
      DatacenterSurfaceSnapshot.deepLink(for: .overview).absoluteString,
      "pvecompanion://datacenter"
    )
    XCTAssertEqual(
      DatacenterSurfaceSnapshot.deepLink(for: .guests).absoluteString,
      "pvecompanion://guests"
    )
    XCTAssertEqual(
      DatacenterSurfaceSnapshot.deepLink(for: .nodes).absoluteString,
      "pvecompanion://nodes"
    )
    XCTAssertEqual(
      DatacenterSurfaceSnapshot.deepLink(for: .tasks).absoluteString,
      "pvecompanion://tasks"
    )
  }
}
