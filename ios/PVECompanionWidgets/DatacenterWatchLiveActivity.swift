import ActivityKit
import SwiftUI
import WidgetKit

struct DatacenterWatchLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DatacenterWatchAttributes.self) { context in
      DatacenterWatchLockScreenView(context: context)
        .activityBackgroundTint(Color(uiColor: .secondarySystemBackground))
        .activitySystemActionForegroundColor(Color.pveAccent)
        .widgetURL(DatacenterSurfaceSnapshot.deepLink)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(
            context.state.healthLabel,
            systemImage: statusSymbolName(context.state.healthCode)
          )
          .font(.headline)
          .foregroundStyle(statusColor(context.state.healthCode))
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(timerInterval: Date()...context.attributes.endsAt, countsDown: true)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        DynamicIslandExpandedRegion(.bottom) {
          LiveActivityMetrics(state: context.state)
            .padding(.top, 2)
        }
      } compactLeading: {
        Image(systemName: statusSymbolName(context.state.healthCode))
          .foregroundStyle(statusColor(context.state.healthCode))
      } compactTrailing: {
        Text("\(context.state.onlineNodeCount)/\(context.state.nodeCount)")
          .font(.caption2.monospacedDigit().weight(.semibold))
      } minimal: {
        Image(systemName: statusSymbolName(context.state.healthCode))
          .foregroundStyle(statusColor(context.state.healthCode))
      }
      .widgetURL(DatacenterSurfaceSnapshot.deepLink)
      .keylineTint(statusColor(context.state.healthCode))
    }
  }
}

private struct DatacenterWatchLockScreenView: View {
  let context: ActivityViewContext<DatacenterWatchAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(
          context.state.healthLabel,
          systemImage: statusSymbolName(context.state.healthCode)
        )
        .font(.headline)
        .foregroundStyle(statusColor(context.state.healthCode))
        Spacer()
        Text(timerInterval: Date()...context.attributes.endsAt, countsDown: true)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      LiveActivityMetrics(state: context.state)
      HStack(spacing: 2) {
        Text("Updated")
        Text(context.state.updatedAt, style: .relative)
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
    }
    .padding(16)
  }
}

private struct LiveActivityMetrics: View {
  let state: DatacenterWatchAttributes.ContentState

  var body: some View {
    HStack(spacing: 16) {
      LiveMetric(
        symbol: "server.rack",
        value: "\(state.onlineNodeCount)/\(state.nodeCount)",
        label: "Nodes"
      )
      LiveMetric(
        symbol: "rectangle.3.group.fill",
        value: "\(state.runningGuestCount)/\(state.guestCount)",
        label: "Guests"
      )
      LiveMetric(
        symbol: "arrow.triangle.2.circlepath",
        value: "\(state.runningTaskCount)",
        label: "Tasks"
      )
    }
  }
}

private struct LiveMetric: View {
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.pveAccent)
      VStack(alignment: .leading, spacing: 0) {
        Text(value)
          .font(.subheadline.monospacedDigit().weight(.semibold))
        Text(label)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
