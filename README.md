# omarchy-custom

SDDM theme cloned from Omarchy, with user list (left) and session list (right).

Repo: https://github.com/nightdevil00/omarchy-custom

## Install from git

```bash
git clone https://github.com/nightdevil00/omarchy-custom.git
cd omarchy-custom
./install.sh
```

Options:

- `--dry-run` — print what would be done
- `--no-enable` — copy files but don't write `/etc/sddm.conf.d/zz-omarchy-custom-theme.conf`
- `--keep-autologin` — don't remove `/etc/sddm.conf.d/autologin.conf`
- `-h, --help` — usage

The script resolves theme sources relative to itself, so it works from any
clone path. Existing installs are backed up to `/var/backups/omarchy-custom-sddm/`.

Takes effect on next SDDM greeter (logout/reboot). Test now (logs you out):

```bash
sudo systemctl restart sddm
```
