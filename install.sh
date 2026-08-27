#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-plasma-hybrid
stamp=$(date +%Y%m%d-%H%M%S)
backup_dir=$state_dir/backups/$stamp
with_sddm=false
replace_panel=false
install_deps=false

usage() {
  printf '%s\n' "Usage: ./install.sh [--install-deps] [--replace-panel] [--with-sddm]"
  printf '%s\n' "  --install-deps   Install Plasma and required Arch packages"
  printf '%s\n' "  --replace-panel  Back up and remove existing Plasma panels"
  printf '%s\n' "  --with-sddm      Install the minimal Omarchy login theme and disable autologin"
}

while (($#)); do
  case "$1" in
    --install-deps) install_deps=true ;;
    --replace-panel) replace_panel=true ;;
    --with-sddm) with_sddm=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -n ${HOME:-} && $HOME != / ]] || {
  printf '%s\n' 'Refusing to install with an empty or root HOME.' >&2
  exit 1
}

if $install_deps; then
  command -v pacman >/dev/null 2>&1 || {
    printf '%s\n' '--install-deps currently supports Arch Linux only.' >&2
    exit 1
  }
  sudo pacman -S --needed plasma-meta qt6-tools patch python
fi

require() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Missing dependency: %s\n' "$1" >&2; exit 1; }
}

for command_name in qs qdbus6 jq perl patch python kwriteconfig6 kreadconfig6 plasma-apply-colorscheme; do
  require "$command_name"
done

[[ -f $omarchy_root/shell/shell.qml ]] || {
  printf 'Omarchy shell not found under %s\n' "$omarchy_root" >&2
  exit 1
}
[[ -d $omarchy_root/shell/plugins/agents ]] || {
  printf 'The installed Omarchy version does not provide the Agents plugin.\n' >&2
  exit 1
}

mkdir -p "$backup_dir" "$state_dir"

