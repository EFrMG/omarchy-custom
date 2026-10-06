#!/usr/bin/env bash
# install omarchy-custom SDDM theme and enable it.
# Repo: https://github.com/nightdevil00/omarchy-custom
# Usage (from a git clone):
#   git clone https://github.com/nightdevil00/omarchy-custom.git
#   cd omarchy-custom
#   ./install.sh [--dry-run] [--no-enable] [--keep-autologin] [-h|--help]
# Works regardless of where the repo is cloned: theme sources are resolved
# relative to this script (repo root) with fallback to ./omarchy-custom/
# for checkouts where the theme lives in a subdirectory.
set -euo pipefail
IFS=$'\n\t'

readonly PROG=${0##*/}
readonly THEME="omarchy-custom"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Theme sources: repo root (git clone layout) or ./omarchy-custom/ subdir
# (parent-checkout layout, e.g. ~/custom with omarchy-custom/ inside).
if [[ -f "$SCRIPT_DIR/Main.qml" ]]; then
  readonly SRC_DIR="$SCRIPT_DIR"
elif [[ -f "$SCRIPT_DIR/$THEME/Main.qml" ]]; then
  readonly SRC_DIR="$SCRIPT_DIR/$THEME"
else
  printf '[%s] ERROR: cannot find Main.qml in %s or %s/%s (run from git clone root)\n' \
    "${0##*/}" "$SCRIPT_DIR" "$SCRIPT_DIR" "$THEME" >&2
  exit 1
fi
readonly DEST_DIR="/usr/share/sddm/themes/${THEME}"
# Must sort AFTER 99-omarchy-login.conf (SDDM merges drop-ins lexically,
# later wins). zz- prefix guarantees that; 20- would silently lose.
readonly CONF_FILE="/etc/sddm.conf.d/zz-omarchy-custom-theme.conf"
readonly AUTOLOGIN_CONF="/etc/sddm.conf.d/autologin.conf"
# SDDM loads EVERY file in /etc/sddm.conf.d (not just *.conf), so backups
# must live outside that dir or a stale autologin.conf.bak would re-enable
# autologin. Same reason theme backups don't go next to the theme dir
# (they'd show up as phantom themes).
readonly BACKUP_ROOT="/var/backups/omarchy-custom-sddm"
readonly TS="$(date +%s)"

log() { printf '[%s] %s\n' "$PROG" "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

DRY_RUN=0
ENABLE=1
KEEP_AUTOLOGIN=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run) DRY_RUN=1; shift ;;
    --no-enable) ENABLE=0; shift ;;
    --keep-autologin) KEEP_AUTOLOGIN=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    --) shift; break ;;
    -*) die "unknown flag: $1" ;;
    *) break ;;
  esac
done

for f in Main.qml metadata.desktop theme.conf; do
  [[ -f "$SRC_DIR/$f" ]] || die "missing source file: $SRC_DIR/$f"
done

if command -v qmllint >/dev/null 2>&1; then
  if ! qmllint "$SRC_DIR/Main.qml"; then
    die "qmllint failed on Main.qml"
  fi
else
  log "qmllint not found, skipping QML lint"
fi

run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n' >&2
  else
    "$@"
  fi
}

log "installing $THEME -> $DEST_DIR"
run sudo mkdir -p -- "$DEST_DIR" "$BACKUP_ROOT"

if sudo test -e "$DEST_DIR/Main.qml"; then
  backup="$BACKUP_ROOT/${THEME}.bak.$TS"
  log "backing up existing theme to $backup"
  run sudo cp -a -- "$DEST_DIR" "$backup"
fi

run sudo cp -a -- "$SRC_DIR/Main.qml" "$SRC_DIR/metadata.desktop" "$SRC_DIR/theme.conf" "$DEST_DIR/"
for img in bullet.png entry.png entry-failed.png lock.png lock-failed.png logo.png; do
  if [[ -f "$SRC_DIR/$img" ]]; then
    run sudo cp -a -- "$SRC_DIR/$img" "$DEST_DIR/"
  fi
done
run sudo chmod 755 -- "$DEST_DIR"
run sudo chmod 644 -- "$DEST_DIR/Main.qml" "$DEST_DIR/metadata.desktop" "$DEST_DIR/theme.conf"
run sudo chown -R root:root -- "$DEST_DIR"

if [[ $ENABLE -eq 1 ]]; then
  log "enabling theme in $CONF_FILE"
  if sudo test -f "$CONF_FILE"; then
    run sudo cp -a -- "$CONF_FILE" "$BACKUP_ROOT/zz-omarchy-custom-theme.conf.bak.$TS"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '+ sudo tee %s (contents: [Theme] Current=%s)\n' "$CONF_FILE" "$THEME" >&2
  else
    printf '[Theme]\nCurrent=%s\n' "$THEME" | sudo tee "$CONF_FILE" >/dev/null
  fi
fi

log "verifying"
run ls -l -- "$DEST_DIR"
if [[ $ENABLE -eq 1 ]]; then
  run cat -- "$CONF_FILE"
fi

if [[ $KEEP_AUTOLOGIN -eq 0 ]]; then
  if sudo test -f "$AUTOLOGIN_CONF"; then
    backup_autologin="$BACKUP_ROOT/autologin.conf.bak.$TS"
    log "autologin found, disabling: backup to $backup_autologin then remove $AUTOLOGIN_CONF"
    run sudo cp -a -- "$AUTOLOGIN_CONF" "$backup_autologin"
    run sudo rm -f -- "$AUTOLOGIN_CONF"
  else
    log "no autologin file at $AUTOLOGIN_CONF, nothing to disable"
  fi
else
  log "keeping autologin (--keep-autologin), greeter will still be bypassed on boot"
fi

log "done. Takes effect on next SDDM greeter (logout/reboot)."
log "To test now (logs you out): sudo systemctl restart sddm"
