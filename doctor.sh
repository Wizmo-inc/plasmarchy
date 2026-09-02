#!/usr/bin/env bash
set -uo pipefail

failures=0
check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok   command: %s\n' "$1"
  else
    printf 'FAIL command: %s\n' "$1"
    failures=$((failures + 1))
  fi
}

check_file() {
  if [[ -e $1 || -L $1 ]]; then
    printf 'ok   file: %s\n' "$1"
  else
    printf 'FAIL file: %s\n' "$1"
    failures=$((failures + 1))
  fi
}

for command_name in omarchy qs qdbus6 busctl jq perl python kwriteconfig6 kreadconfig6 kbuildsycoca6 kiconfinder6 localectl spectacle wl-copy slurp gpu-screen-recorder kscreen-doctor plasmashell dolphin gwenview omarchy-launch-terminal omarchy-launch-browser; do
  check_command "$command_name"
done
check_file /usr/share/omarchy/shell/shell.qml
check_file "$HOME/.config/omarchy/plasma-shell.json"
check_file "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.tasks/Tasks.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.keyboard-layout/KeyboardLayout.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.show-desktop/ShowDesktop.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.menu/Menu.qml"
check_file "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop/contents/code/main.js"
if [[ -f $HOME/.config/omarchy/plugins/plasma.agents/Panel.qml ]] ||
   compgen -G "$HOME/.config/omarchy/plugins/*.agents/Panel.qml" >/dev/null; then
  printf '%s\n' 'ok   Agents plugin'
else
  printf '%s\n' 'FAIL Agents plugin'
  failures=$((failures + 1))
fi
if rg -q 'setup\.default\.agent' "$HOME/.config/omarchy/plugins/plasma.agents/Panel.qml" 2>/dev/null; then
  printf '%s\n' 'ok   Agents right-click opens the agent chooser'
else
  printf '%s\n' 'FAIL Agents right-click agent chooser route is missing'
  failures=$((failures + 1))
fi
if rg -q '\$HOME/\.local/bin/omarchy-shell" shell summon plasma\.menu.*style\.theme' \
  "$HOME/.local/bin/plasmarchy-themes-handler" 2>/dev/null &&
   rg -q 'localBin = Quickshell\.env\("HOME"\) \+ "/\.local/bin"' \
     "$HOME/.config/omarchy/plugins/plasma.menu/Menu.qml" 2>/dev/null &&
   [[ -x "$HOME/.local/bin/omarchy-menu-images" ]]; then
  printf '%s\n' 'ok   Themes handler opens the Omarchy selector through Plasma IPC'
else
  printf '%s\n' 'FAIL Themes handler cannot open the Omarchy selector through Plasma IPC'
  failures=$((failures + 1))
fi
check_file "$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid/contents/lockscreen/LockScreenUi.qml"
check_file "$HOME/.local/bin/omarchy-capture-screenshot"
check_file "$HOME/.local/bin/omarchy-capture-region"
check_file "$HOME/.local/bin/omarchy-capture-screenrecording"
check_file "$HOME/.local/bin/omarchy-system-reboot"
check_file "$HOME/.local/bin/codex-resume-all"
check_file "$HOME/.config/systemd/user/plasmarchy-session-checkpoint.service"
check_file "$HOME/.config/systemd/user/plasmarchy-session-checkpoint.timer"
check_file "$HOME/.local/bin/plasmarchy-session-start"
check_file "$HOME/.local/bin/plasmarchy-sync-wallpaper"
check_file "$HOME/.local/bin/plasmarchy-quicklaunch"
check_file "$HOME/.local/bin/plasmarchy-open-agent"
check_file "$HOME/.local/bin/plasmarchy-agent-menu-refresh"
check_file "$HOME/.local/bin/plasmarchy-themes-handler"
check_file "$HOME/.local/bin/omarchy-menu-images"
check_file "$HOME/.local/bin/omarchy-hyprland-monitor-focused"
check_file "$HOME/.local/bin/plasmarchy-capture-screenshot"
check_file "$HOME/.local/share/kio/servicemenus/plasmarchy-open-with-agent.desktop"
check_file "$HOME/.local/share/plasma/plasmoids/org.kde.plasma.folder/contents/ui/FolderViewLayer.qml"

