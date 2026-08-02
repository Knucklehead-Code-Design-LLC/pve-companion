import SwiftUI
import UIKit
import WidgetKit

@main
struct PVECompanionWidgetBundle: WidgetBundle {
  var body: some Widget {
    DatacenterStatusWidget()
    DatacenterWatchLiveActivity()
  }
}

func statusSymbolName(_ healthCode: String) -> String {
  switch healthCode {
  case "healthy": "checkmark.circle.fill"
  case "warning": "exclamationmark.triangle.fill"
  case "critical": "xmark.octagon.fill"
  default: "questionmark.diamond.fill"
  }
}

func statusColor(_ healthCode: String) -> Color {
  switch healthCode {
  case "healthy": .green
  case "warning": .orange
  case "critical": .red
  default: .secondary
  }
}

extension Color {
  static let pveAccent = Color(uiColor: .systemBlue)
}
