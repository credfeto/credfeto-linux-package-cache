# credfeto-linux-package-cache

docker compose for linux package cache for arch linux and flathub

Pacman Repos:
* core
* extra
* multilib
* chaotic-aur

Flatpak repos
* Flathub

AUR
* note this is an experimental cache/proxy, and still hits the aur RPC to get package metadata

## Server Setup

```bash
git clone https://github.com/credfeto/credfeto-linux-package-cache.git
sudo mkdir /cache
cd credfeto-linux-package-cache

./update
```

Additional recommended install
* Add firewall rules to allow the following TCP Ports
  - 7878 - for pacman repos
  - 7777 - for flathub
  - 7776 - for aur
* Use NGINX or front end other front end proxy to resolve more friendly urls and TLS e.g:
  - https://pacman.example.com points to ``http://<server>:7878``
  - https://flathub.example.com points to ``http://<server>:7777``
  - https://aur.example.com points to ``http://<server>:7776``

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

### AUR (Yay)

Copy the following into ~/.config/yay/config.json adjusting hostnames as appropriate 

```json
{
    "aururl": "https://aur.example.com/repos",
    "aurrpcurl": "https://aur.example.com/rpc?"
}

```

### flatpak

```bash
sudo flatpak remote-modify --url=https://flathub.example.com/repo/ flathub-verified
```