current_background=$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null)
plasma_background=$(awk -F= '/^Image=file:\/\// {sub(/^Image=file:\/\//, ""); print; exit}' \
  "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null)
if [[ -n $current_background && $plasma_background == "$current_background" ]]; then
  printf '%s\n' 'ok   Plasma wallpaper matches the current Omarchy background'
else
  printf '%s\n' 'FAIL Plasma wallpaper does not match the current Omarchy background'
  failures=$((failures + 1))
fi

if rg -q 'selection=\$\(slurp' "$HOME/.local/bin/omarchy-capture-region" 2>/dev/null &&
   rg -q 'export PATH=.*\.local/bin' "$HOME/.local/bin/omarchy-capture-screenrecording" 2>/dev/null &&
   rg -q 'export PATH=.*\.local/bin' "$HOME/.local/bin/plasmarchy-session-start" 2>/dev/null &&
   rg -q 'activeOutputName' "$HOME/.local/bin/omarchy-hyprland-monitor-focused" 2>/dev/null &&
   rg -q 'resolution=0x0' "$HOME/.local/bin/omarchy-capture-screenrecording" 2>/dev/null; then
  printf '%s\n' 'ok   screen recording uses Plasma monitor and drag selection helpers'
else
  printf '%s\n' 'FAIL screen recording is not using the Plasma capture helpers'
  failures=$((failures + 1))
fi

if [[ $(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null) == org.omarchy.plasma.hybrid ]]; then
  printf '%s\n' 'ok   Omarchy Plasma idle lock screen is selected'
else
  printf '%s\n' 'FAIL Omarchy Plasma idle lock screen is not selected'
  failures=$((failures + 1))
fi

lock_ui=$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid/contents/lockscreen/LockScreenUi.qml
if rg -q 'Qt.Key_Return.*Qt.Key_Enter' "$lock_ui" 2>/dev/null &&
   rg -q 'authenticator\.promptForSecret' "$lock_ui" 2>/dev/null &&
   rg -q 'pendingPassword' "$lock_ui" 2>/dev/null &&
   rg -q 'KeyboardLayoutSwitcher' "$lock_ui" 2>/dev/null; then
  printf '%s\n' 'ok   idle lock supports reliable authentication and keyboard-layout switching'
else
  printf '%s\n' 'FAIL idle lock is missing reliable authentication or keyboard-layout switching'
  failures=$((failures + 1))
fi

sddm_ui=/usr/local/share/sddm/themes/omarchy-plasma/Main.qml
if [[ -f $sddm_ui ]] &&
   rg -q 'keyboard\.currentLayout' "$sddm_ui" 2>/dev/null &&
   rg -q 'hasMultipleKeyboardLayouts' "$sddm_ui" 2>/dev/null; then
  printf '%s\n' 'ok   Omarchy-style SDDM login supports keyboard-layout switching'
else
  printf '%s\n' 'warn Omarchy-style SDDM login layout switcher is not installed'
fi

capture_desktop="$HOME/.local/share/applications/org.omarchy.capture.desktop"
capture_action_ready=false
if rg -q '^Exec=.*plasmarchy-capture-screenshot$' "$capture_desktop" 2>/dev/null &&
   rg -q '^StartupNotify=false$' "$capture_desktop" 2>/dev/null &&
   rg -q '^DBusActivatable=false$' "$capture_desktop" 2>/dev/null &&
   rg -q '^X-KDE-GlobalAccel-CommandShortcut=true$' "$capture_desktop" 2>/dev/null &&
   ! rg -q '^NoDisplay=true$' "$capture_desktop" 2>/dev/null &&
   [[ $(kreadconfig6 --file kglobalshortcutsrc --group services \
     --group org.omarchy.capture.desktop --key _launch 2>/dev/null) == Print* ]]; then
  capture_action_ready=true
fi

if qdbus6 org.kde.kglobalaccel /kglobalaccel >/dev/null 2>&1; then
  print_owners=$(qdbus6 --literal org.kde.kglobalaccel /kglobalaccel \
    org.kde.KGlobalAccel.getGlobalShortcutsByKey 16777225 2>/dev/null)
  if [[ $capture_action_ready == true &&
        $print_owners == *org.omarchy.capture.desktop* &&
        $print_owners != *org_omarchy_capture_desktop* &&
        $print_owners != *org.kde.spectacle.desktop* ]]; then
    printf '%s\n' 'ok   Print exclusively opens the Omarchy screenshot flow'
  else
    printf '%s\n' 'FAIL Print has a missing or conflicting screenshot shortcut'
    failures=$((failures + 1))
  fi
elif [[ $capture_action_ready == true ]]; then
  printf '%s\n' 'ok   Omarchy Print desktop action is installed'
else
  printf '%s\n' 'FAIL Omarchy Print desktop action is not installed'
  failures=$((failures + 1))
fi

if rg -q 'refreshCurrentShell' "$HOME/.config/omarchy/hooks/theme-set.d" 2>/dev/null; then
  printf '%s\n' 'FAIL a theme hook still calls destructive refreshCurrentShell'
  failures=$((failures + 1))
fi

if [[ $(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null) == Omarchy-Plasma ]] &&
   [[ $(kiconfinder6 keyboard-layout 2>/dev/null) == *keyboard-layout* ]]; then
  printf '%s\n' 'ok   Plasma-specific icons fall back cleanly from the Omarchy icon theme'
else
  printf '%s\n' 'FAIL Plasma-specific icon fallback is not configured'
  failures=$((failures + 1))
fi

if [[ $(kreadconfig6 --file ksplashrc --group KSplash --key Theme 2>/dev/null) == None ]] &&
   [[ $(kreadconfig6 --file ksplashrc --group KSplash --key Engine 2>/dev/null) == none ]]; then
  printf '%s\n' 'ok   Plasma startup splash is disabled'
else
  printf '%s\n' 'note Plasma startup splash is enabled'
fi

power_button_ok=true
for power_profile in AC Battery LowBattery; do
  if [[ $(kreadconfig6 --file powerdevilrc --group "$power_profile" \
          --group SuspendAndShutdown --key PowerButtonAction 2>/dev/null) != 1 ]]; then
    power_button_ok=false
  fi
done
if $power_button_ok; then
  printf '%s\n' 'ok   hardware power-button tap suspends through Plasma'
else
  printf '%s\n' 'FAIL hardware power-button tap is not configured to suspend'
  failures=$((failures + 1))
fi

if [[ $(kreadconfig6 --file ksmserverrc --group General --key loginMode 2>/dev/null) == restorePreviousLogout ]] &&
   rg -q 'org\.kde\.Shutdown\.logoutAndReboot' "$HOME/.local/bin/omarchy-system-reboot" 2>/dev/null; then
  printf '%s\n' 'ok   orderly reboot saves and restores the previous Plasma session'
else
  printf '%s\n' 'FAIL previous Plasma session restoration is not configured'
  failures=$((failures + 1))
fi

if [[ -x $HOME/.local/bin/codex-resume-all ]] &&
   rg -q 'codex resume --all' "$HOME/.local/bin/codex-resume-all" 2>/dev/null; then
  printf '%s\n' 'ok   global Codex resume picker is installed'
else
  printf '%s\n' 'FAIL global Codex resume picker is missing'
  failures=$((failures + 1))
fi

if systemctl --user is-enabled plasmarchy-session-checkpoint.timer >/dev/null 2>&1 &&
   systemctl --user is-active plasmarchy-session-checkpoint.timer >/dev/null 2>&1 &&
   [[ -s $HOME/.local/state/plasmasessionrestorestaterc ]]; then
  printf '%s\n' 'ok   low-overhead crash-recovery checkpoint timer is active'
else
  printf '%s\n' 'FAIL crash-recovery session checkpoint is inactive or empty'
  failures=$((failures + 1))
fi

if command -v jq >/dev/null 2>&1 && ! jq -e . "$HOME/.config/omarchy/plasma-shell.json" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL plasma-shell.json is invalid JSON'
  failures=$((failures + 1))
fi

if [[ $(jq -r '.bar.position // empty' "$HOME/.config/omarchy/plasma-shell.json" 2>/dev/null) == bottom ]]; then
  printf '%s\n' 'ok   Plasmarchy bar is positioned at the bottom'
else
  printf '%s\n' 'FAIL Plasmarchy bar is not positioned at the bottom'
  failures=$((failures + 1))
fi

if jq -e '.bar.layout.center[] | select(.id == "plasma.keyboard-layout")' \
  "$HOME/.config/omarchy/plasma-shell.json" >/dev/null 2>&1 &&
  rg -q 'org\.kde\.plasma\.workspace\.keyboardlayout' \
    "$HOME/.config/omarchy/plugins/plasma.keyboard-layout/KeyboardLayout.qml" 2>/dev/null; then
  printf '%s\n' 'ok   Plasma keyboard layout switcher is available on the bar'
else
  printf '%s\n' 'FAIL Plasma keyboard layout switcher is missing from the bar'
  failures=$((failures + 1))
fi

layout_count=$(qdbus6 --literal org.kde.keyboard /Layouts getLayoutsList 2>/dev/null |
  rg -o '\[Argument: \(sss\)' | wc -l)
if ((layout_count > 1)); then
  printf 'ok   Plasma currently exposes %d keyboard layouts\n' "$layout_count"
  system_layouts=$(localectl status 2>/dev/null |
    sed -n 's/^[[:space:]]*X11 Layout: //p')
  if [[ $system_layouts == *,* ]]; then
    printf 'ok   system XKB layouts (%s) persist across Plasma logins\n' "$system_layouts"
  else
    printf '%s\n' 'warn multiple layouts are not in the system XKB setting and may reset at login'
  fi
else
  printf '%s\n' 'warn Plasma currently exposes one keyboard layout; the bar switcher stays hidden'
fi

if jq -e '.bar.layout.left[] | select(.id == "plasma.tasks") | .launchers | length > 0' \
  "$HOME/.config/omarchy/plasma-shell.json" >/dev/null 2>&1; then
  printf '%s\n' 'ok   quick launchers are configured before window tasks'
else
  printf '%s\n' 'FAIL quick launchers are missing from plasma.tasks'
  failures=$((failures + 1))
fi

if jq -e '.plugins[] | select(.id == "plasma.menu")' \
  "$HOME/.config/omarchy/plasma-shell.json" >/dev/null 2>&1 &&
  rg -q 'Pin to Quick Launch' "$HOME/.config/omarchy/plugins/plasma.menu/Menu.qml" 2>/dev/null; then
  printf '%s\n' 'ok   graphical app actions are installed'
else
  printf '%s\n' 'FAIL graphical app actions are missing'
  failures=$((failures + 1))
fi

if rg -q 'Pin to Plasmarchy bar' "$HOME/.config/omarchy/plugins/plasma.tasks/Tasks.qml" 2>/dev/null; then
  printf '%s\n' 'ok   running windows can be pinned directly from the taskbar'
else
  printf '%s\n' 'FAIL taskbar pin action is missing'
  failures=$((failures + 1))
fi

if rg -q 'fallback_icon_for_app' "$HOME/.config/omarchy/plugins/plasma.tasks/tasks.sh" 2>/dev/null; then
  printf '%s\n' 'ok   custom apps have project-artwork and monogram icon fallbacks'
else
  printf '%s\n' 'FAIL custom-app icon fallback is missing'
  failures=$((failures + 1))
fi

if [[ $(xdg-mime query default image/png 2>/dev/null) == org.kde.gwenview.desktop ]] &&
   [[ $(xdg-mime query default image/jpeg 2>/dev/null) == org.kde.gwenview.desktop ]]; then
  printf '%s\n' 'ok   images open in Plasma-native Gwenview windows'
else
  printf '%s\n' 'FAIL image files are not associated with Gwenview'
  failures=$((failures + 1))
fi

if [[ $(xdg-mime query default x-scheme-handler/plasmarchy 2>/dev/null) == org.plasmarchy.themes.desktop ]] &&
   rg -q 'plasmarchyThemesAction' \
     "$HOME/.local/share/plasma/plasmoids/org.kde.plasma.folder/contents/ui/FolderViewLayer.qml" 2>/dev/null; then
  printf '%s\n' 'ok   desktop context menu includes Plasmarchy Themes'
else
  printf '%s\n' 'FAIL desktop Themes context action is missing'
  failures=$((failures + 1))
fi

if [[ $(jq -r '.bar.layout.right[-1].id // empty' "$HOME/.config/omarchy/plasma-shell.json" 2>/dev/null) == plasma.show-desktop ]]; then
  printf '%s\n' 'ok   Show Desktop is the final right-side bar action'
else
  printf '%s\n' 'FAIL Show Desktop is not the final right-side bar action'
  failures=$((failures + 1))
fi

if qdbus6 org.kde.KWin /Scripting >/dev/null 2>&1; then
  if qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded \
    plasmarchy-show-desktop 2>/dev/null | grep -qx true; then
    printf '%s\n' 'ok   Plasmarchy minimize-all KWin script is loaded'
  else
    printf '%s\n' 'FAIL Plasmarchy minimize-all KWin script is not loaded'
    failures=$((failures + 1))
  fi
else
  printf '%s\n' 'note KWin scripting unavailable (expected outside a running Plasma session)'
fi

if qdbus6 org.kde.KWin /KWin org.kde.KWin.currentDesktop >/dev/null 2>&1; then
  printf '%s\n' 'ok   KWin D-Bus'
else
  printf '%s\n' 'note KWin D-Bus unavailable (expected outside a running Plasma session)'
fi

if qs list --all 2>/dev/null | grep -Fq "$HOME/.config/quickshell/plasma-omarchy/shell.qml"; then
  printf '%s\n' 'ok   hybrid shell is running'
else
  printf '%s\n' 'note hybrid shell is not currently running'
fi

exit "$failures"
