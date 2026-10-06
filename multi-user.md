# Multi-user setup with omarchy-custom

Omarchy is single-user by default: the stock `omarchy` SDDM theme is a
password-only prompt with no user or session picker. For multiple users:

1. Install the `omarchy-custom` theme from this repo (user/session picker).
2. Create the extra Linux user(s) with the right groups and sudo.
3. Disable autologin so the greeter actually shows.

No reinstall needed. Desktop config (`~/.config/hypr/`, `~/.config/omarchy/`)
is per-user, so each user gets an independent desktop.

## 1. Clone and install the theme

```bash
git clone https://github.com/nightdevil00/omarchy-custom.git
cd omarchy-custom
./install.sh
```

What it does:

- Copies `Main.qml`, `metadata.desktop`, `theme.conf` + PNGs to
  `/usr/share/sddm/themes/omarchy-custom/` (`755` dir, `644` files, `root:root`).
- Writes `/etc/sddm.conf.d/zz-omarchy-custom-theme.conf` with
  `Current=omarchy-custom`. The `zz-` prefix sorts after `10-theme.conf` and
  `99-omarchy-login.conf`, so it wins without editing shipped files.
- Removes `/etc/sddm.conf.d/autologin.conf` (greeter would be skipped otherwise).
- Backs up anything it replaces to `/var/backups/omarchy-custom-sddm/`.

Options: `--dry-run`, `--no-enable`, `--keep-autologin` (keeps autologin,
greeter stays bypassed on boot), `-h/--help`.

Apply: takes effect on next greeter (`sudo systemctl restart sddm` logs you out).

Revert:

```bash
sudo rm /etc/sddm.conf.d/zz-omarchy-custom-theme.conf
sudo systemctl restart sddm
# falls back to Current=omarchy from 99-omarchy-login.conf
```

## 2. Add a new user

Easiest — one call does theme (§1) + user + password + sudo:

```bash
./install.sh --add-user <username> --groups wheel --sudo
```

`--groups` defaults to `wheel`; `--sudo-nopasswd` gives passwordless sudo
instead. Existing users are kept and just updated. Or manually, from your
existing admin account:

```bash
sudo useradd -m -s /usr/bin/bash <username>
sudo passwd <username>
sudo usermod -aG wheel <username>
id <username>
# expect: uid=1001(<username>) gid=1001(<username>) groups=1001(<username>),998(wheel)
```

- `-m` creates `/home/<username>` from `/etc/skel`.
- `-s /usr/bin/bash` matches the shell of existing users here.
- `wheel` is the desktop/admin group (existing users `mihai`, `admin` are both
  in `wheel`). No audio/video/storage groups needed: PipeWire, logind, and
  device access come from the systemd user session started via `uwsm`, not
  static groups.
- Account needs UID >= 1000, a password, and a valid shell, or SDDM won't list it.

## 3. Sudo (if needed)

`./install.sh --add-user <username> --sudo` handles this for you (writes and
validates `/etc/sudoers.d/<username>`). Manually, note: on this machine
`%wheel` in `/etc/sudoers` is **commented out** — sudo comes
from per-user drop-ins in `/etc/sudoers.d/` (e.g. `mihai`, `admin` contain
`<user> ALL=(ALL) NOPASSWD: ALL`). Adding someone to `wheel` alone does
**not** grant sudo. Pick one:

**Option A — per-user file (matches this machine):**

```bash
echo '<username> ALL=(ALL) ALL' | sudo tee /etc/sudoers.d/<username>
sudo chmod 440 /etc/sudoers.d/<username>
sudo visudo -c
```

Use `ALL=(ALL) NOPASSWD: ALL` instead for passwordless sudo like the existing
users — less secure, your call.

**Option B — standard Arch `%wheel` (all wheel members get sudo):**

```bash
sudo visudo
# uncomment:
# %wheel ALL=(ALL:ALL) ALL
```

Verify:

```bash
su - <username> -c 'sudo -l'
```

Graphical privilege escalation (polkit) works automatically for local SDDM
logins — no extra config.

## 4. First login

Log in graphically as the new user once, or provision manually:

```bash
su - <username>
omarchy-provision-user
```

Idempotent (rerun with `--force`). Run as the user, never as root. Sets up
agent skills symlinks, `xdg-user-dirs`, default browser, and marks
`~/.local/state/omarchy/done/finalize-user`.

## 5. Verify

```bash
ls /usr/share/sddm/themes/
cat /etc/sddm.conf.d/zz-omarchy-custom-theme.conf
ls /usr/share/wayland-sessions/   # hyprland-uwsm.desktop is the Omarchy entry
systemctl status sddm
journalctl -u sddm -e --no-pager
loginctl list-sessions
```

You should get the centered login (bigger logo, username + password) with
user and session dropdowns underneath. Log in once per user to lock in
`RememberLastUser/LastSession` (set by `99-omarchy-login.conf` — keep it).

## 6. Troubleshooting

- **Black/broken greeter:** set `Current=breeze` or `Current=omarchy` in the
  `zz-` file, `systemctl restart sddm`. If that works, the custom QML/assets
  are at fault — check `journalctl -u sddm -b | grep -iE 'fail|error|greeter'`.
- **User missing:** no password, bad shell, or UID < 1000. Test `su - <user>`
  or TTY login (`Ctrl+Alt+F2`); if that fails it's PAM/account, not SDDM.
- **Session missing:** `.desktop` must exist in `/usr/share/wayland-sessions/`,
  be world-readable, with a working `Exec=`. Try from a TTY:
  `uwsm start -e -D Hyprland hyprland.desktop`.
- **Login loops to greeter:** session command failed after auth passed. Check
  `journalctl -u sddm` after the auth line plus `journalctl --user -b -p err`.
- **Locked out of GUI:** `Ctrl+Alt+F2`, log in, fix config, `systemctl restart sddm`.
