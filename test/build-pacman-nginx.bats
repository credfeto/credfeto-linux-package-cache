#!/usr/bin/env bats
# Unit tests for build-pacman-nginx's helper functions.
#
# The real script does real work (sudo pacman, rate-mirrors, nginx -t,
# docker) as soon as it's executed, so these tests "source" it instead - a
# guard near the end of the script ("if [ "${BASH_SOURCE[0]}" = "${0}" ]")
# means sourcing loads only the function definitions, none of that
# side-effecting flow, since $0 (bats) never equals BASH_SOURCE[0] (this
# file) when sourced.
#
# Functions that read globals the real top-level flow would normally set
# (MIRROR_SPECS, MIRRORLIST_MAX_AGE_DAYS) get those set directly by each
# test instead, pointed at throwaway files under a per-test temp directory.
# shellcheck disable=SC2034 # these are read by name from the sourced
# script's functions (MIRROR_SPECS, *_MIRRORS, is_resolvable overrides),
# which shellcheck can't trace through the dynamic "source $SCRIPT" below.

bats_require_minimum_version 1.5.0

SCRIPT="$BATS_TEST_DIRNAME/../build-pacman-nginx"

setup() {
  # shellcheck source=/dev/null
  source "$SCRIPT"
  TEST_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- is_arch_url ---

@test "is_arch_url matches a well-formed arch Server line" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_arch_url 'Server = https://mirror.example.com/archlinux/$repo/os/$arch')
  [ "$result" = "mirror.example.com" ]
}

@test "is_arch_url returns empty for a chaotic-shaped line" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_arch_url 'Server = https://mirror.example.com/$repo/$arch')
  [ -z "$result" ]
}

@test "is_arch_url returns empty for an unrelated line" {
  result=$(is_arch_url 'not a server line at all')
  [ -z "$result" ]
}

# --- is_chaotic_aur_url ---

@test "is_chaotic_aur_url matches a well-formed chaotic Server line" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_chaotic_aur_url 'Server = https://mirror.example.com/$repo/$arch')
  [ "$result" = "mirror.example.com" ]
}

@test "is_chaotic_aur_url returns empty for an arch-shaped line" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_chaotic_aur_url 'Server = https://mirror.example.com/archlinux/$repo/os/$arch')
  [ -z "$result" ]
}

# --- is_cachyos_url ---

@test "is_cachyos_url captures host and prefix separately" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_cachyos_url 'Server = https://mirror.example.com/cachyos/repo/$arch/$repo')
  [ "$result" = "mirror.example.com|/cachyos/repo" ]
}

@test "is_cachyos_url returns empty for an arch-shaped line" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  result=$(is_cachyos_url 'Server = https://mirror.example.com/archlinux/$repo/os/$arch')
  [ -z "$result" ]
}

# --- is_resolvable ---

@test "is_resolvable succeeds for a host that resolves" {
  is_resolvable localhost
}

@test "is_resolvable fails for a host that cannot resolve" {
  run is_resolvable "this-host-definitely-does-not-exist.invalid"
  [ "$status" -ne 0 ]
}

# --- remove_mirror_from_array ---

@test "remove_mirror_from_array removes a plain host entry" {
  declare -a arr=("a.example.com" "b.example.com" "c.example.com")
  remove_mirror_from_array arr "b.example.com"
  [ "${#arr[@]}" -eq 2 ]
  [[ " ${arr[*]} " != *" b.example.com "* ]]
}

@test "remove_mirror_from_array matches by host part of a host|prefix entry" {
  declare -a arr=("a.example.com|/one" "b.example.com|/two")
  remove_mirror_from_array arr "b.example.com"
  [ "${#arr[@]}" -eq 1 ]
  [ "${arr[0]}" = "a.example.com|/one" ]
}

@test "remove_mirror_from_array leaves the array untouched and fails when nothing matches" {
  declare -a arr=("a.example.com")
  if remove_mirror_from_array arr "not-there.example.com"; then
    echo "expected failure, got success" >&2
    return 1
  fi
  [ "${#arr[@]}" -eq 1 ]
  [ "${arr[0]}" = "a.example.com" ]
}

# --- needs_mirrorlist_refresh ---

@test "needs_mirrorlist_refresh is true when the mirrorlist file is missing" {
  MIRRORLIST_MAX_AGE_DAYS=7
  needs_mirrorlist_refresh "$TEST_DIR/does-not-exist"
}

