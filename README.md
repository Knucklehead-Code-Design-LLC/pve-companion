# PVE Companion

PVE Companion is an open-source, Apple-first Flutter client for managing
Proxmox VE servers from macOS, iPhone, and iPad. It is a clean-room project:
it talks to the documented Proxmox REST API and does not reuse the official
frontend or its Dart packages.

> **Independent project.** PVE Companion is not affiliated with, endorsed by,
> or sponsored by Proxmox Server Solutions GmbH. “Proxmox” and “Proxmox VE”
> are used only to describe compatibility and may be trademarks of their
> respective owners.

## Current capability

PVE Companion is deliberately useful without claiming web-interface parity:

- Multiple named server profiles, with password-realm or API-token sign-in.
- Password sign-in does not yet implement TOTP/2FA challenge flows. Use an
  appropriately scoped API token for a 2FA-protected account until that
  workflow is implemented.
- Optional credential retention in Apple Keychain; profile preferences never
  contain passwords, token secrets, tickets, or CSRF values.
- Ephemeral password session tickets and per-server SHA-256 certificate
  fingerprint trust. The app never globally disables TLS validation.
- An adaptive Overview command center for Mac, iPad, and iPhone that puts
  operational problems first, then capacity, workload, nodes, and recent
  reported activity. Stopped guests remain workload inventory, not incidents.
- Apple-native navigation and interaction patterns: stable tabs on iPhone,
  collapsible sliver titles, tactile confirmation, and pull-to-refresh, a
  persistent sidebar on iPad
  and Mac, real navigation bars, anchored command menus, Cupertino search and
  filters, inset grouped data, scoped sheets, clear confirmations, Dynamic
  Type support, and system light/dark appearance.
- Privacy-safe WidgetKit views for the iPhone and iPad Home Screen and Lock
  Screen. Dedicated small, medium, and large Home Screen layouts summarize
  health, nodes, guests, tasks, and aggregate resource pressure; metric links
  open the matching app destination. Widgets identify data older than one hour
  as stale and never store or display a server URL, hostname, username,
  credential, ticket, or CSRF token.
- An optional four-hour **Datacenter Watch** Live Activity for maintenance and
  incident windows. It appears on the Lock Screen and, on supported iPhones,
  in the Dynamic Island, and updates whenever the app refreshes the cluster.
- An Incident Center that derives prioritized, drill-down-ready attention from
  offline nodes, per-node pressure, storage availability/capacity, and failed
  reported tasks.
- VM/LXC details with task-aware power controls, snapshots, guest backups,
  recent guest task state, and a narrow configuration editor for CPU, memory,
  start-at-boot, and description. Force Stop and Reset are explicitly
  confirmed and visually separated from normal power actions.
- Node detail and guarded operations: restart/shut down a reported-online
  node, restart a reported service, and refresh its package index. The app
  never performs a package upgrade automatically.
- Backup Center for reviewing configured backup destinations, schedules,
  copies, and recent backup activity. On-demand backups originate from the
  relevant guest detail so their scope is unambiguous.
- A short-lived, read-only multi-datacenter portfolio for all saved Keychain
  profiles. It never changes the active workspace while collecting status.
- Local alerts for newly observed critical or attention incidents, plus
  opt-in reachability-change alerts on iPhone, iPad, and Mac for the selected
  datacenter when its credential is saved in Keychain. OS-scheduled background
  timing is controlled by Apple (and macOS checks require the app to remain
  running), so they supplement—not replace—Proxmox or a real monitoring
  system.
- A Cluster Administration audit surface for membership, quorum, HA state, and
  safe datacenter options. Cluster topology, storage, and network changes stay
  in Proxmox's full administration UI.
- An in-app VM/LXC VNC console with framebuffer, pointer, keyboard, and
  clipboard controls. Its short-lived VNC ticket stays inside the authenticated
  transport and is discarded after connection setup.
- An original, trademark-distinct app icon and deterministic App Store capture
  flows for iPhone, iPad, and Mac.

It does **not** yet provide guest creation or deletion, migration, restore,
SPICE, package upgrades, cluster/network topology editing, roles, continuous
background monitoring, or a replacement for every Proxmox VE web surface. See
the
[web-parity roadmap](docs/roadmap.md) for the planned path.

## Security model

Use a VPN or a trusted private network to reach Proxmox VE. Do not forward
port `8006` directly to the public internet.

- Server URLs must use HTTPS.
- A self-signed or otherwise untrusted certificate pauses connection and shows
  its SHA-256 fingerprint. Trust requires an explicit confirmation after
  out-of-band verification and is pinned only to that server host and port.
- Server profile metadata lives in platform preferences. Opted-in credential
  secrets live only in Apple Keychain. Password tickets remain in memory for
  the current app session.
