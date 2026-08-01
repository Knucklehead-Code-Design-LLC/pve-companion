# Architecture

PVE Companion follows the responsibility model used by Kerecis Core and
RMBB—scaled down for one Flutter application rather than mechanically copying
their monorepo structure. Each feature owns the smallest coherent set of
domain, data, application, and presentation code.

## Feature boundaries

| Feature | Owns |
| --- | --- |
| `connection_profiles` | Server profile rules, secure credential boundary, profile persistence, sign-in state, and add/manage-server UI. |
| `cluster_overview` | Cluster/node/storage/task models, strict response decoding, snapshot refresh state, derived datacenter health, command-center overview, and node views. |
| `guests` | VM/LXC models, safe configuration projection, power command behavior, detail state, and guest UI. |
| `storage` and `tasks` | Read-only presentation of the cluster-overview data in the first milestone. |
| `system_surfaces` | Privacy-safe aggregate projection, WidgetKit snapshot publication, and Datacenter Watch lifecycle. |
| `core/api` | Transport-only Proxmox HTTP session, headers, ticket handling, response validation, and typed transport errors. |
| `core/security` | Keychain adapter and certificate fingerprint derivation. |
| `app/workspace` | Adaptive shell navigation, server selection, and workspace-level actions. |
| `core/presentation` | Apple-first colors, typography, inset groups, list rows, progress, status, section, and state primitives shared across features. |

Dependencies flow in one direction:

```text
Widget → focused controller → feature repository → core HTTP/keychain adapter
```

Widgets render state and forward intent. Controllers own validation, async
sequencing, duplicate-action guards, stale-response protection, and disposal
behavior. Repositories map a feature's API data to its domain types. The HTTP
service owns request encoding, authentication headers, TLS pinning, and strict
envelope validation; UI code never assembles requests.

`ChangeNotifier`/`Listenable` from Flutter SDK provide the small amount of
long-lived state required here. There is no provider/state-management package,
generic service locator, speculative shared `utils`, or code generation.

## Apple system surfaces

`system_surfaces` converts a loaded cluster snapshot into a deliberately small
aggregate model. The projection includes only health and counts; it excludes
server endpoints, host and guest names, users, credentials, tickets, and CSRF
values. `PveCompanionController` publishes that model after a successful
cluster refresh.

One Flutter method channel forwards the model to native iOS code. The native
host writes JSON to the private
`group.com.knuckleheadcodedesign.pvecompanion` App Group and asks WidgetKit to
reload its timeline. The SwiftUI extension owns Home Screen, Lock Screen, and
Live Activity rendering. No Flutter engine or third-party widget package runs
inside the extension.

Widgets display the latest app-provided snapshot and make its age visible.
They do not promise real-time status. Datacenter Watch is a user-started,
four-hour ActivityKit session for a defined maintenance or incident window;
it updates when the app refreshes and supports Lock Screen plus compact,
minimal, and expanded Dynamic Island presentations. A future remote-update
service would require an explicit APNs design and privacy review.

## Dashboard derivation

`cluster_overview/domain/datacenter_health.dart` owns the immutable health,
issue, workload, task-activity, per-node, and capacity value types.
`datacenter_health_evaluator.dart` owns the derivation policy that turns a
decoded snapshot into those types. This keeps rendering code free of policy
decisions and lets pure unit tests cover threshold boundaries without a widget
or network connection.

- Offline nodes and critical per-node CPU, memory, or root-disk pressure are
  critical. Failed reported tasks and warning pressure are warnings. A stopped
  guest is inventory, not an incident.
- Pressure thresholds are inclusive: 75% is warning and 90% is critical.
  Health evaluates each reporting node; cluster capacity remains explicit
  about its aggregation (CPU = highest reported node, byte metrics = complete
  known-node totals).
- Missing or incomplete values stay unreported. Configured storage is
  inventory because the current endpoint does not provide utilization.
