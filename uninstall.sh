#!/usr/bin/env bash
set -euo pipefail

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-plasma-hybrid
backup_dir=$state_dir/latest-backup

[[ -n ${HOME:-} && $HOME != / ]] || {
  printf '%s\n' 'Refusing to uninstall with an empty or root HOME.' >&2
  exit 1
}

[[ -d $backup_dir ]] || {
  printf 'No installation backup found at %s\n' "$backup_dir" >&2
  exit 1
}

pkill -f "$HOME/.config/quickshell/plasma-omarchy/shell.qml" 2>/dev/null || true

restore_or_remove() {
  local target=$1 saved=$backup_dir/${1#/}
  rm -rf -- "$target"
  if [[ -e $saved || -L $saved ]]; then
    mkdir -p "$(dirname -- "$target")"
    cp -a -- "$saved" "$target"
  fi
}

restore_or_remove "$HOME/.config/omarchy/plasma-shell.json"
restore_or_remove "$HOME/.config/quickshell/plasma-omarchy"
restore_or_remove "$HOME/.config/autostart/plasma-omarchy-bar.desktop"
restore_or_remove "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
restore_or_remove "$HOME/.local/bin/omarchy-shell"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.agents omatask; do
  restore_or_remove "$HOME/.config/omarchy/plugins/$plugin_id"
done
restore_or_remove "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

if [[ -f $state_dir/system-install.env ]] && grep -qx 'with_sddm=true' "$state_dir/system-install.env"; then
  sudo rm -rf -- /usr/local/share/sddm/themes/omarchy-plasma
  sudo rm -f -- /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf
  if [[ -f $backup_dir/etc/sddm.conf.d/zz-omarchy-plasma-theme.conf ]]; then
    sudo cp -a -- "$backup_dir/etc/sddm.conf.d/zz-omarchy-plasma-theme.conf" /etc/sddm.conf.d/
  fi
  if [[ -f $backup_dir/etc/sddm.conf.d/autologin.conf ]]; then
    sudo rm -f -- /etc/sddm.conf.d/autologin.conf.disabled
    sudo cp -a -- "$backup_dir/etc/sddm.conf.d/autologin.conf" /etc/sddm.conf.d/autologin.conf
  elif [[ -f $backup_dir/etc/sddm.conf.d/autologin.conf.disabled ]]; then
    sudo cp -a -- "$backup_dir/etc/sddm.conf.d/autologin.conf.disabled" /etc/sddm.conf.d/autologin.conf.disabled
  fi
fi

printf '%s\n' 'Omarchy Plasma Hybrid removed. Log out and back in to finish restoring the desktop.'
