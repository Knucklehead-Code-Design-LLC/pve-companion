# Web-parity roadmap

PVE Companion is not yet a replacement for the Proxmox VE web interface. This
roadmap orders compatibility by operational value and safety rather than
claiming parity before it exists.

## Milestone 0.1 — secure daily companion

- [x] Multi-server profiles with password-realm and API-token authentication.
- [x] Optional Apple Keychain credential storage and in-memory password tickets.
- [x] Explicit per-server TLS fingerprint trust for untrusted certificates.
- [x] Datacenter command center that prioritizes reported problems and
  pressure, then capacity, VM/LXC workload, nodes, configured storage, and
  recent reported activity.
- [x] Guest details plus confirmed start, graceful shutdown, and reboot.
- [x] Adaptive macOS, iPadOS, and iOS navigation.
- [x] Cupertino search, status filters, and operational sorting across guest
      and node inventories, plus focused storage and task filters.
- [x] Current-state resource, workload, availability, storage, and task-outcome
      visualizations without a charting dependency or implied historical data.
- [x] Storage configuration merged with reported per-node capacity telemetry,
      including shared-capacity de-duplication and node coverage.
- [x] Small, medium, and large Home Screen layouts plus Lock Screen status
      widgets using a privacy-safe last-known datacenter snapshot, honest stale
      state, and destination-specific links.
- [x] Time-bounded Datacenter Watch Live Activity for Lock Screen and Dynamic
      Island maintenance monitoring.

## Milestone 0.2 — trustworthy operations

- [ ] Guest task tracking with completion/error state after control actions.
- [ ] TOTP/2FA password-authentication challenge flow and clear unsupported
  authentication feedback.
- [ ] Read-only guest runtime details and logs, plus deeper node/storage detail
  beyond the current cluster and per-node utilization summaries.
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
