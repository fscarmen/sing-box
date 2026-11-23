# Vendored official Xray installer

Source: https://github.com/XTLS/Xray-install
Pinned commit: b0d349e9c6234e8fa1b0d50ca9a29ce54452918f (2026-10-23)
Imported: 2026-10-27. License: GPL-3.0; retained in LICENSE.
`install-release.sh` is unchanged; SHA256 is recorded in SOURCE.json.
`xray-user.conf` and this README are integration additions.

The dashboard verifies an explicitly versioned official release ZIP and invokes
this script with `install --local ... --without-geodata --without-logfiles
--no-update-service --manually-restart-later`. A validated Reality configuration
and a project-owned non-root systemd unit are prepared first, because the
upstream installer may start a new service even with manual-restart requested.
The script installs the core and dedicated account; this project supplies the
node configuration, firewall persistence, monitoring, client exports and rollback.
No upstream removal or floating latest-install operation is exposed by the GUI.
