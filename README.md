# Plasmarchy

The Omarchy shell and theme experience on top of KDE Plasma's fluid window
management. It keeps the distinctive Omarchy bar, menus, indicators, Agents,
Task Manager, Wi-Fi, audio, weather, and theme switching while using KWin for
window tasks, minimization, virtual desktops, effects, and overview.

This is an unofficial community integration. It does not replace or modify
files owned by the Omarchy package.

Published by **cobraxai**.

## Features

- Bottom Omarchy Quickshell bar in a Plasma session
- Theme-aware quick launchers that merge with their running window tasks
- Right-click app actions to pin or unpin Quick Launch icons and add desktop shortcuts
- Right-click any open window to pin it directly to the Plasmarchy bar
- Desktop-entry, executable, project-artwork, and generated-monogram icon fallbacks for custom apps
- Dolphin **Open with Agent** folder submenu generated from installed coding agents
- KWin-aware window task buttons with click-to-minimize behavior
- Right-click Close menu for every running application or folder task
- Show Desktop minimize/restore toggle that keeps the bottom bar visible
- Distinct window-minimize glyph for Show Desktop instead of a display icon
- Plasma virtual desktop switcher and KRunner shortcut
- Plasma-native keyboard layout indicator with click and scroll switching
- Safe keyboard layout buttons on the optional SDDM login and idle lock screens
- Desktop right-click shortcut to the Omarchy theme chooser
- Omarchy application and agent menus
- Omarchy Agents usage panel and the `omatask` system monitor
- Omarchy palette, icon theme, and wallpaper synchronization into Plasma
- Separate Plasma shell configuration, leaving Hyprland untouched
- Optional minimal Omarchy SDDM login screen that selects Plasma
- Timestamped backups, diagnostics, and rollback
- Minimal login flow with Plasma's redundant startup splash disabled
- Matching minimal Omarchy idle/unlock screen backed by KScreenLocker and the active Plasma Shell package
- Print Screen routed through the Omarchy release-to-capture, save, clipboard, notification, and editor flow
- Screenshots and images open in movable, minimizable Gwenview windows
- Omarchy notification popups enabled for screenshot and system feedback
- Omarchy-style drag-to-select screen recording from the Capture menu
- Login-time and live background synchronization with the active Omarchy theme
- Immediate Plasma palette, folder-icon, and Plasmarchy bar refresh after theme changes
- Quick power-button tap suspends directly; a deliberate long press powers down
- Orderly Plasma reboot with previous applications and windows restored at login
- Global `codex-resume-all` picker for saved Codex sessions from every project
- Five-minute, one-shot application checkpoints for crash and power-loss recovery

Unlike Omarchy's upstream top-bar layout, Plasmarchy intentionally installs
its primary bar at the bottom by default.

## Requirements

- A current Omarchy installation
- KDE Plasma 6 and KWin
- Dolphin (the default pinned file manager) and Gwenview (the Plasma-native image viewer)
- Quickshell (`qs`), `qdbus6`, `jq`, `perl`, and `patch`
- `plasma-apply-colorscheme`
- Spectacle and `wl-copy` (used as the KWin-compatible screenshot backend)
- `gpu-screen-recorder` and `slurp` for screen recording

The first tested combination is Omarchy `4.0.0.r1836.g0ae1694-1`, Plasma
`6.7.4`, and Quickshell `0.3.1`. Omarchy development snapshots may change the
shell APIs; run `./doctor.sh` after upgrading.

## Omarchy Plugins marketplace

Plasmarchy is listed as a **manual-setup** plugin because it is a complete KDE
Plasma integration rather than a single shell widget. Adding its small service
entry point through the marketplace is safe and makes no system changes, but
it does not install the full desktop integration by itself. Follow the guided
installation below to install Plasma dependencies, create backups, and choose
the optional panel and login-screen changes explicitly.

## Install

On a fresh Omarchy installation, clone the project and let it install Plasma,
the required Arch packages, the replacement panel, and the Omarchy SDDM login:

```bash
git clone https://github.com/Wizmo-inc/plasmarchy.git
cd plasmarchy
./install.sh --install-deps --replace-panel --with-sddm
```

If Plasma is already installed, omit `--install-deps`.

`--replace-panel` removes existing Plasma panels after backing up the Plasma
layout. Omit it to keep those panels alongside the Omarchy bar.

If Plasma and its dependencies are already installed, the complete integration
can be applied with:

```bash
./install.sh --replace-panel --with-sddm
```

