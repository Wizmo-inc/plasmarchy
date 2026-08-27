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

for command_name in omarchy qs qdbus6 busctl jq perl python kwriteconfig6 kreadconfig6 kbuildsycoca6 spectacle wl-copy plasmashell dolphin gwenview omarchy-launch-terminal omarchy-launch-browser; do
  check_command "$command_name"
done
check_file /usr/share/omarchy/shell/shell.qml
check_file "$HOME/.config/omarchy/plasma-shell.json"
check_file "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.tasks/Tasks.qml"
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
check_file "$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid/contents/lockscreen/LockScreenUi.qml"
check_file "$HOME/.local/bin/omarchy-capture-screenshot"
check_file "$HOME/.local/bin/plasmarchy-quicklaunch"

if [[ $(kreadconfig6 --file kscreenlockerrc --group Greeter --key Theme 2>/dev/null) == org.omarchy.plasma.hybrid ]]; then
  printf '%s\n' 'ok   Omarchy Plasma idle lock screen is selected'
else
  printf '%s\n' 'FAIL Omarchy Plasma idle lock screen is not selected'
  failures=$((failures + 1))
fi

if qdbus6 org.kde.kglobalaccel /kglobalaccel >/dev/null 2>&1; then
  print_owners=$(qdbus6 --literal org.kde.kglobalaccel /kglobalaccel \
    org.kde.KGlobalAccel.getGlobalShortcutsByKey 16777225 2>/dev/null)
  if [[ $print_owners == *org.omarchy.capture.desktop* &&
        $print_owners != *org_omarchy_capture_desktop* &&
        $print_owners != *org.kde.spectacle.desktop* ]]; then
    printf '%s\n' 'ok   Print exclusively opens the Omarchy screenshot flow'
  else
    printf '%s\n' 'FAIL Print has a missing or conflicting screenshot shortcut'
    failures=$((failures + 1))
  fi
elif grep -q '^X-KDE-Shortcuts=Print$' "$HOME/.local/share/applications/org.omarchy.capture.desktop" 2>/dev/null; then
  printf '%s\n' 'ok   Omarchy Print desktop action is installed'
else
  printf '%s\n' 'FAIL Omarchy Print desktop action is not installed'
  failures=$((failures + 1))
fi

if rg -q 'refreshCurrentShell' "$HOME/.config/omarchy/hooks/theme-set.d" 2>/dev/null; then
  printf '%s\n' 'FAIL a theme hook still calls destructive refreshCurrentShell'
  failures=$((failures + 1))
fi

if [[ $(kreadconfig6 --file ksplashrc --group KSplash --key Theme 2>/dev/null) == None ]] &&
   [[ $(kreadconfig6 --file ksplashrc --group KSplash --key Engine 2>/dev/null) == none ]]; then
  printf '%s\n' 'ok   Plasma startup splash is disabled'
else
  printf '%s\n' 'note Plasma startup splash is enabled'
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

if [[ $(xdg-mime query default image/png 2>/dev/null) == org.kde.gwenview.desktop ]] &&
   [[ $(xdg-mime query default image/jpeg 2>/dev/null) == org.kde.gwenview.desktop ]]; then
  printf '%s\n' 'ok   images open in Plasma-native Gwenview windows'
else
  printf '%s\n' 'FAIL image files are not associated with Gwenview'
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
