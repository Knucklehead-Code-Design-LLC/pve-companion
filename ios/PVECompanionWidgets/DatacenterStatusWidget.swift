import SwiftUI
import WidgetKit

struct DatacenterStatusEntry: TimelineEntry {
  let date: Date
  let snapshot: DatacenterSurfaceSnapshot?
  let isPlaceholder: Bool

  var isStale: Bool {
    snapshot?.isStale(at: date) ?? false
  }

  var relevance: TimelineEntryRelevance? {
    guard let snapshot else {
      return nil
    }
    let score: Float =
      switch snapshot.healthCode {
      case "critical": 100
      case "warning": 60
      default: snapshot.runningTaskCount > 0 ? 20 : 10
      }
    return TimelineEntryRelevance(score: score)
  }
}

struct DatacenterStatusProvider: TimelineProvider {
  func placeholder(in context: Context) -> DatacenterStatusEntry {
    DatacenterStatusEntry(
      date: .now,
      snapshot: .placeholder,
      isPlaceholder: true
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (DatacenterStatusEntry) -> Void
  ) {
    completion(
      DatacenterStatusEntry(
        date: .now,
        snapshot: context.isPreview ? .placeholder : .load(),
        isPlaceholder: false
      )
    )
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<DatacenterStatusEntry>) -> Void
  ) {
    let now = Date()
    guard let snapshot = DatacenterSurfaceSnapshot.load() else {
      completion(
        Timeline(
          entries: [
            DatacenterStatusEntry(
              date: now,
              snapshot: nil,
              isPlaceholder: false
            )
          ],
          policy: .never
        )
      )
      return
    }

    let entries = snapshot.widgetTimelineDates(now: now).map { date in
      DatacenterStatusEntry(
        date: date,
        snapshot: snapshot,
        isPlaceholder: false
      )
    }
    completion(Timeline(entries: entries, policy: .never))
  }
}

struct DatacenterStatusWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: DatacenterSurfaceSnapshot.widgetKind,
      provider: DatacenterStatusProvider()
    ) { entry in
      DatacenterStatusWidgetView(entry: entry)
        .widgetURL(DatacenterSurfaceSnapshot.deepLink)
        .pveWidgetBackground()
    }
    .configurationDisplayName("Datacenter Status")
    .description(
      "Monitor health, nodes, guests, tasks, and resource pressure from your Home Screen."
    )
    .supportedFamilies(supportedFamilies)
  }

  private var supportedFamilies: [WidgetFamily] {
    #if os(iOS)
      return [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .accessoryInline,
        .accessoryCircular,
        .accessoryRectangular,
      ]
    #else
      return [.systemSmall, .systemMedium, .systemLarge]
    #endif
  }
}

struct DatacenterStatusWidgetView: View {
  @Environment(\.widgetFamily) private var environmentFamily

  let entry: DatacenterStatusEntry
  let familyOverride: WidgetFamily?

  init(
    entry: DatacenterStatusEntry,
    familyOverride: WidgetFamily? = nil
  ) {
    self.entry = entry
    self.familyOverride = familyOverride
  }

  private var family: WidgetFamily {
    familyOverride ?? environmentFamily
  }

  @ViewBuilder
  var body: some View {
    if let snapshot = entry.snapshot {
      populatedContent(snapshot)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    } else {
      EmptyDatacenterWidgetView(family: family)
    }
  }

  @ViewBuilder
  private func populatedContent(_ snapshot: DatacenterSurfaceSnapshot) -> some View {
    switch family {
    #if os(iOS)
      case .accessoryInline:
        AccessoryInlineView(snapshot: snapshot, isStale: entry.isStale)
      case .accessoryCircular:
        AccessoryCircularView(snapshot: snapshot)
      case .accessoryRectangular:
        AccessoryRectangularView(snapshot: snapshot, isStale: entry.isStale)
    #endif
    case .systemMedium:
      MediumStatusView(snapshot: snapshot, isStale: entry.isStale)
    case .systemLarge:
      LargeStatusView(snapshot: snapshot, isStale: entry.isStale)
    default:
      SmallStatusView(snapshot: snapshot, isStale: entry.isStale)
    }
  }
}

