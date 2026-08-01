# Security policy

## Supported baseline

Security fixes are applied to the current `main` branch. This pre-1.0 project
does not make compatibility promises for old builds.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do
not open a public issue for a vulnerability involving authentication, TLS,
certificate pinning, credential storage, or Proxmox API authorization.

Include a minimal reproduction, affected platform/version, impact, and safe
redacted logs. Never include a production URL, IP address, hostname, password,
API token, session ticket, CSRF token, certificate private key, provisioning
profile, or signing artifact.

Maintainers will acknowledge a report, assess scope, coordinate a fix, and
publish a disclosure when users can safely update.

## Security expectations

- PVE management should be reached through HTTPS and a trusted private network
  or VPN; PVE Companion does not make a public port-forward safe.
- Certificate trust must remain explicit, per server, host, and port.
- Credential secrets must remain outside preference JSON and logs.
- New power or destructive operations require clear confirmation and tests.
