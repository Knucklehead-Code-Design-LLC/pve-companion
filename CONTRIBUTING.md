# Contributing to PVE Companion

Thanks for helping make PVE Companion a reliable independent Proxmox VE
client. By contributing, you agree that your contributions are licensed under
the repository's Apache-2.0 license.

## Before opening a pull request

1. Keep a change inside its owning feature. Do not add catch-all `helpers`,
   `common`, or `utils` files.
2. Preserve the dependency direction: widget → controller → repository →
   platform/HTTP adapter.
3. Add observable tests at the cheapest reliable layer. Authentication,
   persistence, response decoding, async/stale-response behavior, and
   destructive boundaries need focused coverage.
4. Run:

   ```sh
   flutter pub get
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   ```

5. For Apple-specific changes, also run the local unsigned builds in
   [the release guide](docs/release/apple-builds.md).

## Security and dependency rules

- Never commit a real server URL, IP address, hostname, credential, API token,
  ticket, CSRF token, certificate, provisioning profile, or signing artifact.
- Do not test against another person's server. Use fixtures, a disposable local
  environment, or a server you are authorized to operate.
- Keep direct dependencies minimal. A new dependency needs a documented reason
  in `docs/architecture/architecture.md`, a security/license review, and a
  demonstrated need that Flutter/Dart SDK facilities cannot meet.
- Do not import code, assets, or generated models from Proxmox projects without
  updating the clean-room licensing ADR and obtaining a maintainer review.

## Pull requests

Use a focused title and explain user-facing behavior, security impact, tests,
and any API/version assumptions. Avoid drive-by refactors in a feature change.
All GitHub Actions checks run on Ubuntu by design; they do not replace local
macOS/iOS validation.