private struct SmallStatusView: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      DatacenterWidgetHeader(isStale: isStale)
      VStack(alignment: .leading, spacing: 3) {
        Label(snapshot.healthLabel, systemImage: statusSymbolName(snapshot.healthCode))
          .font(.title3.weight(.bold))
          .foregroundStyle(statusColor(snapshot.healthCode))
          .widgetAccentable()
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Text(issueSummary(snapshot))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Datacenter health")
      .accessibilityValue(
        "\(isStale ? "Stale, last reported " : "")\(snapshot.healthLabel), \(issueSummary(snapshot))"
      )
      Spacer(minLength: 0)
      HStack(spacing: 10) {
        CompactWidgetMetric(
          symbol: "server.rack",
          value: "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount)",
          label: "Nodes"
        )
        CompactWidgetMetric(
          symbol: "rectangle.3.group.fill",
          value: "\(snapshot.runningGuestCount)/\(snapshot.guestCount)",
          label: "Guests"
        )
      }
      UpdatedLabel(snapshot: snapshot, isStale: isStale)
    }
  }
}

private struct MediumStatusView: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      DatacenterWidgetHeader(isStale: isStale)
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 5) {
          Label(
            snapshot.healthLabel,
            systemImage: statusSymbolName(snapshot.healthCode)
          )
          .font(.title3.weight(.bold))
          .foregroundStyle(statusColor(snapshot.healthCode))
          .widgetAccentable()
          Text(issueSummary(snapshot))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          Spacer(minLength: 0)
          UpdatedLabel(snapshot: snapshot, isStale: isStale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)

        Divider()

        HStack(spacing: 14) {
          DestinationMetric(
            destination: .nodes,
            symbol: "server.rack",
            value: "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount)",
            label: "Nodes"
          )
          DestinationMetric(
            destination: .guests,
            symbol: "rectangle.3.group.fill",
            value: "\(snapshot.runningGuestCount)/\(snapshot.guestCount)",
            label: "Guests"
          )
          DestinationMetric(
            destination: .tasks,
            symbol: "arrow.triangle.2.circlepath",
            value: "\(snapshot.runningTaskCount)",
            label: "Tasks"
          )
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

private struct LargeStatusView: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 13) {
      DatacenterWidgetHeader(isStale: isStale)
      Link(destination: DatacenterSurfaceSnapshot.deepLink(for: .overview)) {
        HStack(spacing: 12) {
          Image(systemName: statusSymbolName(snapshot.healthCode))
            .font(.title2.weight(.semibold))
            .foregroundStyle(statusColor(snapshot.healthCode))
            .widgetAccentable()
          VStack(alignment: .leading, spacing: 2) {
            Text(snapshot.healthLabel)
              .font(.headline)
            Text(issueSummary(snapshot))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(statusColor(snapshot.healthCode).opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Datacenter health")
      .accessibilityValue(
        "\(isStale ? "Stale, last reported " : "")\(snapshot.healthLabel), \(issueSummary(snapshot))"
      )

      HStack(spacing: 12) {
        DestinationMetricCard(
          destination: .nodes,
          symbol: "server.rack",
          value: "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount)",
          label: "Nodes"
        )
        DestinationMetricCard(
          destination: .guests,
          symbol: "rectangle.3.group.fill",
          value: "\(snapshot.runningGuestCount)/\(snapshot.guestCount)",
          label: "Guests"
        )
        DestinationMetricCard(
          destination: .tasks,
          symbol: "arrow.triangle.2.circlepath",
          value: "\(snapshot.runningTaskCount)",
          label: "Tasks"
        )
      }

      VStack(alignment: .leading, spacing: 9) {
        Text("RESOURCE PRESSURE")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
          .tracking(0.4)
        PressureMetric(
          label: "Peak CPU",
          symbol: "cpu",
          fraction: snapshot.cpuFraction
        )
        PressureMetric(
          label: "Memory",
          symbol: "memorychip",
          fraction: snapshot.memoryFraction
        )
        PressureMetric(
          label: "Root disk",
          symbol: "internaldrive.fill",
          fraction: snapshot.rootDiskFraction
        )
      }
      Spacer(minLength: 0)
      HStack {
        UpdatedLabel(snapshot: snapshot, isStale: isStale)
        Spacer()
        if snapshot.failedTaskCount > 0 {
          Label(
            "\(snapshot.failedTaskCount) failed",
            systemImage: "exclamationmark.circle.fill"
          )
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.red)
          .widgetAccentable()
          .accessibilityLabel(
            "\(snapshot.failedTaskCount) failed \(snapshot.failedTaskCount == 1 ? "task" : "tasks")"
          )
        }
      }
    }
  }
}

private struct DatacenterWidgetHeader: View {
  let isStale: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "square.grid.2x2.fill")
        .foregroundStyle(Color.pveAccent)
        .widgetAccentable()
      Text("PVE COMPANION")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .tracking(0.3)
        .lineLimit(1)
      Spacer(minLength: 4)
      if isStale {
        Text("STALE")
          .font(.caption2.weight(.bold))
          .foregroundStyle(.orange)
          .widgetAccentable()
          .accessibilityLabel("Data is stale")
      }
    }
  }
}