backup() {
  local source=$1 relative
  [[ -e $source || -L $source ]] || return 0
  relative=${source#/}
  mkdir -p "$backup_dir/$(dirname -- "$relative")"
  cp -a -- "$source" "$backup_dir/$relative"
}

backup "$HOME/.config/omarchy/plasma-shell.json"
backup "$HOME/.config/quickshell/plasma-omarchy"
backup "$HOME/.config/autostart/plasma-omarchy-bar.desktop"
backup "$HOME/.config/ksplashrc"
backup "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
backup "$HOME/.local/bin/omarchy-shell"
backup "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.agents omatask; do
  backup "$HOME/.config/omarchy/plugins/$plugin_id"
done

mkdir -p \
  "$HOME/.config/omarchy/plugins" \
  "$HOME/.config/omarchy/hooks/theme-set.d" \
  "$HOME/.config/quickshell/plasma-omarchy" \
  "$HOME/.config/autostart" \
  "$HOME/.local/bin"

install -m 0644 "$repo_dir/user/plasma-shell.json" "$HOME/.config/omarchy/plasma-shell.json"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces omatask; do
  rm -rf -- "$HOME/.config/omarchy/plugins/$plugin_id"
  cp -a -- "$repo_dir/user/plugins/$plugin_id" "$HOME/.config/omarchy/plugins/$plugin_id"
done

rm -rf -- "$HOME/.config/omarchy/plugins/plasma.agents"
cp -a -- "$omarchy_root/shell/plugins/agents" "$HOME/.config/omarchy/plugins/plasma.agents"
perl -pi -e 's/omarchy\.agents/plasma.agents/g' \
  "$HOME/.config/omarchy/plugins/plasma.agents/manifest.json" \
  "$HOME/.config/omarchy/plugins/plasma.agents/Panel.qml" \
  "$HOME/.config/omarchy/plugins/plasma.agents/README.md"
if ! patch --silent --forward -d "$HOME/.config/omarchy/plugins/plasma.agents" -p1 < "$repo_dir/patches/agents-plasma.patch"; then
  printf '%s\n' 'Warning: the Agents menu patch did not match this Omarchy version; the stock right-click action remains.' >&2
fi

cp -- "$omarchy_root/shell/shell.qml" "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
perl -pi -e 's#home \+ "/\.config/omarchy/shell\.json"#home + "/.config/omarchy/plasma-shell.json"#' \
  "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
for item in Commons Ui plugins services; do
  ln -sfn -- "$omarchy_root/shell/$item" "$HOME/.config/quickshell/plasma-omarchy/$item"
done

install -m 0755 "$repo_dir/user/omarchy-shell" "$HOME/.local/bin/omarchy-shell"
install -m 0755 "$repo_dir/user/plasma-hybrid.hook" "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"

# Keep SDDM's minimal login, but skip Plasma's second branded startup screen.
kwriteconfig6 --file ksplashrc --group KSplash --key Theme --notify None
kwriteconfig6 --file ksplashrc --group KSplash --key Engine --notify none

desktop_file=$HOME/.config/autostart/plasma-omarchy-bar.desktop
{
  printf '%s\n' '[Desktop Entry]'
  printf '%s\n' 'Type=Application'
  printf '%s\n' 'Name=Omarchy Bar for Plasma'
  printf '%s\n' 'Comment=Run the Omarchy-style Quickshell bar in KDE Plasma'
  printf 'Exec=env OMARCHY_PATH=%s qs --no-duplicate --daemonize --path %s/.config/quickshell/plasma-omarchy\n' "$omarchy_root" "$HOME"
  printf '%s\n' 'OnlyShowIn=KDE;'
  printf '%s\n' 'X-KDE-autostart-after=panel'
  printf '%s\n' 'X-KDE-StartupNotify=false'
} > "$desktop_file"

if $replace_panel && qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'var ps = panels(); for (var i = ps.length - 1; i >= 0; --i) ps[i].remove();' >/dev/null
fi

if $with_sddm; then
  [[ -d /usr/share/sddm/themes/omarchy ]] || {
    printf '%s\n' 'The Omarchy SDDM theme is not installed.' >&2
    exit 1
  }
  sudo mkdir -p /usr/local/share/sddm/themes /etc/sddm.conf.d "$backup_dir/etc/sddm.conf.d"
  for config_file in /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d/autologin.conf.disabled /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf; do
    if sudo test -e "$config_file"; then
      sudo cp -a -- "$config_file" "$backup_dir/etc/sddm.conf.d/"
    fi
  done
  sudo rm -rf -- /usr/local/share/sddm/themes/omarchy-plasma
  sudo cp -a -- /usr/share/sddm/themes/omarchy /usr/local/share/sddm/themes/omarchy-plasma
  sudo install -m 0644 "$repo_dir/system/sddm/Main.qml" /usr/local/share/sddm/themes/omarchy-plasma/Main.qml
  sudo install -m 0644 "$repo_dir/system/sddm/metadata.desktop" /usr/local/share/sddm/themes/omarchy-plasma/metadata.desktop
  printf '%s\n' '[Theme]' 'ThemeDir=/usr/local/share/sddm/themes' 'Current=omarchy-plasma' | \
    sudo tee /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf >/dev/null
  if sudo test -e /etc/sddm.conf.d/autologin.conf; then
    sudo mv -- /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d/autologin.conf.disabled
  fi
  printf '%s\n' 'with_sddm=true' > "$state_dir/system-install.env"
else
  printf '%s\n' 'with_sddm=false' > "$state_dir/system-install.env"
fi

ln -sfn -- "$backup_dir" "$state_dir/latest-backup"
printf 'installed_at=%q\nbackup_dir=%q\n' "$stamp" "$backup_dir" > "$state_dir/install.env"

"$repo_dir/doctor.sh" || true

if [[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]]; then
  pkill -f "$HOME/.config/quickshell/plasma-omarchy/shell.qml" 2>/dev/null || true
  env OMARCHY_PATH="$omarchy_root" qs --no-duplicate --daemonize --path "$HOME/.config/quickshell/plasma-omarchy"
fi

printf '\nInstalled Omarchy Plasma Hybrid. Log out and choose Plasma if this is a new Plasma installation.\n'
printf 'Backup: %s\n' "$backup_dir"
