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
| `core/api` | Transport-only Proxmox HTTP session, headers, ticket handling, response validation, and typed transport errors. |
| `core/security` | Keychain adapter and certificate fingerprint derivation. |

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

## Dashboard derivation

`cluster_overview/domain/datacenter_health.dart` turns a decoded snapshot into
typed health, issue, workload, task-activity, per-node, and capacity values.
This keeps rendering code free of policy decisions and lets pure unit tests
cover threshold boundaries without a widget or network connection.

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

The deterministic preview data belongs under `tool/support`, not `lib`, and
the preview target is local-only. It gives maintainers a repeatable healthy or
critical visual state without mixing demonstration data into application code.

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

## Adaptive UI

The workspace uses a navigation rail at wider Mac/iPad widths and a bottom
navigation bar at compact iPhone widths. All pages retain their controller
state when the layout switches. This is a single restrained Material 3 design
system, not a component-library abstraction.

## Dependency audit

The project has three direct third-party runtime dependencies:

| Dependency | Why it is justified | Rejected alternative |
| --- | --- | --- |
| [`crypto`](https://pub.dev/packages/crypto) | Vetted SHA-256 implementation for certificate fingerprint pinning. | Hand-rolled cryptography. |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | Apple Keychain-backed credential persistence across iOS, iPadOS, and macOS. | Plaintext preferences or duplicating platform-channel Keychain code. |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Platform preference store for non-secret server metadata and selection. | Treating Keychain as a general JSON database. |

Flutter SDK facilities supply UI, networking (`dart:io`), state
(`ChangeNotifier`), JSON, and testing. The project intentionally has no
`http`, provider, BLoC, reactive-state, UI-kit, analytics, push, or codegen
dependency. Transitive packages are resolved and pinned in `pubspec.lock`; they
are not used directly by application code.
