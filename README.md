# Omarchy Plasma Hybrid

The Omarchy shell and theme experience on top of KDE Plasma's fluid window
management. It keeps the distinctive Omarchy bar, menus, indicators, Agents,
Task Manager, Wi-Fi, audio, weather, and theme switching while using KWin for
window tasks, minimization, virtual desktops, effects, and overview.

This is an unofficial community integration. It does not replace or modify
files owned by the Omarchy package.

## Features

- Bottom Omarchy Quickshell bar in a Plasma session
- KWin-aware window task buttons with click-to-minimize behavior
- Plasma virtual desktop switcher and KRunner shortcut
- Omarchy application and agent menus
- Omarchy Agents usage panel and the `omatask` system monitor
- Omarchy palette and wallpaper synchronization into Plasma
- Separate Plasma shell configuration, leaving Hyprland untouched
- Optional minimal Omarchy SDDM login screen that selects Plasma
- Timestamped backups, diagnostics, and rollback

## Requirements

- A current Omarchy installation
- KDE Plasma 6 and KWin
- Quickshell (`qs`), `qdbus6`, `jq`, `perl`, and `patch`
- `plasma-apply-colorscheme`

The first tested combination is Omarchy `4.0.0.r1836.g0ae1694-1`, Plasma
`6.7.4`, and Quickshell `0.3.1`. Omarchy development snapshots may change the
shell APIs; run `./doctor.sh` after upgrading.

## Install

On a fresh Omarchy installation, clone the project and let it install Plasma
and the required Arch packages:

```bash
git clone https://github.com/Wizmo-inc/omarchy-plasma-hybrid.git
cd omarchy-plasma-hybrid
./install.sh --install-deps --replace-panel
```

If Plasma is already installed, omit `--install-deps`.

`--replace-panel` removes existing Plasma panels after backing up the Plasma
layout. Omit it to keep those panels alongside the Omarchy bar.

To also install the minimal Omarchy login screen and disable SDDM autologin:

```bash
./install.sh --replace-panel --with-sddm
```

The SDDM option is the only part that requests `sudo`. It copies visual assets
from the Omarchy theme already installed on your machine; this repository does
not redistribute those assets.

Log out, choose **Plasma (Wayland)**, and log back in. Existing Hyprland and
`~/.config/omarchy/shell.json` settings are left intact.

## Diagnose and remove

```bash
./doctor.sh
./uninstall.sh
```

Backups live under
`~/.local/state/omarchy-plasma-hybrid/backups/`. The uninstaller restores the
most recent pre-install state, including the previous Plasma panel layout and
SDDM configuration when applicable.

## How it works

The installer derives `shell.qml` and the Agents plugin from the currently
installed Omarchy release, then applies the small Plasma-specific adaptations.
Shared Omarchy shell directories are symlinked read-only. User-owned KWin
widgets live in `~/.config/omarchy/plugins`, while a compatibility wrapper
routes Omarchy IPC to the correct Quickshell instance in Plasma and falls back
to the packaged command in Hyprland.

## Contributing

Issues and pull requests are welcome. Please include `./doctor.sh` output,
Omarchy version, Plasma version, and Quickshell version with bug reports. Do
not post API keys, agent credentials, or the contents of authentication files.

## License

Original integration code is available under the MIT License. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for upstream attribution.