@test "needs_mirrorlist_refresh is true when the .ranked marker is missing" {
  MIRRORLIST_MAX_AGE_DAYS=7
  echo "mirror.example.com" > "$TEST_DIR/list"
  needs_mirrorlist_refresh "$TEST_DIR/list"
}

@test "needs_mirrorlist_refresh is false when the marker is fresh" {
  MIRRORLIST_MAX_AGE_DAYS=7
  echo "mirror.example.com" > "$TEST_DIR/list"
  touch "$TEST_DIR/list.ranked"
  run needs_mirrorlist_refresh "$TEST_DIR/list"
  [ "$status" -ne 0 ]
}

@test "needs_mirrorlist_refresh is true when the marker is older than the max age" {
  MIRRORLIST_MAX_AGE_DAYS=7
  echo "mirror.example.com" > "$TEST_DIR/list"
  touch -d "10 days ago" "$TEST_DIR/list.ranked"
  needs_mirrorlist_refresh "$TEST_DIR/list"
}

@test "needs_mirrorlist_refresh is true when the file has been pruned down to empty, even with a fresh marker" {
  # Regression test: pruning every mirror out of a list between re-ranks
  # must not be left to wait out the rest of the staleness window with
  # nothing left to load - that's the "stays broken until someone notices"
  # failure mode this mechanism exists to avoid.
  MIRRORLIST_MAX_AGE_DAYS=7
  : > "$TEST_DIR/list"
  touch "$TEST_DIR/list.ranked"
  needs_mirrorlist_refresh "$TEST_DIR/list"
}

@test "needs_mirrorlist_refresh ignores the mirrorlist file's own mtime" {
  # Regression test for the staleness-clock bug fixed in round 2 of the
  # self-heal review: prune_mirror_host rewrites the mirrorlist file, which
  # bumps its mtime, but that must not reset the re-rank clock - only a
  # real re-rank (which touches the separate .ranked marker) should.
  MIRRORLIST_MAX_AGE_DAYS=7
  touch -d "10 days ago" "$TEST_DIR/list.ranked"
  echo "mirror.example.com" > "$TEST_DIR/list"
  needs_mirrorlist_refresh "$TEST_DIR/list"
}

# --- prune_mirror_host ---

@test "prune_mirror_host empties the file when pruning its last remaining mirror" {
  # Regression test: grep -v exits 1 (not 0) when the pruned host was the
  # file's only line, since it then has zero surviving lines to print. An
  # earlier "grep -vF ... && mv ..." skipped the mv whenever that happened,
  # silently leaving the dead mirror in the file.
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  echo 'Server = https://only.example.com/archlinux/$repo/os/$arch' > "$TEST_DIR/arch"
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|TEST_ARR")
  declare -a TEST_ARR=("only.example.com")

  prune_mirror_host "only.example.com"

  [ ! -s "$TEST_DIR/arch" ]
  [ "${#TEST_ARR[@]}" -eq 0 ]
}

@test "prune_mirror_host removes the host from its mirrorlist file and array" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  printf 'Server = https://bad.example.com/archlinux/$repo/os/$arch\nServer = https://good.example.com/archlinux/$repo/os/$arch\n' > "$TEST_DIR/arch"
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|TEST_ARR")
  declare -a TEST_ARR=("bad.example.com" "good.example.com")

  prune_mirror_host "bad.example.com"

  run ! grep -q "bad.example.com" "$TEST_DIR/arch"
  grep -q "good.example.com" "$TEST_DIR/arch"
  [ "${#TEST_ARR[@]}" -eq 1 ]
  [ "${TEST_ARR[0]}" = "good.example.com" ]
}

@test "prune_mirror_host does not remove an unrelated mirror whose name contains the pruned host as a substring" {
  # Regression test: prune_mirror_host used to grep for the bare host, which
  # matches anywhere in the line - pruning mirror1.example.com would also
  # strip an unrelated sub.mirror1.example.com line. Matching on
  # "://host/" (the URL's own host boundaries) fixes that.
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  printf 'Server = https://mirror1.example.com/archlinux/$repo/os/$arch\nServer = https://sub.mirror1.example.com/archlinux/$repo/os/$arch\n' > "$TEST_DIR/arch"
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|TEST_ARR")
  declare -a TEST_ARR=("mirror1.example.com" "sub.mirror1.example.com")

  prune_mirror_host "mirror1.example.com"

  run ! grep -q "://mirror1.example.com/" "$TEST_DIR/arch"
  grep -q "sub.mirror1.example.com" "$TEST_DIR/arch"
  [ "${#TEST_ARR[@]}" -eq 1 ]
  [ "${TEST_ARR[0]}" = "sub.mirror1.example.com" ]
}