- Presentation is split by dashboard responsibility (health, capacity and
  workload, nodes, and activity). `PveWorkspace` owns the drill-down routing;
  dashboard widgets receive callbacks rather than depending on app navigation.

Large presentation surfaces are split at responsibility boundaries rather
than by arbitrary size. Connection form orchestration, field rendering, and
certificate consent are separate owners; guest-detail lifecycle, content, and
power confirmation are separate owners; dashboard metric and storage cards
are also independent from the section layout.

The deterministic preview data belongs under `tool/support`, not `lib`, and
the preview targets are local-only. They give maintainers repeatable healthy,
critical, and App Store capture states without mixing demonstration data into
application code. The screenshot target reuses production workspace and
feature widgets and performs no network requests.

## Security boundaries

- `shared_preferences` persists only JSON profile metadata and selected-server
  state. It never receives a credential secret, authentication ticket, or CSRF
  token.
- `flutter_secure_storage` maps opted-in credentials to the Apple Keychain.
- Password authentication obtains a PVE ticket and CSRF token only in memory.
- For a certificate chain that platform trust rejects, the network adapter
  captures a SHA-256 DER fingerprint and rejects the connection. A connection
  succeeds only after the user explicitly pins that exact fingerprint for the
  same host and port.
- Guest configuration is allow-listed before rendering. No force-stop or
  destructive guest control is present in the first milestone.

## Adaptive Apple UI

The workspace uses five stable Cupertino tabs at compact iPhone widths and a
persistent sidebar at wider iPad and Mac widths. Both present the same
destinations in the same order, and an `IndexedStack` retains each page's
controller and navigation state as people move through the app.

The shared presentation layer follows Apple platform conventions with system
typography and dynamic colors, inset grouped surfaces, 44-point controls,
Cupertino sheets and alerts, labeled navigation, and semantic status that
never depends on color alone. Feature presentation remains feature-owned;
the shared layer contains only primitives used across several domains. A
Material app host remains as Flutter infrastructure for compatibility, but
the visible interaction system is Cupertino-first on iPhone, iPad, and Mac.

Each compact destination owns one `CustomScrollView` headed by a
`CupertinoSliverNavigationBar`. The large title collapses into the pinned bar,
and `CupertinoSliverRefreshControl` participates in the same scroll view. This
avoids a fixed navigation title competing with a second content title. The
wide shell moves server identity into the sidebar and gives the detail pane one
compact navigation bar, so iPad and Mac retain the same hierarchy without
simulating an oversized iPhone layout.

Inventory pages use Flutter's Cupertino search fields, sliding segmented
controls, list sections, list tiles, form sections, sheets, alerts, and dynamic
system colors. Revealed commands use an anchored menu; action sheets remain
reserved for choices related to an action, and sheets remain scoped tasks.
The complete surface and state contract lives in
[`docs/design/interface-inventory.md`](../design/interface-inventory.md).

## Dependency audit

The project has four direct third-party runtime dependencies:

| Dependency | Why it is justified | Rejected alternative |
| --- | --- | --- |
| [`cupertino_icons`](https://pub.dev/packages/cupertino_icons) | Flutter's official Cupertino symbol font for familiar Apple-platform navigation and actions. | Shipping missing glyphs, drawing and maintaining a custom icon font, or using Android-oriented symbols. |
| [`crypto`](https://pub.dev/packages/crypto) | Vetted SHA-256 implementation for certificate fingerprint pinning. | Hand-rolled cryptography. |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | Apple Keychain-backed credential persistence across iOS, iPadOS, and macOS. | Plaintext preferences or duplicating platform-channel Keychain code. |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Platform preference store for non-secret server metadata and selection. | Treating Keychain as a general JSON database. |

Flutter SDK facilities supply Cupertino UI, networking (`dart:io`), state
(`ChangeNotifier`), JSON, and testing. The project intentionally has no
third-party UI kit, `http`, provider, BLoC, reactive-state, analytics, push,
or codegen dependency. Transitive packages are resolved and pinned in
`pubspec.lock`; they are not used directly by application code.
