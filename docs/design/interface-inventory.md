# Interface inventory

This inventory is the review contract for PVE Companion's Flutter/Cupertino
interface. A release should exercise every surface and state listed here at an
iPhone width, an iPad width, and a Mac window width where the surface is
available.

## Adaptive workspace

| Surface | Compact iPhone behavior | iPad and Mac behavior |
| --- | --- | --- |
| Primary navigation | Five stable `CupertinoTabBar` destinations with 23-point destination icons. | Persistent sidebar with a 288-point iPad width, a 264-point Mac width, an inset server switcher, a quiet selected state, and connected-state context. |
| Page navigation | Each destination owns a `CupertinoSliverNavigationBar`; its large title collapses into the pinned bar while scrolling. Server selection leads and workspace commands trail. | The sidebar owns server selection. The detail pane owns one compact `CupertinoNavigationBar` with the current destination and workspace commands. |
| Refresh | Pull to refresh within each destination; the workspace menu remains an accessible fallback. | Pull to refresh plus one labeled Refresh action in the connected-status footer. Refresh is omitted from the title bar and overflow menu to avoid duplication. |
| Scrolling | One `CustomScrollView` per destination, status-bar tap to top, Cupertino overscroll, and retained tab state. | The same destination scroll model inside the detail pane; the sidebar remains fixed. |

## Primary destinations

| Destination | Information hierarchy | Primary interactions |
| --- | --- | --- |
| Overview | Proxmox version context; compact health drill-in; current CPU, memory, and disk pressure; workload composition; storage capacity; node pressure; recent activity. | Pull/footer refresh; open health, guests, storage, nodes, or tasks. Charts show current composition and pressure, never invented history. |
| Guests | Four-metric status strip; aggregate CPU, memory, and disk footprint; VM/LXC composition and placement; search and status filter; running-first inventory with per-guest pressure on wide screens. iPhone puts inventory before deeper analysis. | Search by name, node, VMID, or kind; filter; open guest detail. |
| Nodes | Four-metric status strip; cluster pressure and node-availability analysis; search and attention filter; attention-first cards with CPU, memory, disk, cores, and uptime. iPhone puts node cards before deeper analysis. | Search by node name; filter; pull/footer refresh. |
| Storage | Configured, available, used, and free metrics; effective-capacity and topology analysis; pool utilization; local/shared filter; per-node pool coverage. iPhone puts pool cards before deeper analysis. | Filter and refresh. Capacity and availability remain explicitly unreported when the API account does not provide that telemetry. |
| Tasks | Four-metric outcome strip; outcome rate and activity profile; type, node, user, time, duration, and state inventory. iPhone puts recent operations before deeper analysis. | Filter and refresh. |

## Scoped and secondary surfaces

| Surface | Presentation | Required states |
| --- | --- | --- |
| Welcome | Centered first-run explanation, Cupertino feature list, and one Add Proxmox Server call to action. | Default and large text. |
| Disconnected workspace | Selected-server context with Connect and Add Another Server actions. | No selection, ready, connecting, and connection error. |
| Add server | Cupertino sheet with Server, Sign In, and On This Device form sections. | Password/API token, validation, submitting, server error, certificate trust. |
| Manage servers | Cupertino sheet with add, select/connect, selected state, and delete. | Empty, populated, busy, connection failure, removal confirmation. |
| Guest detail | Cupertino sheet with one navigation title, guest context, runtime metrics, confirmed power controls, and safe configuration form rows. | Loading, loaded/stopped/running/template, action busy/error/success, load failure. |
| Datacenter Watch | Cupertino sheet explaining visible data and a time-bounded start action. | Available, busy, start failure, active/end command. |
| About and privacy | Cupertino alert with version, independence, security, privacy, and project links. | Default and link launch failure where applicable. |

## Apple system surfaces

WidgetKit owns small/medium Home Screen widgets, inline/circular/rectangular
Lock Screen widgets, and the Datacenter Watch Live Activity. Test placeholder,
populated, stale, tinted, dark, reduced-transparency, and Always-On variants.
Visible snapshots contain aggregate status and counts only; they never contain
server endpoints, host/guest names, users, or credentials.

## Visual qualification

The deterministic store preview renders all five primary destinations from
production widgets. The capture pipeline produces five iPhone, five portrait
iPad, and five Mac review images. Before release, also exercise landscape iPad,
scrolling title collapse,
pull to refresh, sidebar footer refresh, search results, every filter, empty results, critical health,
Dynamic Type, light/dark appearance, and the secondary sheets on simulators or
physical devices.
