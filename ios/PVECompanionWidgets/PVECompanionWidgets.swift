import SwiftUI
import WidgetKit

@main
struct PVECompanionWidgetBundle: WidgetBundle {
  var body: some Widget {
    DatacenterStatusWidget()
    DatacenterWatchLiveActivity()
  }
}

private struct DatacenterStatusEntry: TimelineEntry {
  let date: Date
  let snapshot: DatacenterSurfaceSnapshot?

  var displaySnapshot: DatacenterSurfaceSnapshot {
    snapshot ?? .placeholder
  }
}

private struct DatacenterStatusProvider: TimelineProvider {
  func placeholder(in context: Context) -> DatacenterStatusEntry {
    DatacenterStatusEntry(date: .now, snapshot: nil)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (DatacenterStatusEntry) -> Void
  ) {
    completion(
      DatacenterStatusEntry(
        date: .now,
        snapshot: context.isPreview ? .placeholder : .load()
      )
    )
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<DatacenterStatusEntry>) -> Void
  ) {
    let entry = DatacenterStatusEntry(
      date: .now,
      snapshot: DatacenterSurfaceSnapshot.load()
    )
    completion(
      Timeline(
        entries: [entry],
        policy: .after(Date().addingTimeInterval(15 * 60))
      )
    )
  }
}

private struct DatacenterStatusWidget: Widget {
  let kind = "DatacenterStatusWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DatacenterStatusProvider()) { entry in
      DatacenterStatusWidgetView(entry: entry)
        .widgetURL(DatacenterSurfaceSnapshot.deepLink)
        .pveWidgetBackground()
    }
    .configurationDisplayName("Datacenter Status")
    .description("See the last reported health, nodes, guests, and tasks at a glance.")
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryInline,
      .accessoryCircular,
      .accessoryRectangular,
    ])
  }
}

private struct DatacenterStatusWidgetView: View {
  @Environment(\.widgetFamily) private var family

  let entry: DatacenterStatusEntry

  var body: some View {
    Group {
      switch family {
      case .accessoryInline:
        AccessoryInlineView(snapshot: entry.displaySnapshot)
      case .accessoryCircular:
        AccessoryCircularView(snapshot: entry.displaySnapshot)
      case .accessoryRectangular:
        AccessoryRectangularView(snapshot: entry.displaySnapshot)
      case .systemMedium:
        MediumStatusView(snapshot: entry.displaySnapshot)
      default:
        SmallStatusView(snapshot: entry.displaySnapshot)
      }
    }
    .redacted(reason: entry.snapshot == nil ? .placeholder : [])
  }
}

private struct SmallStatusView: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 7) {
        StatusSymbol(snapshot: snapshot)
        Text(snapshot.healthLabel)
          .font(.headline)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      MetricLine(
        symbol: "server.rack",
        value: "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount)",
        label: "nodes"
      )
      MetricLine(
        symbol: "rectangle.3.group.fill",
        value: "\(snapshot.runningGuestCount)/\(snapshot.guestCount)",
        label: "running"
      )
      Text(snapshot.updatedAt, style: .relative)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

private struct MediumStatusView: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        HStack(spacing: 8) {
          StatusSymbol(snapshot: snapshot)
          Text(snapshot.healthLabel)
            .font(.headline)
        }
        Spacer()
        Text(snapshot.updatedAt, style: .relative)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 18) {
        WidgetMetric(
          symbol: "server.rack",
          value: "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount)",
          label: "Nodes online"
        )
        WidgetMetric(
          symbol: "rectangle.3.group.fill",
          value: "\(snapshot.runningGuestCount)/\(snapshot.guestCount)",
          label: "Guests running"
        )
        WidgetMetric(
          symbol: "arrow.triangle.2.circlepath",
          value: "\(snapshot.runningTaskCount)",
          label: "Active tasks"
        )
      }
    }
  }
}

private struct AccessoryInlineView: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    Label(
      "\(snapshot.healthLabel) · \(snapshot.onlineNodeCount)/\(snapshot.nodeCount) nodes",
      systemImage: statusSymbolName(snapshot.healthCode)
    )
  }
}

private struct AccessoryCircularView: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    Gauge(
      value: Double(snapshot.onlineNodeCount),
      in: 0...Double(max(snapshot.nodeCount, 1))
    ) {
      Image(systemName: "server.rack")
    } currentValueLabel: {
      Text("\(snapshot.onlineNodeCount)")
        .font(.headline)
    }
    .gaugeStyle(.accessoryCircularCapacity)
  }
}

private struct AccessoryRectangularView: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(snapshot.healthLabel, systemImage: statusSymbolName(snapshot.healthCode))
        .font(.headline)
      Text(
        "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount) nodes · "
          + "\(snapshot.runningGuestCount)/\(snapshot.guestCount) guests"
      )
      .font(.caption)
    }
  }
}

private struct StatusSymbol: View {
  let snapshot: DatacenterSurfaceSnapshot

  var body: some View {
    Image(systemName: statusSymbolName(snapshot.healthCode))
      .foregroundStyle(statusColor(snapshot.healthCode))
      .font(.system(size: 17, weight: .semibold))
  }
}

private struct MetricLine: View {
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .frame(width: 17)
        .foregroundStyle(.tint)
      Text(value)
        .fontWeight(.semibold)
      Text(label)
        .foregroundStyle(.secondary)
    }
    .font(.caption)
  }
}

private struct WidgetMetric: View {
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: symbol)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.tint)
      Text(value)
        .font(.title3.weight(.semibold))
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

private extension View {
  @ViewBuilder
  func pveWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(.background, for: .widget)
    } else {
      background(Color(uiColor: .secondarySystemBackground))
    }
  }
}
