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

qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
  plasmarchy-show-desktop >/dev/null 2>&1 || true
qs kill --any-display --path "$HOME/.config/quickshell/plasma-omarchy" >/dev/null 2>&1 || true

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
restore_or_remove "$HOME/.config/ksplashrc"
restore_or_remove "$HOME/.config/kscreenlockerrc"
restore_or_remove "$HOME/.config/kglobalshortcutsrc"
restore_or_remove "$HOME/.config/kwinrc"
restore_or_remove "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
restore_or_remove "$HOME/.local/bin/omarchy-shell"
restore_or_remove "$HOME/.local/bin/omarchy-capture-screenshot"
restore_or_remove "$HOME/.local/share/applications/org.omarchy.capture.desktop"
restore_or_remove "$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid"
restore_or_remove "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.show-desktop plasma.agents omatask; do
  restore_or_remove "$HOME/.config/omarchy/plugins/$plugin_id"
done
restore_or_remove "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
systemctl --user try-restart plasma-kglobalaccel.service >/dev/null 2>&1 || true

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

printf '%s\n' 'Plasmarchy removed. Log out and back in to finish restoring the desktop.'
