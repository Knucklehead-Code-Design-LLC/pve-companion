# Interface inventory

This inventory is the review contract for PVE Companion's Flutter/Cupertino
interface. A release should exercise every surface and state listed here at an
iPhone width, an iPad width, and a Mac window width where the surface is
available.

## Adaptive workspace

| Surface | Compact iPhone behavior | iPad and Mac behavior |
| --- | --- | --- |
| Primary navigation | Five stable `CupertinoTabBar` destinations with 23-point destination icons. | Persistent sidebar with a 288-point iPad width, a 264-point Mac width, an inset server switcher, a quiet selected state, and connected-state context. |
| Page navigation | Each destination owns a `CupertinoSliverNavigationBar`; its large title collapses into the pinned bar while scrolling. Server selection leads and workspace commands trail. | The sidebar owns server selection. The detail pane owns one compact `CupertinoNavigationBar` with the current destination, refresh, and workspace commands. |
| Refresh | Pull to refresh within each destination; the hidden workspace menu remains an accessible fallback. | Pull to refresh plus one visible detail-toolbar refresh action. Refresh is omitted from the overflow menu to avoid duplication. |
| Scrolling | One `CustomScrollView` per destination, status-bar tap to top, Cupertino overscroll, and retained tab state. | The same destination scroll model inside the detail pane; the sidebar remains fixed. |

## Primary destinations

| Destination | Information hierarchy | Primary interactions |
| --- | --- | --- |
| Overview | Proxmox version context; compact health drill-in; aligned CPU, memory, disk, and workload summaries; storage inventory; node pressure; recent activity. | Pull/toolbar refresh; open health, guests, storage, nodes, or tasks. Healthy status omits redundant prose. |
| Guests | Workload/running summary; search; All/Running/Stopped filter; running-first alphabetical inventory. iPad adds a four-metric strip, an inline wide control row, and two-column workload cards. | Search by name, node, VMID, or kind; filter; open guest detail. |
| Nodes | Online/attention summary; search; All/Attention filter; attention-first alphabetical cards with CPU, memory, disk, cores, and uptime. iPad adds node, online, attention, and core metrics. | Search by node name; filter; pull/toolbar refresh. |
| Storage | Configured/shared summary; All/Shared/Local filter; type and allowed content inventory. iPad adds four storage metrics and two-column pool cards. | Filter and refresh. Utilization is never implied when the API does not report it. |
| Tasks | Recent/running/failed summary; All/Running/Failed filter; type, node, user, time, and state inventory. iPad adds four activity metrics and two-column task cards. | Filter and refresh. |

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
pull to refresh, search results, every filter, empty results, critical health,
Dynamic Type, light/dark appearance, and the secondary sheets on simulators or
physical devices.