- Configuration details are allow-listed before display so secrets are not
  casually surfaced in the guest detail view.
- In-app consoles use the existing authenticated WebSocket and certificate
  pinning path. Their VNC ticket is held only in memory by the transport,
  never exposed to UI code, and discarded after setup or when the app leaves
  the foreground.
- Local incident notifications can display the selected profile name and an
  incident title (such as a node or storage name) on the device. Local
  connection-change notifications can also be evaluated during Apple-scheduled
  background activity for the selected profile when its credential is saved in
  Keychain. These checks are opportunistic; on macOS the app must remain
  running, and alerts may be visible to someone with physical access to the
  device.
- A sanitized aggregate snapshot is stored in the app's private Apple App
  Group so the WidgetKit extension can render it. Datacenter Watch is started
  only by the user and shows aggregate health/counts on visible system
  surfaces.

Read the [architecture and dependency audit](docs/architecture/architecture.md)
before contributing authentication, network, or certificate changes.
Use the [interface inventory](docs/design/interface-inventory.md) when
reviewing a UI change or qualifying an Apple-platform release.
Read the public [privacy policy](PRIVACY.md) for the developer's data-handling
commitments.

## Local development

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

For a deterministic, local-only visual review of the Overview dashboard, run
the preview target on a booted iPhone or iPad simulator. It uses fixture data
only and never contacts a server:

```sh
flutter devices
flutter run -d <ios-simulator-id> -t tool/datacenter_dashboard_preview.dart
```

Use the Healthy/Critical switch to review both states; use an iPhone simulator
for compact layout and an iPad simulator for wide layout. The same target can
run on macOS only in a development environment with a valid Apple signing
identity, because the app's Keychain entitlement prevents an unsigned macOS
debug launch.

For App Store screenshots, use the production-widget capture target and the
checked-in capture guide:

```sh
flutter run -d <ios-simulator-id> \
  -t tool/store_screenshot_preview.dart \
  --dart-define=SCREENSHOT_SCENE=overview
```

See [App Store screenshots](docs/app-store/screenshots/README.md) for the exact
device canvases and repeatable multi-scene capture command.

The Mac screenshots need no signing identity:

```sh
tool/capture_macos_store_screenshots.sh
```

### Dashboard health semantics

Overview derives its health banner from the latest reported snapshot. Offline
nodes and critical per-node pressure are critical; failed recent reported
tasks and warning pressure need attention. Peak CPU use is the highest
reported node, while memory and root-disk capacity aggregate only nodes with
complete values. Health checks every reporting node so a hot node cannot be
masked by a low cluster average. Reported CPU, memory, or root-disk pressure
is warning at **75% or above** and critical at **90% or above**.

“All systems operational” means the latest snapshot contains no derived issue;
it does not claim that every possible metric was reported. Missing or
incomplete telemetry remains explicitly unreported.

Configured storage is shown as inventory backed by available cluster telemetry.
Backup Center reads only backup destinations and content exposed to the signed-in
Proxmox account; it does not invent a retention policy or manipulate copies.

Apple builds are intentionally verified locally, not on paid macOS GitHub
Actions runners. An iOS simulator build does not require signing; the macOS
compile-only check intentionally disables signing because Keychain Sharing
requires a real development certificate for an installable app:

```sh
flutter build ios --simulator
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Release -derivedDataPath /tmp/pve-companion-macos-build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

See [Apple build and release notes](docs/release/apple-builds.md) for signing,
simulator, distribution, App Store metadata, and TestFlight guidance. GitHub
Actions runs the low-cost Ubuntu verification path; Codemagic compiles iOS pull
requests without credentials, uploads signed iOS/iPadOS and macOS `main`
builds to TestFlight, and submits the platform-specific artifacts for
version-tagged releases to App Store review.

## Project design

The project uses feature-owned folders and an explicit dependency direction:
widget → controller → repository → HTTP service. The WidgetKit and ActivityKit
extension is native SwiftUI and communicates through one dependency-free
platform channel and an App Group. The Flutter app uses four direct
third-party packages only: Apple’s official Cupertino icon font, vetted
SHA-256 support, Keychain storage, and non-secret preference storage. The
full rationale is in the
[dependency audit](docs/architecture/architecture.md#dependency-audit).

The [clean-room licensing decision](docs/architecture/0001-clean-room-proxmox-client.md)
records why this project is Apache-2.0 instead of an AGPL-derived frontend.

## Contributing and support

Please read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
the [Code of Conduct](CODE_OF_CONDUCT.md). Use GitHub private vulnerability
reporting for security issues; do not place credentials, server URLs, or
certificate private keys in issues, logs, or pull requests.

PVE Companion is licensed under [Apache-2.0](LICENSE).
