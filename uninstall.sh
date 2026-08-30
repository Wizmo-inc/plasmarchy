#!/usr/bin/env bash
set -euo pipefail

state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-plasma-hybrid

[[ -n ${HOME:-} && $HOME != / ]] || {
  printf '%s\n' 'Refusing to uninstall with an empty or root HOME.' >&2
  exit 1
}

assert_user_path_safe() {
  local path=$1 current=$HOME relative part
  case "$path" in
    "$HOME"|"$HOME"/*) ;;
    *) printf 'Refusing path outside HOME: %s\n' "$path" >&2; exit 1 ;;
  esac
  [[ ! -L $HOME ]] || { printf 'Refusing symlinked HOME: %s\n' "$HOME" >&2; exit 1; }
  relative=${path#"$HOME"}
  relative=${relative#/}
  IFS='/' read -r -a parts <<<"$relative"
  for part in "${parts[@]}"; do
    [[ -n $part ]] || continue
    current=$current/$part
    [[ ! -L $current ]] || {
      printf 'Refusing symlinked path component: %s\n' "$current" >&2
      exit 1
    }
  done
}

assert_system_path_safe() {
  local path=$1 current= part
  [[ $path == /* ]] || { printf 'Refusing non-absolute system path: %s\n' "$path" >&2; exit 1; }
  IFS='/' read -r -a parts <<<"${path#/}"
  for part in "${parts[@]}"; do
    [[ -n $part ]] || continue
    current=$current/$part
    [[ ! -L $current ]] || {
      printf 'Refusing symlinked system path component: %s\n' "$current" >&2
      exit 1
    }
  done
}

atomic_sudo_write() {
  local target=$1 mode=${2:-0644} parent temporary
  parent=$(dirname -- "$target")
  assert_system_path_safe "$parent"
  assert_system_path_safe "$target"
  temporary=$(sudo mktemp --tmpdir="$parent" ".plasmarchy.$(basename -- "$target").XXXXXX")
  if ! sudo tee "$temporary" >/dev/null; then
    sudo rm -f -- "$temporary"
    return 1
  fi
  sudo chmod "$mode" "$temporary"
  sudo sync -f "$temporary"
  assert_system_path_safe "$target"
  sudo mv -T -- "$temporary" "$target"
  sudo sync -f "$parent"
}

restore_root_file() {
  local source=$1 target=$2
  assert_user_path_safe "$source"
  [[ -f $source && ! -L $source ]] || return 1
  atomic_sudo_write "$target" 0644 < "$source"
}

latest_backup=$state_dir/latest-backup
if [[ -L $latest_backup ]]; then
  # Compatibility with pre-1.1 installations, which used a symlink here.
  backup_dir=$(readlink -f -- "$latest_backup")
else
  assert_user_path_safe "$latest_backup"
  IFS= read -r backup_dir < "$latest_backup" || backup_dir=
fi
case "$backup_dir" in
  "$state_dir/backups/"*) ;;
  *) printf 'Refusing backup outside the Plasmarchy backup root: %s\n' "$backup_dir" >&2; exit 1 ;;
esac
assert_user_path_safe "$backup_dir"

[[ -d $backup_dir ]] || {
  printf 'No installation backup found at %s\n' "$backup_dir" >&2
  exit 1
}

qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
  plasmarchy-show-desktop >/dev/null 2>&1 || true
qs kill --any-display --path "$HOME/.config/quickshell/plasma-omarchy" >/dev/null 2>&1 || true
systemctl --user disable --now plasmarchy-session-checkpoint.timer >/dev/null 2>&1 || true

restore_or_remove() {
  local target=$1 saved=$backup_dir/${1#/}
  assert_user_path_safe "$target"
  assert_user_path_safe "$saved"
  rm -rf -- "$target"
  if [[ -e $saved || -L $saved ]]; then
    mkdir -p "$(dirname -- "$target")"
    cp -a -- "$saved" "$target"
  fi
}

restore_or_remove "$HOME/.config/omarchy/plasma-shell.json"
restore_or_remove "$HOME/.config/quickshell/plasma-omarchy"
restore_or_remove "$HOME/.config/autostart/plasma-omarchy-bar.desktop"
restore_or_remove "$HOME/.config/systemd/user/plasmarchy-session-checkpoint.service"
restore_or_remove "$HOME/.config/systemd/user/plasmarchy-session-checkpoint.timer"
restore_or_remove "$HOME/.config/ksplashrc"
restore_or_remove "$HOME/.config/kscreenlockerrc"
restore_or_remove "$HOME/.config/plasmashellrc"
restore_or_remove "$HOME/.config/kglobalshortcutsrc"
restore_or_remove "$HOME/.config/powerdevilrc"
restore_or_remove "$HOME/.config/ksmserverrc"
restore_or_remove "$HOME/.config/mimeapps.list"
restore_or_remove "$HOME/.config/kwinrc"
restore_or_remove "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
restore_or_remove "$HOME/.local/bin/omarchy-shell"
restore_or_remove "$HOME/.local/bin/omarchy-capture-screenshot"
restore_or_remove "$HOME/.local/bin/omarchy-capture-region"
restore_or_remove "$HOME/.local/bin/omarchy-capture-screenrecording"
restore_or_remove "$HOME/.local/bin/omarchy-system-reboot"
restore_or_remove "$HOME/.local/bin/codex-resume-all"
restore_or_remove "$HOME/.local/bin/plasmarchy-session-start"
restore_or_remove "$HOME/.local/bin/plasmarchy-sync-wallpaper"
restore_or_remove "$HOME/.local/bin/plasmarchy-quicklaunch"
restore_or_remove "$HOME/.local/bin/plasmarchy-open-agent"
restore_or_remove "$HOME/.local/bin/plasmarchy-agent-menu-refresh"
restore_or_remove "$HOME/.local/bin/plasmarchy-themes-handler"
restore_or_remove "$HOME/.local/share/kio/servicemenus/plasmarchy-open-with-agent.desktop"
restore_or_remove "$HOME/.local/share/applications/org.omarchy.capture.desktop"
restore_or_remove "$HOME/.local/share/applications/org.plasmarchy.themes.desktop"
plasma_icon_theme_dir="$HOME/.local/share/icons/Omarchy-Plasma"
plasma_icon_theme_backup="$backup_dir/${plasma_icon_theme_dir#/}"
if [[ ! -e $plasma_icon_theme_backup ]] &&
   [[ $(kreadconfig6 --file kdeglobals --group Icons --key Theme 2>/dev/null) == Omarchy-Plasma ]]; then
  previous_icon_theme=$(sed -n 's/^Inherits=\([^,]*\).*/\1/p' "$plasma_icon_theme_dir/index.theme" 2>/dev/null)
  kwriteconfig6 --file kdeglobals --group Icons --key Theme --notify "${previous_icon_theme:-breeze-dark}"
fi
restore_or_remove "$plasma_icon_theme_dir"
restore_or_remove "$HOME/.local/share/plasma/plasmoids/org.kde.plasma.folder"
restore_or_remove "$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid"
restore_or_remove "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.keyboard-layout plasma.show-desktop plasma.agents plasma.menu omatask; do
  restore_or_remove "$HOME/.config/omarchy/plugins/$plugin_id"
done
restore_or_remove "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
systemctl --user daemon-reload
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
systemctl --user try-restart plasma-kglobalaccel.service >/dev/null 2>&1 || true
systemctl --user try-restart plasma-powerdevil.service >/dev/null 2>&1 || true
systemctl --user try-restart plasma-plasmashell.service >/dev/null 2>&1 || true

assert_user_path_safe "$state_dir/system-install.env"
if [[ -f $state_dir/system-install.env && ! -L $state_dir/system-install.env ]] &&
   grep -qx 'with_sddm=true' "$state_dir/system-install.env"; then
  assert_system_path_safe /usr/local/share/sddm/themes/omarchy-plasma
  assert_system_path_safe /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf
  sudo rm -rf -- /usr/local/share/sddm/themes/omarchy-plasma
  sudo rm -f -- /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf
  if [[ -f $backup_dir/etc/sddm.conf.d/zz-omarchy-plasma-theme.conf &&
        ! -L $backup_dir/etc/sddm.conf.d/zz-omarchy-plasma-theme.conf ]]; then
    restore_root_file "$backup_dir/etc/sddm.conf.d/zz-omarchy-plasma-theme.conf" \
      /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf
  fi
  if [[ -f $backup_dir/etc/sddm.conf.d/autologin.conf &&
        ! -L $backup_dir/etc/sddm.conf.d/autologin.conf ]]; then
    assert_system_path_safe /etc/sddm.conf.d/autologin.conf.disabled
    sudo rm -f -- /etc/sddm.conf.d/autologin.conf.disabled
    restore_root_file "$backup_dir/etc/sddm.conf.d/autologin.conf" \
      /etc/sddm.conf.d/autologin.conf
  elif [[ -f $backup_dir/etc/sddm.conf.d/autologin.conf.disabled &&
          ! -L $backup_dir/etc/sddm.conf.d/autologin.conf.disabled ]]; then
    restore_root_file "$backup_dir/etc/sddm.conf.d/autologin.conf.disabled" \
      /etc/sddm.conf.d/autologin.conf.disabled
  fi
fi

printf '%s\n' 'Plasmarchy removed. Log out and back in to finish restoring the desktop.'
