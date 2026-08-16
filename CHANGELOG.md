# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
Please ADD ALL Changes to the UNRELEASED SECTION and not a specific release
-->

## [Unreleased]
### Security
### Added
- Added .ai-instructions and ai/local/index.md from cs-template standard
### Fixed
- Fixed missing trailing newline in firewall script
- Fixed typo in credfeto-linux-package-cache.service WorkingDirectory (credfeto-linx-package-cache -> credfeto-linux-package-cache) that caused the systemd timer to fail at CHDIR on every scheduled run, silently preventing nginx mirror config regeneration
- Fixed two latent bugs in build-pacman-nginx found while touching the file: an unescaped $uri in the chaotic-aur demo rewrite was being expanded by bash to nothing (silently generating a broken nginx rewrite), and the mirror-count summary lines printed the wrong values (missing array index, and a literal unexpanded variable name)
- Fixed CachyOS mirror detection in build-pacman-nginx so nginx config regeneration no longer fails, and made zero CachyOS mirrors non-fatal so it can no longer block Arch/Chaotic-AUR/pacman/flathub updates
- Fixed build-pacman-nginx generating an nginx config that always failed nginx -t: proxy_cache_valid's time argument does not support variables, so the pkg/flathub cache-time maps introduced by the direct-TLS feature never validated. Replaced with per-content-type location blocks using literal cache times
### Changed
- Re-enabled TLS on nginx's pacman.local (8889) and flathub.local (8777) vhosts using the already-generated local certs, gave immutable package/object files (.pkg.tar.zst, .sig, .filez, /repo/deltas/) a 60-day proxy cache lifetime instead of the blanket 24h default, added matching firewall rules, and made /ping respond identically to /health so it can serve as the Traefik health-check path directly against nginx
- Moved pacman.local and flathub.local TLS back onto a single shared port (7777, matching what cache-proxy used to serve both on), distinguished by SNI instead of splitting them onto separate ports (8889/8777); no Traefik change is needed since it already points both pacman-service and flathub-service at port 7777
- Standardised build-pacman-nginx on the die/success/info shell output convention (colourised, die writes to stderr and now reliably reports failure via exit status)
### Deprecated
### Removed
- Removed dead pacoloco.yaml config, cache-pacoloco docker volume, and unused arch-pkgs cache directory, since pacoloco was never actually wired into docker-compose.yml (pacman caching is handled by cache-proxy plus the host nginx from build-pacman-nginx)
- Removed cache-proxy: the docker-compose service, its external cache-proxy volume, proxy-appsettings.json, PROXY_USER/proxy.local cert generation, the /cache/proxy directory setup, the LOCAL_IP/.env templating step it was the only consumer of, and its port 7777/7878 firewall rules. Traffic for pacman.markridgwell.com and flathub.markridgwell.com now goes straight to nginx (see the Changed entry above); AUR is unaffected, it uses the separate cache-aur app
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created