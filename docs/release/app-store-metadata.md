# App Store metadata

This is the reviewed English (U.S.) metadata baseline for version 1.0.0. Keep
the live App Store Connect record synchronized when product behavior changes.

| Field | Value |
| --- | --- |
| Name | PVE Companion |
| Subtitle | See your datacenter clearly |
| Primary category | Developer Tools |
| Secondary category | Utilities |
| Bundle ID | `com.knuckleheadcodedesign.pvecompanion` |
| SKU | `pve-companion-ios` |
| Supported product-page platforms | iOS, iPadOS, and macOS |
| Existing App Store Connect platforms | iOS, iPadOS, and macOS; each has a prepared 1.0.0 version |
| macOS Xcode category | `public.app-category.developer-tools` |
| Copyright | 2026 Knucklehead Code & Design LLC |
| Privacy policy URL | `https://github.com/Knucklehead-Code-Design-LLC/pve-companion/blob/main/PRIVACY.md` |
| Support URL | `https://github.com/Knucklehead-Code-Design-LLC/pve-companion/issues` |
| Marketing URL | `https://github.com/Knucklehead-Code-Design-LLC/pve-companion` |

## Promotional text

See the health of your Proxmox VE datacenter at a glance, then move directly
into guests, nodes, storage, and recent tasks from iPhone, iPad, or Mac.

## Description

PVE Companion is a secure, open-source companion for Proxmox VE. Its adaptive
datacenter view puts operational issues, capacity, workloads, node pressure,
and recent activity in one clear command center.

Save multiple named server profiles, connect with a password or API token,
and optionally keep credentials in Apple Keychain. Self-signed certificates
require explicit SHA-256 fingerprint confirmation and are pinned only to the
server you approve.

Core features:

- Datacenter health, capacity, workload, nodes, and recent task activity
- VM and LXC inventory with focused details
- Confirmed start, shutdown, and reboot requests
- Read-only storage and task views
- Apple-native tabs, sidebar, sheets, and adaptive layouts for iPhone, iPad,
  and Mac
- Small, medium, and large iPhone and iPad Home Screen widgets for last-known
  datacenter health, workload, activity, and aggregate resource pressure
- Optional four-hour iPhone Datacenter Watch on the Lock Screen and Dynamic
  Island
- No ads, analytics, tracking, or developer-operated cloud service

PVE Companion connects directly to the Proxmox VE server you configure. Use a
trusted private network or VPN; never expose port 8006 directly to the public
internet.

PVE Companion is an independent project and is not affiliated with, endorsed
by, or sponsored by Proxmox Server Solutions GmbH. Proxmox and Proxmox VE are
used only to describe compatibility and may be trademarks of their respective
owners.

## Platform-local product-page content

Use the promotional text, description, keywords, URLs, and release notes above
for both the iOS/iPadOS and macOS platform versions. When macOS is added to an
existing App Store Connect record, Apple transfers most shared metadata but
not the platform promotional text, description, or screenshots. Keep those
Mac fields synchronized deliberately rather than assuming they copied.

The Mac App Store category must remain **Developer Tools**, matching the
`LSApplicationCategoryType` declared by the macOS target. Keep **Utilities**
as the secondary category unless the product meaningfully changes.

## Keywords

`proxmox,virtualization,homelab,server,vm,lxc,datacenter,monitoring,sysadmin`

## Version 1.0.0 release notes

Initial release across iPhone, iPad, and Mac with secure server profiles, an
Apple-first datacenter command center, guest inventory and power actions, node
health, storage inventory, and recent task activity. iPhone and iPad also
include Home and Lock Screen widgets plus an optional Datacenter Watch Live
Activity.

## Screenshot order

Upload the five files from each platform folder in this order:

1. `01-datacenter-overview.jpg` — Health, at a glance.
2. `02-guest-inventory.jpg` — Every guest, in clear view.
3. `03-node-health.jpg` — Know which nodes need attention.
4. `04-storage-inventory.jpg` — Capacity, made clear.
5. `05-recent-tasks.jpg` — Every task, in one place.

The files are generated from the real production-widget views and live in
[`docs/app-store/screenshots`](../app-store/screenshots/README.md). Do not
reorder a single platform independently without reviewing its product-page
preview.

## App privacy answer baseline

Select **Data Not Collected**. Server and credential information is processed
on-device and sent only to the user-configured Proxmox endpoint; it is not
transmitted to the developer or a developer-controlled third party. Recheck
this answer before every release and whenever a dependency or service is
added.

The age-rating questionnaire should describe the app as an infrastructure
utility with no user-generated content, advertising, gambling, commerce,
violence, or mature content. App Store Connect calculates the displayed age
rating from the current questionnaire; do not hard-code a rating in marketing
copy.