private struct UpdatedLabel: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    HStack(spacing: 3) {
      Image(systemName: isStale ? "clock.fill" : "clock")
      Text("Updated")
      Text(
        snapshot.updatedAt,
        format: .relative(presentation: .numeric, unitsStyle: .abbreviated)
      )
    }
    .font(.caption2)
    .foregroundStyle(isStale ? .orange : .secondary)
    .widgetAccentable(isStale)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
  }
}

private struct CompactWidgetMetric: View {
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.pveAccent)
          .widgetAccentable()
        Text(value)
          .font(.subheadline.monospacedDigit().weight(.semibold))
      }
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(value)
  }
}

private struct DestinationMetric: View {
  let destination: DatacenterSurfaceDestination
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    Link(destination: DatacenterSurfaceSnapshot.deepLink(for: destination)) {
      VStack(alignment: .leading, spacing: 4) {
        Image(systemName: symbol)
          .font(.system(size: 16, weight: .medium))
          .foregroundStyle(Color.pveAccent)
          .widgetAccentable()
        Text(value)
          .font(.title3.monospacedDigit().weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
        Text(label)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityValue(value)
    .accessibilityHint("Opens \(destination.rawValue) in PVE Companion")
  }
}

private struct DestinationMetricCard: View {
  let destination: DatacenterSurfaceDestination
  let symbol: String
  let value: String
  let label: String

  var body: some View {
    Link(destination: DatacenterSurfaceSnapshot.deepLink(for: destination)) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.pveAccent)
          .widgetAccentable()
        VStack(alignment: .leading, spacing: 1) {
          Text(value)
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(10)
      .background(Color.secondary.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
    .accessibilityValue(value)
  }
}

private struct PressureMetric: View {
  let label: String
  let symbol: String
  let fraction: Double?

  var body: some View {
    Link(destination: DatacenterSurfaceSnapshot.deepLink(for: .nodes)) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.pveAccent)
          .frame(width: 16)
          .widgetAccentable()
        Text(label)
          .font(.caption)
          .frame(width: 58, alignment: .leading)
        if let fraction {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.secondary.opacity(0.15))
              Capsule()
                .fill(pressureColor(fraction))
                .frame(width: geometry.size.width * fraction)
                .widgetAccentable()
            }
          }
          .frame(height: 6)
          Text(fraction, format: .percent.precision(.fractionLength(0)))
            .font(.caption.monospacedDigit().weight(.semibold))
            .frame(width: 34, alignment: .trailing)
        } else {
          Text("Not reported")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue(
      fraction.map { $0.formatted(.percent.precision(.fractionLength(0))) }
        ?? "Not reported"
    )
    .accessibilityHint("Opens nodes in PVE Companion")
  }
}

private struct EmptyDatacenterWidgetView: View {
  let family: WidgetFamily

