# credfeto-linux-package-cache

docker compose for linux package cache for arch linux and flathub

Pacman Repos:

* core
* extra
* multilib
* chaotic-aur

Flatpak repos

* Flathub

## Server Setup

```bash
git clone https://github.com/credfeto/credfeto-linux-package-cache.git
sudo mkdir /cache
cd credfeto-linux-package-cache

./update
```

Additional recommended install

* Add firewall rules to allow the following TCP Ports
  * 8888 (plain) - for pacman repos, served directly by the nginx that `build-pacman-nginx` generates
  * 8776 (plain) - for flathub, served directly by the same nginx
  * 7777 (TLS) - shared by both pacman.local and flathub.local via SNI
* Use NGINX or another front end proxy to resolve more friendly urls and TLS e.g:
  * `https://pacman.example.com` points to ``https://<server>:7777`` (SNI: pacman.local)
  * `https://flathub.example.com` points to ``https://<server>:7777`` (SNI: flathub.local)

### Watchtower update schedule

The `cache-watchtower` service checks for updated container images on a cron schedule set by
`WATCHTOWER_SCHEDULE`. The default is `0 42 * * * *`, which runs at 42 minutes past every hour.

Watchtower uses a 6-field cron expression with seconds first: `second minute hour day-of-month month day-of-week`.

To override the schedule, create a `.env` file next to `docker-compose.yml` containing, for example:

```bash
WATCHTOWER_SCHEDULE=0 15 3 * * *
```

Old images are removed after a container is updated, because `WATCHTOWER_CLEANUP` is enabled.

## Client Setup

### pacman.conf

```ini
[core]
Server = https://pacman.example.com/repo/archlinux/$repo/os/$arch

[extra]
Server = https://pacman.example.com/repo/archlinux/$repo/os/$arch

[multilib]
Server = https://pacman.example.com/repo/archlinux/$repo/os/$arch


[chaotic-aur]
Server = https://pacman.example.com/repo/chaotic-aur/x86_64
```

note: could keep the existing include references and use CacheServer instead so it uses the Included mirrorlist as a
fallback to the cache:

```ini
[core]
Include = /etc/pacman.d/mirrorlist
CacheServer = https://pacman.example.com/repo/archlinux/$repo/os/$arch

[extra]
Include = /etc/pacman.d/mirrorlist
CacheServer = https://pacman.example.com/repo/archlinux/$repo/os/$arch

[multilib]
Include = /etc/pacman.d/mirrorlist
CacheServer = https://pacman.example.com/repo/archlinux/$repo/os/$arch


[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
CacheServer = https://pacman.example.com/repo/chaotic-aur/x86_64
```

### flatpak

```bash
sudo flatpak remote-modify --url=https://flathub.example.com/repo/ flathub-verified
```
