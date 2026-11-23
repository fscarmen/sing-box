Dashboard source imported from the sibling vps-dashboard project, upstream
https://github.com/Shimmersss/vps-dashboard, initially at commit
2d5fb74 (Panel v2.1), updated on 2026-10-27 to
e1ccdc5168ba53c37eeffc06e7c09764fe99ab01 (Panel v2.5.0), then updated on 2026-11-23 to
c435914 (Panel v2.5.3).
The original panel, tests, Vue application and static
resources are retained and extended here for this fork's local management mode.
The original project is left unchanged. ip2region's license remains in
panel/vendor/ip2region/LICENSE.md. Geolocation databases are optional and are
not included. Management mode does not configure an ESA origin gate.

The upstream main branch history was rewritten; this integration uses the
recorded source versions rather than replacing this fork's checkout. Xray
monitoring, per-user/outbound ledgers, protocol-aware bans, media probes and
optional public reachability checks are incorporated. This fork keeps its
sing-box installer, management authorization, fixed subscriptions, recovery CLI
and service names. Upstream SSH deployment/publishing scripts are not used.
Upstream deploy profiles under deploy/ are reference examples, not bootstrap
service definitions; see ../docs/XRAY-MONITOR.md for this fork's settings.

Managed Xray deployment additionally vendors the official XTLS/Xray-install
script at b0d349e9c6234e8fa1b0d50ca9a29ce54452918f, unmodified under GPL-3.0.
Its separate license, source pin and checksum are kept in vendor/xray-install/.
This fork supplies the Reality configuration, management jobs, client exports,
non-root unit and firewall integration; see ../docs/XRAY-DEPLOY.md.
