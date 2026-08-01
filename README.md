# PVE Companion

PVE Companion is an open-source, Apple-first Flutter client for managing
Proxmox VE servers from macOS, iPhone, and iPad. It is a clean-room project:
it talks to the documented Proxmox REST API and does not reuse the official
frontend or its Dart packages.

> **Independent project.** PVE Companion is not affiliated with, endorsed by,
> or sponsored by Proxmox Server Solutions GmbH. “Proxmox” and “Proxmox VE”
> are used only to describe compatibility and may be trademarks of their
> respective owners.

## First milestone

The `0.1` baseline is deliberately useful without claiming web-interface
parity:

- Multiple named server profiles, with password-realm or API-token sign-in.
- Optional credential retention in Apple Keychain; profile preferences never
  contain passwords, token secrets, tickets, or CSRF values.
- Ephemeral password session tickets and per-server SHA-256 certificate
  fingerprint trust. The app never globally disables TLS validation.
- Responsive Mac, iPad, and iPhone navigation for cluster overview, nodes,
  guest inventory, configured storage, and recent tasks.
- VM/LXC details plus confirmed, non-force start, shutdown, and reboot
  requests. Storage and tasks are read-only in this milestone.

It does **not** yet provide guest consoles, guest creation, destructive
deletion, migration, backup/restore, cluster/network configuration, roles,
or a replacement for every Proxmox VE web surface. See the
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

Read the [architecture and dependency audit](docs/architecture/architecture.md)
before contributing authentication, network, or certificate changes.

## Local development

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Apple builds are intentionally verified locally, not on paid macOS GitHub
Actions runners. An iOS simulator build does not require signing; the macOS
compile-only check intentionally disables signing because Keychain Sharing
requires a real development certificate for an installable app:

```sh
flutter build ios --simulator --no-codesign
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Debug -derivedDataPath /tmp/pve-companion-macos-build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

See [Apple build and release notes](docs/release/apple-builds.md) for signing,
simulator, and distribution guidance. CI runs format, analysis, and tests on
an Ubuntu runner only.

## Project design

The project uses feature-owned folders and an explicit dependency direction:
widget → controller → repository → HTTP service. It uses three direct
third-party packages only: vetted SHA-256 support, Keychain storage, and
non-secret preference storage. The full rationale is in the
[dependency audit](docs/architecture/architecture.md#dependency-audit).

The [clean-room licensing decision](docs/architecture/0001-clean-room-proxmox-client.md)
records why this project is Apache-2.0 instead of an AGPL-derived frontend.

## Contributing and support

Please read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and
the [Code of Conduct](CODE_OF_CONDUCT.md). Use GitHub private vulnerability
reporting for security issues; do not place credentials, server URLs, or
certificate private keys in issues, logs, or pull requests.

PVE Companion is licensed under [Apache-2.0](LICENSE).
