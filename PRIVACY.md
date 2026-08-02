# PVE Companion privacy policy

Effective August 1, 2026

PVE Companion is an open-source client that connects directly from your Apple
device to Proxmox VE servers that you configure. Knucklehead Code Design LLC
does not operate a relay, account service, analytics service, advertising
service, or telemetry backend for the app.

## Data the developer collects

The developer does not collect data from PVE Companion. The app contains no
advertising, analytics, tracking, crash-reporting, or third-party login SDKs.
It does not sell or share personal information and does not track you across
apps or websites.

## Data stored on your device

PVE Companion stores server profile metadata, such as a profile name, server
URL, username, realm, and certificate fingerprint, in platform preferences on
your device. If you choose **Remember credentials**, the password or API token
secret is stored in Apple Keychain. Password-session tickets and CSRF values
remain in memory for the current app session.

When the app receives a datacenter snapshot, it stores a sanitized aggregate
summary in an Apple App Group shared only with the PVE Companion widget
extension. The summary contains a health state and counts for issues, online
nodes, running guests, and tasks, plus current aggregate CPU, memory, and
root-disk utilization percentages. It does not contain
the server URL, hostname, IP address, username, password, token secret,
authentication ticket, CSRF token, or guest and node names.

Home Screen and Lock Screen widgets display the last stored summary. If you
explicitly start a four-hour Datacenter Watch, Apple may display the same
aggregate information as a Live Activity on the Lock Screen, in the Dynamic
Island on supported iPhones, and in other system locations Apple supports.
Visible system surfaces can be seen by someone with physical access to your
device. Datacenter Watch can be ended from the app.

You can remove stored profile metadata and its associated Keychain credential
by deleting the server profile in the app. Deleting the app also removes its
app container; Keychain behavior is controlled by Apple and the operating
system.

## Direct communication with your server

Cluster, node, guest, storage, task, and authentication data travels directly
between your device and the Proxmox VE endpoint you configure. The developer
does not receive that traffic. Your Proxmox administrator's policies govern
data held by that server.

Use HTTPS over a trusted private network or VPN. Do not expose the Proxmox
management port directly to the public internet.

## Apple services and support

Apple may process App Store, TestFlight, purchase, and diagnostic information
under Apple's own terms and privacy policy. If you voluntarily send a GitHub
issue, support request, crash log, or screenshot, the information you choose
to include is processed by the service you use and may be visible to the
project maintainers. Never include credentials, authentication tickets,
private keys, private hostnames, or IP addresses in a public issue.

For a privacy question or request, use the project's
[GitHub support page](https://github.com/Knucklehead-Code-Design-LLC/pve-companion/issues).
For a security-sensitive report, use GitHub's private vulnerability reporting
flow from the repository's **Security** tab.

## Changes

Material changes will be published in this file and will update the effective
date above. Because the project is open source, the exact application behavior
and privacy declarations can also be reviewed in this repository.