  @ViewBuilder
  var body: some View {
    switch family {
    #if os(iOS)
      case .accessoryInline:
        Label("Open PVE Companion to refresh", systemImage: "server.rack")
      case .accessoryCircular:
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "server.rack")
        }
        .accessibilityLabel("No datacenter status. Open PVE Companion to refresh.")
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Label("No datacenter status", systemImage: "server.rack")
            .font(.headline)
          Text("Open PVE Companion to refresh")
            .font(.caption)
        }
    #endif
    default:
      VStack(alignment: .leading, spacing: 8) {
        Image(systemName: "server.rack")
          .font(.title2.weight(.semibold))
          .foregroundStyle(Color.pveAccent)
          .widgetAccentable()
        Text("Open PVE Companion")
          .font(.headline)
        Text("Connect to a server and refresh to populate this widget.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(family == .systemSmall ? 3 : 2)
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
    }
  }
}

private struct AccessoryInlineView: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    Label(
      "\(isStale ? "Stale · " : "")\(snapshot.healthLabel) · \(snapshot.onlineNodeCount)/\(snapshot.nodeCount) nodes",
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
        .font(.headline.monospacedDigit())
    }
    .gaugeStyle(.accessoryCircularCapacity)
    .accessibilityLabel("Nodes online")
    .accessibilityValue("\(snapshot.onlineNodeCount) of \(snapshot.nodeCount)")
  }
}

private struct AccessoryRectangularView: View {
  let snapshot: DatacenterSurfaceSnapshot
  let isStale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Label(snapshot.healthLabel, systemImage: statusSymbolName(snapshot.healthCode))
        .font(.headline)
      Text(
        "\(snapshot.onlineNodeCount)/\(snapshot.nodeCount) nodes · "
          + "\(snapshot.runningGuestCount)/\(snapshot.guestCount) guests"
      )
      .font(.caption)
      if isStale {
        Text("Stale data")
          .font(.caption2.weight(.semibold))
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private func issueSummary(_ snapshot: DatacenterSurfaceSnapshot) -> String {
  if snapshot.issueCount == 0 {
    return "No reported issues"
  }
  return "\(snapshot.issueCount) reported \(snapshot.issueCount == 1 ? "issue" : "issues")"
}

private func pressureColor(_ fraction: Double) -> Color {
  if fraction >= 0.90 {
    return .red
  }
  if fraction >= 0.75 {
    return .orange
  }
  return Color.pveAccent
}

extension View {
  @ViewBuilder
  fileprivate func pveWidgetBackground() -> some View {
    #if os(iOS)
      if #available(iOSApplicationExtension 17.0, *) {
        containerBackground(.background, for: .widget)
      } else {
        background(Color(uiColor: .secondarySystemBackground))
      }
    #else
      containerBackground(.background, for: .widget)
    #endif
  }
}

#if DEBUG
  private let criticalPreviewSnapshot = DatacenterSurfaceSnapshot(
    healthCode: "critical",
    healthLabel: "Critical",
    issueCount: 3,
    onlineNodeCount: 2,
    nodeCount: 3,
    runningGuestCount: 11,
    guestCount: 14,
    runningTaskCount: 2,
    failedTaskCount: 1,
    updatedAt: Date().addingTimeInterval(-7_200),
    cpuFraction: 0.92,
    memoryFraction: 0.78,
    rootDiskFraction: 0.63
  )

  #Preview("Small · Healthy", as: .systemSmall) {
    DatacenterStatusWidget()
  } timeline: {
    DatacenterStatusEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
  }

  #Preview("Medium · Stale", as: .systemMedium) {
    DatacenterStatusWidget()
  } timeline: {
    DatacenterStatusEntry(
      date: .now,
      snapshot: criticalPreviewSnapshot,
      isPlaceholder: false
    )
  }

  #Preview("Large · Operations", as: .systemLarge) {
    DatacenterStatusWidget()
  } timeline: {
    DatacenterStatusEntry(date: .now, snapshot: .placeholder, isPlaceholder: false)
  }

  #Preview("Small · No data", as: .systemSmall) {
    DatacenterStatusWidget()
  } timeline: {
    DatacenterStatusEntry(date: .now, snapshot: nil, isPlaceholder: false)
  }
#endif
