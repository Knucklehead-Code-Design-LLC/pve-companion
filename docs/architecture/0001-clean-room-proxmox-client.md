# ADR 0001: Use a clean-room Proxmox VE API client

- Status: accepted
- Date: 2026-08-01

## Context

The official Flutter frontend is published at
[`pve_flutter_frontend`](https://git.proxmox.com/git/pve_flutter_frontend.git).
Proxmox publicly describes its source as primarily
[GNU AGPLv3](https://www.proxmox.com/en/about/open-source/developers), and its
official documentation describes an API intended for client integrations.

The upstream Flutter project and its related Dart packages (including the
official `proxmox_dart_api_client` work visible in Proxmox's public developer
mailing list) would offer prebuilt protocol and UI behavior. A derivative
would need a complete source, copyright, and dependency audit before any code
was copied, linked, or adapted; it would also require AGPL-compatible licensing
and attribution obligations.

During this initial implementation, direct HTTPS and Git access to
`git.proxmox.com` timed out from the build environment. The official source
was therefore **not cloned or used**, and no substitute GitHub fork was used as
an authority. The decision deliberately avoids inferring a license from an
unofficial mirror. Public official licensing and development material was used
only to determine that importing the official source was not necessary for a
first milestone.

## Decision

PVE Companion is a new, clean-room Flutter application that calls the
documented Proxmox VE HTTP API. It contains no copied source, generated models,
assets, package dependencies, UI strings, or branding from the official
frontend or its Dart packages.

It is licensed under Apache-2.0. This decision is limited to the source in this
repository and is not legal advice. The product includes a clear independent,
unaffiliated trademark disclaimer and uses a Knucklehead-owned application ID:
`com.knuckleheadcodedesign.pvecompanion`.

## Consequences

- The first milestone can focus on Apple platforms, adaptive UI, direct typed
  transport behavior, and a minimal dependency graph.
- API coverage grows incrementally from strict request/response behavior and
  tested fixtures rather than from a copied frontend.
- The team must not import any Proxmox frontend/Dart source later without a
  fresh legal review. If a future change is derivative of AGPL code, the
  licensing, notices, source availability, and attribution must be changed to
  comply before release.
- Documentation should continue to call the product an independent Proxmox VE
  client and must not imply official endorsement.

## Rejected alternative

An AGPL-derived frontend could eventually speed up parity, but it would not be
materially better for this initial Apple-first utility. It would couple the
project to upstream source/layout decisions, increase compliance work, and
provide no clear benefit over a small direct REST client for the implemented
features.
