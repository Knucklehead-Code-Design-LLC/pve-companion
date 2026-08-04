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
- [x] Guest details plus confirmed power actions, safe configuration updates,
  snapshots, and on-demand backup submission.
- [x] Adaptive macOS, iPadOS, and iOS navigation.
- [x] Cupertino search, status filters, and operational sorting across guest
      and node inventories, plus focused storage and task filters.
- [x] Current-state resource, workload, availability, storage, and task-outcome
      visualizations, plus explicit Proxmox RRD-backed node performance history
      when server telemetry and permissions are available.
- [x] Storage configuration merged with reported per-node capacity telemetry,
      including shared-capacity de-duplication and node coverage.
- [x] Small, medium, and large Home Screen layouts plus Lock Screen status
      widgets using a privacy-safe last-known datacenter snapshot, honest stale
      state, and destination-specific links.
- [x] Time-bounded Datacenter Watch Live Activity for Lock Screen and Dynamic
      Island maintenance monitoring.

## Milestone 0.2 — trustworthy operations

- [x] Guest and node task tracking with completion/error state after control
  actions, plus bounded polling and refresh-safe status cards.
- [x] Read-only guest runtime details and recent activity, node service/version
  detail, backup destinations/schedules/copies, and an Incident Center derived
  from the latest reported datacenter state.
- [x] Guarded node restart/shutdown, service restart, and package-index refresh
  actions. The client does not perform unattended package upgrades.
- [x] Read-only multi-datacenter portfolio using short-lived sessions for
  saved Keychain profiles without replacing the active workspace.
- [x] Local foreground notification preferences for newly observed incidents.
- [x] Cluster posture audit for membership, quorum, HA state, and safe
  datacenter options.
- [ ] TOTP/2FA password-authentication challenge flow and clear unsupported
  authentication feedback.
- [ ] Named profile editing and certificate pin rotation with explicit
  re-verification.
- [ ] API capability/version negotiation and a fixture suite for supported PVE
  versions.

## Milestone 0.3 — console and lifecycle workflows

- [x] In-app VM/LXC VNC console with ticket lifecycle, framebuffer rendering,
  pointer/keyboard input, clipboard support, and foreground revocation.
- [ ] SPICE console design and compatibility policy.
- [ ] Guest create/clone wizard with validation, least-privilege authorization,
  and task progress.
- [x] Snapshot creation, rollback/deletion confirmation, and on-demand backup
  submission with task status.
- [ ] Migration and restore flows with irreversible-action review and
  confirmation.
- [ ] Optional biometric reauthentication before sensitive actions.

## Milestone 1.0 — selected web-surface parity

- [ ] Storage and network configuration editing.
- [x] Read-only cluster/HA posture and permission-aware unavailable states.
- [ ] Cluster/HA configuration editing after a dedicated safety and permission
  design.
- [ ] Full task/log visibility, a11y audit, localization, release hardening,
  migration support, and a supported-version policy.
- [ ] A documented evaluation of any remaining web-only workflows.

## Explicit non-goals until designed safely

- Guest deletion or bulk destructive actions.
- Persisting session tickets or certificate private material.
- Public-internet assumptions for PVE management access.
- Background analytics, push notifications, or package-heavy architecture.
