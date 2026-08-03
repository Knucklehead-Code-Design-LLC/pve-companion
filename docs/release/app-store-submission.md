# App Store submission handoff

This is the final handoff for the initial iOS, iPadOS, and macOS App Store
release. It does not submit the app or store reviewer credentials in the
repository. Complete the linked checks before creating an App Store review
submission.

## Submission package

| Item | Prepared source | Current state |
| --- | --- | --- |
| English (U.S.) product-page copy | [app-store-metadata.md](app-store-metadata.md) | Entered for both prepared platform versions |
| iPhone, iPad, and Mac screenshots | [screenshots](../app-store/screenshots/README.md) | Five branded JPEGs per device family, uploaded to the prepared versions |
| Privacy policy, support, and marketing URLs | [app-store-metadata.md](app-store-metadata.md) | Public and reachable |
| App privacy answer | [app-store-metadata.md](app-store-metadata.md) | `Data Not Collected`; recheck after every dependency or service change |
| Archive, signing, TestFlight, and device qualification | [apple-builds.md](apple-builds.md) and [testflight-checklist.md](testflight-checklist.md) | Requires publishing-account work |
| Static release-asset validation | `tool/verify_app_store_submission.sh` | Run before upload or review submission |
| Guest-console policy review | [App Review Guidelines §4.2.7](https://developer.apple.com/app-store/review/guidelines/) | Resolve before public submission |

The checked-in source supports version `1.0.0` on iOS, iPadOS, and macOS. The
existing App Store Connect record contains prepared 1.0.0 versions for both
iOS/iPadOS and macOS. A macOS build still cannot be attached until its Mac App
Store signing key is configured in Codemagic and the build has finished
processing.

## macOS platform state

macOS has been added to the existing PVE Companion record. It remains one
universal-purchase record with the existing Apple ID, SKU, and bundle ID
`com.knuckleheadcodedesign.pvecompanion`; do not create a separate Mac app
record. The Mac version is `1.0.0` with its promotional text, description, and
five prepared screenshots entered. Apple copies most shared metadata when a
platform is added, but not those platform-local fields.

Before uploading the first Mac build, configure a **Mac App Distribution**
certificate, a **Mac Installer Distribution** certificate, and a matching
**Mac App Store** provisioning profile under the publishing organization.
`macos-testflight` retrieves or creates those signing files after the protected
Codemagic `CERTIFICATE_PRIVATE_KEY` is configured. The macOS target already
declares the required App Sandbox entitlement, matching bundle ID, privacy
manifest, encryption declaration, and Developer Tools category. Do not reuse
an iOS distribution profile for the Mac target.

## Complete in App Store Connect

The publishing organization must complete these account-scoped items. They
cannot be safely inferred or committed to source control.

- Confirm agreements, banking and tax status, trader status where applicable,
  availability territories, price, and App Review contact details.
- Confirm the primary category is **Developer Tools** on the shared App
  Information page and matches the macOS target's
  `public.app-category.developer-tools` declaration.
- Verify each platform's uploaded screenshots and product-page preview.
- Complete the current age-rating questionnaire from the app's actual
  behavior. Select no social-media capabilities, user-generated-content
  features, advertising, commerce, gambling, or mature content unless the
  shipping binary has changed. Do not select a Kids category or override the
  calculated rating without a product or legal reason.
- Reconfirm App Privacy as **Data Not Collected** only after auditing every
  dependency and the shipping build. Direct requests to a server that the
  developer cannot access or retain are not, by themselves, developer data
  collection; revisit the answer if a developer-operated service or analytics
  is added.
- Confirm the export-compliance response matches
  `ITSAppUsesNonExemptEncryption = false` in both application targets.
  Reassess it if encryption, cryptography, or transport behavior changes.
- Resolve the Guest Console policy gate below before submitting the public
  build on any platform.
- Select only processed, platform-matching TestFlight builds after they pass
  the device and archive checks. Keep App Store release mode manual for this
  initial release on every platform.

Apple's requirements change independently of this repository. Before each
submission, verify the current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [privacy requirements](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [age-rating questionnaire](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/), and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## Guest Console policy gate

The in-app guest console mirrors and controls a Proxmox guest. Treat it as a
potential [Guideline 4.2.7 Remote Desktop Client](https://developer.apple.com/app-store/review/guidelines/)
case. That rule applies when a client mirrors specific software or services
and requires a user-owned personal-computer or dedicated-game-console host,
with host and client on a local LAN-based network. The current app's normal
network guidance supports trusted private networks and VPNs, so do not assume
that a public, remote, or VPN-only review setup satisfies the rule.

Before submitting, obtain written clarification from Apple that the submitted
console experience and review setup comply, or deliberately omit/disable the
console from every submitted platform build. The latter is a product change
that requires an explicit decision and full regression qualification. Do not
describe a public review endpoint or VPN as compliant console access unless
Apple has confirmed it. Keep the clarification and its date in the App Review
notes; it is a release blocker, not a checkbox to infer from source code.

## App Review Information

PVE Companion requires an existing Proxmox VE account, so App Review needs a
live, least-privilege review server and credentials. Place them only in App
Store Connect's **App Review Information** fields, never in this repository,
CI logs, screenshots, or issue tracker.

Use this review-note template after replacing the bracketed fields:

```text
PVE Companion connects directly to a Proxmox VE server the user administers.
It has no developer-operated account system, analytics, advertising, or cloud
relay.

Review server URL: [HTTPS review endpoint]
Realm: [Proxmox realm]
Username: [least-privilege review account]
Password or API-token secret: [enter in App Review Information]

The supplied account can view realistic datacenter, guest, node, storage, and
task data. It must remain reachable throughout review. No VPN, hardware, or
out-of-band authentication is required for the non-console experience.

Guest Console status: [Apple review clarification reference and date, or state
that the feature is omitted from the submitted platform builds]. Do not claim
that a public or VPN-only console route complies with Guideline 4.2.7 without
written confirmation from Apple.

To review the app:
1. Add the supplied server profile and sign in.
2. Open Overview, Guests, Nodes, Storage, Tasks, Incident Center, Backup
   Center, Portfolio, and Cluster Administration.
3. Only if the Guest Console status above confirms it is included and approved,
   open a non-production guest's console. Do not perform power, snapshot,
   backup, or node operations unless the review account is specifically
   authorized for the isolated test environment.
4. On iPhone or iPad, add a Home Screen widget and start Datacenter Watch to
   review the optional local Live Activity. These surfaces display aggregate
   health only.

For self-signed TLS, the test server must show the following SHA-256
certificate fingerprint for independent verification: [fingerprint].
```

If an isolated, least-privilege review environment cannot be kept safely
available, use a fully featured built-in demo mode only with Apple's prior
approval. Do not use a production server for review. A TestFlight-only build
is not an App Store submission.

## Choose delivery paths per platform

1. **iOS and iPadOS: submit the processed TestFlight build manually.** Complete
   the App Store Connect fields above, select the qualified build, attach it
   to version `1.0.0`, and submit that platform version for review. This is
   the right path when the existing build is qualified and no binary changes
   are needed.
2. **macOS: create a TestFlight build through Codemagic.** Add the protected
   `CERTIFICATE_PRIVATE_KEY` first, then push the qualified commit to `main`.
   `macos-testflight` builds and uploads the signed `.pkg`; after processing,
   select it only for the macOS version. It is separate from the iOS IPA.
3. **iOS, iPadOS, and macOS: create new App Review builds through Codemagic.**
   Complete every platform's App Store Connect fields first, then create the
   new `v1.0.0` tag only when new version-1.0.0 binaries are intended. That
   single tag starts `ios-app-store-release` and `macos-app-store-release`.
   They upload their respective IPA and `.pkg`, submit both platform versions
   to App Review, and keep manual release selected. Do not use this path merely
   to resubmit an already processed build.
4. **Local Mac fallback:** if Codemagic is unavailable, archive and validate
   `macos/Runner.xcworkspace` in Xcode Organizer, then upload it with
   **Distribute App → App Store Connect → Upload**. Do not change the
   checked-in signing settings or commit signing material to make that work.

After submission, monitor the App Review contact channel, keep the review
server reachable, and preserve the manual-release setting until the approved
version is intentionally released.
