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
### Changed
### Deprecated
### Removed
- Removed dead pacoloco.yaml config, cache-pacoloco docker volume, and unused arch-pkgs cache directory, since pacoloco was never actually wired into docker-compose.yml (pacman caching is handled by cache-proxy plus the host nginx from build-pacman-nginx)
### Deployment Changes
<!--
Releases that have at least been deployed to staging, BUT NOT necessarily released to live.  Changes should be moved from [Unreleased] into here as they are merged into the appropriate release branch
-->
## [0.0.0] - Project created