The SDDM option is the only part that requests `sudo`. It copies visual assets
from the Omarchy theme already installed on your machine; this repository does
not redistribute those assets. SDDM reads every file in its configuration
directory, so the installer removes both active and legacy renamed autologin
files after backing them up.

Managed state and desktop entries are written through restrictive randomized
temporary files, flushed, and atomically replaced. The installer refuses
symlinked managed paths. Optional SDDM backups are read into the user-owned
backup without privileged writes, while system restoration uses validated,
same-directory atomic replacements.

Log out, choose **Plasma (Wayland)**, and log back in. Existing Hyprland and
`~/.config/omarchy/shell.json` settings are left intact.

### Add apps to Quick Launch or the desktop

Open the application launcher in the bottom-left corner, then right-click any
app. Choose **Pin to Quick Launch** or **Add to Desktop**. A pinned app can be
removed from the same menu with **Unpin from Quick Launch**. Changes hot-reload;
no logout or restart is required.

You can also right-click any running app on the bar and choose **Pin to
Plasmarchy bar**. Its running task merges into the pinned icon: click it to
restore or minimize, right-click it to close or unpin, and use the same icon to
launch the app again after it has closed.

Advanced users can still edit the `launchers` array on the `plasma.tasks`
entry in `~/.config/omarchy/plasma-shell.json`.

### Switch keyboard layouts

Open Plasma's keyboard configuration with `kcmshell6 kcm_keyboard`, enable
**Configure layouts**, and add at least two layouts. The current layout then
appears beside the clock in the Plasmarchy bar. Left-click switches to the next
layout, right-click switches to the previous one, and the mouse wheel switches
in either direction. The widget stays hidden when only one layout is configured.

Omarchy launches Plasma with the system keyboard configuration at each login.
To make US and Russian persist across restarts while keeping the virtual console
and disk-unlock keymap on US, configure only the graphical XKB setting:

```bash
sudo localectl --no-convert set-x11-keymap us,ru pc105 , grp:alt_shift_toggle
```

When the optional Omarchy-style SDDM theme is installed, both the login screen
and idle lock screen show a `LANG EN` / `LANG RU` button. Clicking it clears any
partly entered password before switching. `Ctrl+Space` provides the same safe
switch from the password field.

### Continue after a reboot

Plasmarchy routes the Omarchy menu's **Reboot** action through Plasma's native
session shutdown and enables **Restore previous logout session**. Plasma saves
supported applications and windows during the orderly logout and relaunches
them after the next login. Applications remain responsible for restoring their
own document, tab, and in-app state, so unsaved work should still be saved
before rebooting.

Codex sessions are persisted independently under Codex's user data directory.
The normal resume picker can be limited to the current folder; run
`codex-resume-all` from any terminal to see saved interactive sessions from all
project directories. Pass `--include-non-interactive` only when you also want
internal or automated sessions shown.

For an unexpected power loss, a systemd user timer refreshes Plasma's compact
fallback application list every five minutes. It runs the native saver briefly
and exits—there is no resident Plasmarchy recovery process consuming RAM. At
the next login Plasma can relaunch the most recently checkpointed applications;
apps such as browsers and Codex then use their own continuously persisted data
to recover tabs and conversations. The last few minutes of newly opened or
closed apps may be absent after a sudden outage, and unsaved editor buffers are
only recoverable when that editor has its own autosave support.

### Open a folder with an agent

Right-click a folder—or empty space inside the current Dolphin folder—and open
**Open with Agent**. Choose any detected coding agent to start it in that exact
directory. The submenu supports Codex, Claude Code, Gemini, OpenCode, and the
other agents supported by Omarchy. Use **Refresh Agent List** after installing
or removing an agent; Plasmarchy also refreshes the list automatically at login.

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

The installer derives `shell.qml`, the application menu, and the Agents plugin
from the currently installed Omarchy release, then applies the small
Plasma-specific adaptations.
Shared Omarchy shell directories are symlinked read-only. User-owned KWin
widgets live in `~/.config/omarchy/plugins`, while a compatibility wrapper
routes Omarchy IPC to the correct Quickshell instance in Plasma and falls back
to the packaged command in Hyprland.
At login, a small session launcher reapplies the current Omarchy palette and
persisted wallpaper before starting the bar. Screen recording retains
Omarchy's direct region selector while using gpu-screen-recorder under KWin.

## Contributing

Issues and pull requests are welcome. Please include `./doctor.sh` output,
Omarchy version, Plasma version, and Quickshell version with bug reports. Do
not post API keys, agent credentials, or the contents of authentication files.

## License

Original integration code is available under the MIT License. See
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for upstream attribution.
