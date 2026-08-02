# Interface inventory

This inventory is the review contract for PVE Companion's Flutter/Cupertino
interface. A release should exercise every surface and state listed here at an
iPhone width, an iPad width, and a Mac window width where the surface is
available.

## Adaptive workspace

| Surface | Compact iPhone behavior | iPad and Mac behavior |
| --- | --- | --- |
| Primary navigation | Five stable `CupertinoTabBar` destinations with 23-point destination icons. | Persistent sidebar with a fixed 288-point iPad width and 304-point/320-point regular/wide Mac widths, an inset server switcher, a quiet selected state, and connected-state context. |
| Page navigation | Each destination owns a `CupertinoSliverNavigationBar`; its large title collapses into the pinned bar while scrolling. Server selection leads and workspace commands trail. | The sidebar owns server selection. The detail pane owns one compact `CupertinoNavigationBar` with the current destination and workspace commands. |
| Refresh | Pull to refresh within each destination; the workspace menu remains an accessible fallback. An initial failure replaces loading with retry, while a later failure retains the last snapshot and presents a retryable banner. | Pull to refresh plus one accessible Refresh action in the connected-status footer. The footer visibly and semantically reports data freshness or a failed refresh, and the retained page presents the same retryable banner. Refresh is omitted from the title bar and overflow menu to avoid duplication. |
| Scrolling | One `CustomScrollView` per destination, status-bar tap to top, Cupertino overscroll, and retained tab state. | The same destination scroll model inside the detail pane; the sidebar remains fixed. |

## Primary destinations

| Destination | Information hierarchy | Primary interactions |
| --- | --- | --- |
| Overview | Proxmox version context; incident highlights; compact health drill-in; current CPU, memory, and disk pressure; workload composition; storage capacity; node pressure; recent activity. | Pull/footer refresh; open incident targets, guests, storage, nodes, or tasks. Charts show current composition and pressure, never invented history. |
| Guests | Four-metric status strip; aggregate CPU, memory, and disk footprint; VM/LXC composition and placement; explicit filtered-result count; search and status filter; running-first inventory with templates kept separate from stopped workloads. iPhone puts inventory before deeper analysis. | Search by name, node, VMID, or kind; filter; open a task-aware guest detail surface. |
| Nodes | Four-metric status strip; cluster pressure and node-availability analysis; search and attention filter; attention-first cards with CPU, memory, disk, cores, and uptime. iPhone puts node cards before deeper analysis. | Search by node name; filter; pull/footer refresh; open guarded node operations when connected. |
| Storage | Configured, fully available, used, and free metrics; Backup Center; effective-capacity and topology analysis; risk-ordered pool utilization; explicit filtered-result count; local/shared filter; per-node pool coverage. iPhone puts pool cards before deeper analysis. | Open Backup Center; filter and refresh. Pool state distinguishes fully available, partially available, unavailable, and unreported. Capacity and availability remain explicitly unreported when the API account does not provide that telemetry. |
| Tasks | Prioritized outcome strip and activity profile; failed and active operations appear ahead of routine history, while long-running console sessions are labeled separately. Search, state filters, result counts, and type/node/user/time/duration inventory support investigation. iPhone puts recent operations before deeper analysis. | Search, filter, and refresh. |

## Scoped and secondary surfaces

| Surface | Presentation | Required states |
| --- | --- | --- |
| Welcome | Centered first-run explanation, Cupertino feature list, and one Add Proxmox Server call to action. | Default and large text. |
| Disconnected workspace | Selected-server context with Connect and Add Another Server actions. | No selection, ready, connecting, and connection error. |
| Add server | Cupertino sheet with Server, Sign In, and On This Device form sections. | Password/API token, validation, submitting, server error, certificate trust. |
| Manage servers | Cupertino sheet with add, select/connect, selected state, and delete. | Empty, populated, busy, connection failure, removal confirmation. |
| Guest detail | Cupertino sheet with guest runtime, task status, confirmed power controls, snapshot/backup workflows, safe configuration form rows, recent guest activity, and an in-app guest console. Compact widths use one column; desktop sheets use a two-column investigation layout. Templates show their read-only state instead of power controls. | Loading, loaded/stopped/running/template, action busy/error/success, load failure, no backup destination, console connecting/connected/error/privacy-closed states. |
| Incident Center | Cupertino sheet with prioritized critical/attention incidents and target-specific drill-ins. The dashboard only surfaces this section when attention is needed, avoiding duplicate healthy-state messaging. | Healthy empty state, critical/warning mix, and every target navigation. |
| Node detail | Cupertino sheet with system/version information, service state, package-update inventory, task status, and guarded node/service actions. Compact widths use one column; desktop sheets separate node state and guarded controls from updates and services. | Loading, unavailable/offline, permission-limited details, action busy/error/success, load failure. |
| Backup Center | Cupertino sheet with configured destinations, scheduled jobs, discovered copies, and recent backup task state. | Loading, no backup storage, no schedules/copies, permission-limited data, and load failure. |
| Datacenter Portfolio | Cupertino sheet with short-lived, read-only health refreshes for every saved profile. | Loading, healthy/attention/critical/unavailable rows, no profiles, and active-workspace switching. |
| Notifications | Cupertino sheet with local-alert permission, critical/attention preferences, and explicit refresh-only / non-continuous monitoring boundaries. | Undetermined, authorized, denied, unsupported, busy, and persistence/delivery failure. |
| Cluster Administration | Cupertino sheet with read-only membership, quorum, HA, and safe datacenter-option audit. | Loading, permission-limited values, quorate/non-quorate, HA attention, and load failure. |
| Datacenter Watch | Cupertino sheet explaining visible data and a time-bounded start action. | Available, busy, start failure, active/end command. |
| About and privacy | Cupertino alert with version, independence, security, privacy, and project links. | Default and link launch failure where applicable. |

## Apple system surfaces

WidgetKit owns dedicated small, medium, and large Home Screen layouts,
inline/circular/rectangular Lock Screen widgets, and the Datacenter Watch Live
Activity. Small emphasizes health and essential counts; medium adds linked
node, guest, and task metrics; large adds resource pressure and failed-task
context. Test placeholder, no-data, populated, stale, critical, full-color,
tinted, clear-glass, dark, reduced-transparency, and Always-On variants. Widget
and metric taps open the relevant Flutter workspace destination. Visible
snapshots contain aggregate status, counts, and current pressure only; they
never contain server endpoints, host/guest names, users, or credentials.

## Visual qualification

The deterministic store preview renders all five primary destinations from
production widgets. The capture pipeline produces five iPhone, five portrait
iPad, and five Mac review images. Before release, also exercise landscape iPad,
scrolling title collapse,
pull to refresh, sidebar footer refresh, search results, every filter, empty results, critical health,
Dynamic Type, light/dark appearance, guarded-operation confirmation, task state,
and the secondary sheets on simulators or
physical devices.