@test "prune_mirror_host returns failure for a host that is not known" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  echo 'Server = https://good.example.com/archlinux/$repo/os/$arch' > "$TEST_DIR/arch"
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|TEST_ARR")
  declare -a TEST_ARR=("good.example.com")

  run prune_mirror_host "unknown.example.com"
  [ "$status" -ne 0 ]
}

@test "prune_mirror_host checks every list in MIRROR_SPECS, not just one" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  echo 'Server = https://shared.example.com/archlinux/$repo/os/$arch' > "$TEST_DIR/arch"
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  echo 'Server = https://shared.example.com/$repo/$arch' > "$TEST_DIR/chaotic"
  MIRROR_SPECS=(
    "$TEST_DIR/arch|Arch|arch|is_arch_url|ARR_A"
    "$TEST_DIR/chaotic|Chaotic AUR|chaotic-aur|is_chaotic_aur_url|ARR_B"
  )
  declare -a ARR_A=("shared.example.com")
  declare -a ARR_B=("shared.example.com")

  prune_mirror_host "shared.example.com"

  run ! grep -q "shared.example.com" "$TEST_DIR/arch"
  run ! grep -q "shared.example.com" "$TEST_DIR/chaotic"
}

# --- load_mirrors ---

@test "load_mirrors loads resolvable mirrors and skips+prunes unresolvable ones" {
  cat > "$TEST_DIR/arch" <<'LIST'
Server = https://good.example.com/archlinux/$repo/os/$arch
Server = https://bad.example.com/archlinux/$repo/os/$arch
LIST
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|LOADED")

  # Deterministic stand-in for the real DNS check, so this test doesn't
  # depend on live network/resolver behaviour. Invoked indirectly by
  # load_mirrors below, not called directly from this test body.
  # shellcheck disable=SC2329
  is_resolvable() { [[ "$1" != *bad* ]]; }

  declare -a LOADED=()
  load_mirrors is_arch_url "$TEST_DIR/arch" LOADED

  [ "${#LOADED[@]}" -eq 1 ]
  [ "${LOADED[0]}" = "good.example.com" ]
  run ! grep -q "bad.example.com" "$TEST_DIR/arch"
}

@test "load_mirrors ignores blank lines and lines that don't match" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  printf '\nServer = https://good.example.com/archlinux/$repo/os/$arch\nnot a server line\n' > "$TEST_DIR/arch"
  MIRROR_SPECS=("$TEST_DIR/arch|Arch|arch|is_arch_url|LOADED")
  # shellcheck disable=SC2329 # invoked indirectly by load_mirrors below
  is_resolvable() { return 0; }

  declare -a LOADED=()
  load_mirrors is_arch_url "$TEST_DIR/arch" LOADED

  [ "${#LOADED[@]}" -eq 1 ]
}

@test "load_mirrors resolves the bare host, not host|prefix, for CachyOS entries" {
  # shellcheck disable=SC2016 # $repo/$arch are literal pacman.conf tokens, not shell variables
  echo 'Server = https://good.example.com/cachyos/repo/$arch/$repo' > "$TEST_DIR/cachyos"
  MIRROR_SPECS=("$TEST_DIR/cachyos|CachyOS|cachyos|is_cachyos_url|LOADED")

  # Fails the test if is_resolvable is ever asked about a "host|prefix"
  # string instead of the bare host. Invoked indirectly by load_mirrors.
  # shellcheck disable=SC2329
  is_resolvable() { [[ "$1" != *"|"* ]]; }

  declare -a LOADED=()
  load_mirrors is_cachyos_url "$TEST_DIR/cachyos" LOADED

  [ "${#LOADED[@]}" -eq 1 ]
  [ "${LOADED[0]}" = "good.example.com|/cachyos/repo" ]
}

# --- info / success / die ---

@test "info writes its message" {
  run info "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"hello"* ]]
}

@test "success writes its message" {
  run success "done"
  [ "$status" -eq 0 ]
  [[ "$output" == *"done"* ]]
}

@test "die writes its message and exits non-zero" {
  run die "boom"
  [ "$status" -eq 1 ]
  [[ "$output" == *"boom"* ]]
}
