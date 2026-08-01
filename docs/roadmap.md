# Web-parity roadmap

PVE Companion is not yet a replacement for the Proxmox VE web interface. This
roadmap orders compatibility by operational value and safety rather than
claiming parity before it exists.

## Milestone 0.1 — secure daily companion

- [x] Multi-server profiles with password-realm and API-token authentication.
- [x] Optional Apple Keychain credential storage and in-memory password tickets.
- [x] Explicit per-server TLS fingerprint trust for untrusted certificates.
- [x] Cluster overview, nodes, VM/LXC inventory, configured storage, and
  recent-task visibility.
- [x] Guest details plus confirmed start, graceful shutdown, and reboot.
- [x] Adaptive macOS, iPadOS, and iOS navigation.

## Milestone 0.2 — trustworthy operations

- [ ] Guest task tracking with completion/error state after control actions.
- [ ] TOTP/2FA password-authentication challenge flow and clear unsupported
  authentication feedback.
- [ ] Filter, search, and sort across nodes and guests.
- [ ] Read-only guest runtime details, logs, and richer node/storage metrics.
- [ ] Named profile editing and certificate pin rotation with explicit
  re-verification.
- [ ] API capability/version negotiation and a fixture suite for supported PVE
  versions.

## Milestone 0.3 — console and lifecycle workflows

- [ ] Secure VNC/noVNC or SPICE console design, including ticket lifecycle,
  input adaptation, clipboard behavior, and revocation.
- [ ] Guest create/clone wizard with validation, least-privilege authorization,
  and task progress.
- [ ] Backup, snapshot, migration, and restore flows with irreversible-action
  review and confirmation.
- [ ] Optional biometric reauthentication before sensitive actions.

## Milestone 1.0 — selected web-surface parity

- [ ] Storage and network configuration editing.
- [ ] Cluster/HA and permission-aware administration surfaces.
- [ ] Full task/log visibility, a11y audit, localization, release hardening,
  migration support, and a supported-version policy.
- [ ] A documented evaluation of any remaining web-only workflows.

## Explicit non-goals until designed safely

- Force stop/reset, delete, or bulk destructive actions.
- Persisting session tickets or certificate private material.
- Public-internet assumptions for PVE management access.
- Background analytics, push notifications, or package-heavy architecture.
