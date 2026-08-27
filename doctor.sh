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

for command_name in omarchy qs qdbus6 jq perl python plasmashell; do
  check_command "$command_name"
done
check_file /usr/share/omarchy/shell/shell.qml
check_file "$HOME/.config/omarchy/plasma-shell.json"
check_file "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.tasks/Tasks.qml"
check_file "$HOME/.config/omarchy/plugins/plasma.agents/Panel.qml"

if command -v jq >/dev/null 2>&1 && ! jq -e . "$HOME/.config/omarchy/plasma-shell.json" >/dev/null 2>&1; then
  printf '%s\n' 'FAIL plasma-shell.json is invalid JSON'
  failures=$((failures + 1))
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
