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
- bats unit tests (tests/build-pacman-nginx.bats) covering every helper function in build-pacman-nginx, including the mirror self-heal functions added in prior entries; build-pacman-nginx now guards its side-effecting main flow (sudo, rate-mirrors, nginx -t, docker) behind a BASH_SOURCE-vs-$0 check so it can be sourced for testing without running any of it
### Fixed
- Fixed missing trailing newline in firewall script
- Fixed typo in credfeto-linux-package-cache.service WorkingDirectory (credfeto-linx-package-cache -> credfeto-linux-package-cache) that caused the systemd timer to fail at CHDIR on every scheduled run, silently preventing nginx mirror config regeneration
- Fixed two latent bugs in build-pacman-nginx found while touching the file: an unescaped $uri in the chaotic-aur demo rewrite was being expanded by bash to nothing (silently generating a broken nginx rewrite), and the mirror-count summary lines printed the wrong values (missing array index, and a literal unexpanded variable name)
- Fixed CachyOS mirror detection in build-pacman-nginx so nginx config regeneration no longer fails, and made zero CachyOS mirrors non-fatal so it can no longer block Arch/Chaotic-AUR/pacman/flathub updates
- Fixed build-pacman-nginx generating an nginx config that always failed nginx -t: proxy_cache_valid's time argument does not support variables, so the pkg/flathub cache-time maps introduced by the direct-TLS feature never validated. Replaced with per-content-type location blocks using literal cache times
- systemd unit for credfeto-linux-package-cache ran as User=markr with paths under /home/markr, but the repo is deployed at /root/credfeto-linux-package-cache on the hosts, causing flock to fail at CHDIR with Permission denied; unit now runs as User=root against /root/credfeto-linux-package-cache
- build-pacman-nginx only ever ranked pacman/chaotic-aur/CachyOS mirrors once at first bootstrap and never re-checked them, so a mirror that later went offline or lost DNS stayed baked into the generated nginx config forever, causing nginx -t to fail with host not found in upstream and blocking every future config regeneration until someone manually cleared the stale mirrorlist file; mirrors are now DNS-checked before use, a dead mirror named by a failed nginx -t is automatically pruned and the config regenerated and retested, and each mirror list is now fully re-ranked via rate-mirrors on a weekly cadence instead of only once
- prune_mirror_host silently failed to remove a dead mirror from its mirrorlist file whenever that mirror was the file's last remaining line: grep -v exits 1 (not 0) when it has zero surviving lines to print, and the previous 'grep -vF ... && mv ...' skipped the mv on that exit code, leaving the dead mirror in place indefinitely
- remove_mirror_from_array's internal nameref parameter was named arr, so calling it with an array itself named arr failed with bash's circular name reference error; renamed to a name a caller's own array is not realistically going to collide with (load_mirrors' equivalent internal parameter renamed to match)
- is_resolvable pruned a mirror on a single failed DNS lookup, so one transient resolver hiccup was enough to condemn an otherwise-healthy mirror until the next weekly re-rank; now retries a couple of times before giving up
- prune_mirror_host matched the bare hostname anywhere in a mirrorlist line, so pruning a dead mirror could also strip an unrelated healthy mirror whose name contained it as a substring (e.g. pruning mirror1.example.com also removed sub.mirror1.example.com); now matches on the URL's own host boundaries
- a mirrorlist pruned down to zero entries between re-ranks stayed stuck (marker still fresh, nothing to load) instead of triggering an early re-rank, reproducing the same stuck-until-manual-intervention failure this whole self-heal mechanism exists to prevent; needs_mirrorlist_refresh now also treats an empty mirrorlist file as due for refresh
- the nginx -t retry loop could exhaust its attempts on a config nginx keeps rejecting for a different reason each time (or die with a confusing 'not a recognised dead-mirror error' if pruning emptied a mandatory mirror array), and only the last attempt's nginx -t output was kept in the log; raised the retry cap, added an explicit failure when pruning empties the Arch or Chaotic AUR mirror list, and every attempt's output is now appended to the log instead of overwriting it
- update did not check build-pacman-nginx's exit status, so a failure there (including one that had already mutated mirrorlist state) still let update proceed to bring containers up against a stale nginx.conf with no visible failure
- mirrorlists/.gitignore only covered the arch and chaotic mirrorlist files, not the pre-existing cachyos one or the new .ranked marker files, leaving them as untracked artefacts one careless git add away from an unrelated commit
- Normalised missing end-of-file newlines and trailing whitespace across container/support files, and removed the unused PROG variable from the install script (shellcheck SC2034), so the pre-commit baseline passes cleanly
- Corrected 'Not defiled' typo to 'Not defined' in certs/generate error messages
- Cache serves chaotic-aur content again: the *.chaotic.cx mirror fleet became redirect-only (303 to third-party mirrors), which the generated nginx config relayed to clients instead of following, so nothing chaotic was cached and Server=-only clients without direct egress failed; per-mirror server blocks (arch, chaotic-aur and cachyos) now follow upstream redirects server-side, and the chaotic front-end locations retry the next mirror on upstream 5xx responses
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