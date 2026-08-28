#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-plasma-hybrid
stamp=$(date +%Y%m%d-%H%M%S)
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

atomic_write() {
  local target=$1 mode=${2:-0600} parent temporary
  parent=$(dirname -- "$target")
  assert_user_path_safe "$parent"
  mkdir -p "$parent"
  assert_user_path_safe "$target"
  temporary=$(mktemp --tmpdir="$parent" ".$(basename -- "$target").XXXXXX")
  chmod 0600 "$temporary"
  if ! cat > "$temporary"; then
    rm -f -- "$temporary"
    return 1
  fi
  chmod "$mode" "$temporary"
  sync -f "$temporary"
  assert_user_path_safe "$target"
  mv -T -- "$temporary" "$target"
  sync -f "$parent"
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

backup_root_file() {
  local source=$1 target=$2
  assert_system_path_safe "$source"
  assert_user_path_safe "$target"
  sudo test -f "$source" || return 0
  sudo cat -- "$source" | atomic_write "$target" 0600
}

if $install_deps; then
  command -v pacman >/dev/null 2>&1 || {
    printf '%s\n' '--install-deps currently supports Arch Linux only.' >&2
    exit 1
  }
  sudo pacman -S --needed plasma-meta dolphin gwenview qt6-tools patch python spectacle wl-clipboard
fi

require() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Missing dependency: %s\n' "$1" >&2; exit 1; }
}

for command_name in qs qdbus6 busctl systemctl jq perl patch python kwriteconfig6 kreadconfig6 kbuildsycoca6 spectacle wl-copy slurp gpu-screen-recorder kscreen-doctor plasma-apply-colorscheme dolphin gwenview omarchy-launch-terminal omarchy-launch-browser; do
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
[[ -d $omarchy_root/shell/plugins/menu ]] || {
  printf 'The installed Omarchy version does not provide the application menu plugin.\n' >&2
  exit 1
}
jq -e '.bar.position == "bottom"' "$repo_dir/user/plasma-shell.json" >/dev/null || {
  printf '%s\n' 'Plasmarchy package error: the default bar position must be bottom.' >&2
  exit 1
}

assert_user_path_safe "$state_dir"
mkdir -p "$state_dir/backups"
chmod 0700 "$state_dir" "$state_dir/backups"
backup_dir=$(mktemp -d "$state_dir/backups/$stamp.XXXXXX")
chmod 0700 "$backup_dir"

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
backup "$HOME/.config/kscreenlockerrc"
backup "$HOME/.config/plasmashellrc"
backup "$HOME/.config/kglobalshortcutsrc"
backup "$HOME/.config/powerdevilrc"
backup "$HOME/.config/mimeapps.list"
backup "$HOME/.config/kwinrc"
backup "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
backup "$HOME/.local/bin/omarchy-shell"
backup "$HOME/.local/bin/omarchy-capture-screenshot"
backup "$HOME/.local/bin/omarchy-capture-region"
backup "$HOME/.local/bin/omarchy-capture-screenrecording"
backup "$HOME/.local/bin/plasmarchy-session-start"
backup "$HOME/.local/bin/plasmarchy-sync-wallpaper"
backup "$HOME/.local/bin/plasmarchy-quicklaunch"
backup "$HOME/.local/bin/plasmarchy-open-agent"
backup "$HOME/.local/bin/plasmarchy-agent-menu-refresh"
backup "$HOME/.local/bin/plasmarchy-themes-handler"
backup "$HOME/.local/share/kio/servicemenus/plasmarchy-open-with-agent.desktop"
backup "$HOME/.local/share/applications/org.omarchy.capture.desktop"
backup "$HOME/.local/share/applications/org.plasmarchy.themes.desktop"
backup "$HOME/.local/share/plasma/plasmoids/org.kde.plasma.folder"
backup "$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid"
backup "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop"
backup "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.show-desktop plasma.agents plasma.menu omatask; do
  backup "$HOME/.config/omarchy/plugins/$plugin_id"
done

mkdir -p \
  "$HOME/.config/omarchy/plugins" \
  "$HOME/.config/omarchy/hooks/theme-set.d" \
  "$HOME/.config/quickshell/plasma-omarchy" \
  "$HOME/.config/autostart" \
  "$HOME/.local/bin" \
  "$HOME/.local/share/applications" \
  "$HOME/.local/share/kio/servicemenus" \
  "$HOME/.local/share/plasma/plasmoids" \
  "$HOME/.local/share/plasma/shells" \
  "$HOME/.local/share/kwin/scripts"

install -m 0644 "$repo_dir/user/plasma-shell.json" "$HOME/.config/omarchy/plasma-shell.json"
for plugin_id in plasma.launcher plasma.tasks plasma.workspaces plasma.show-desktop omatask; do
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

rm -rf -- "$HOME/.config/omarchy/plugins/plasma.menu"
cp -a -- "$omarchy_root/shell/plugins/menu" "$HOME/.config/omarchy/plugins/plasma.menu"
if ! patch --silent --forward -d "$HOME/.config/omarchy/plugins/plasma.menu" -p1 < "$repo_dir/patches/menu-plasma.patch"; then
  printf '%s\n' 'The Plasmarchy application-menu patch does not match this Omarchy version.' >&2
  exit 1
fi

cp -- "$omarchy_root/shell/shell.qml" "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
perl -pi -e 's#home \+ "/\.config/omarchy/shell\.json"#home + "/.config/omarchy/plasma-shell.json"#' \
  "$HOME/.config/quickshell/plasma-omarchy/shell.qml"
for item in Commons Ui plugins services; do
  ln -sfn -- "$omarchy_root/shell/$item" "$HOME/.config/quickshell/plasma-omarchy/$item"
done

install -m 0755 "$repo_dir/user/omarchy-shell" "$HOME/.local/bin/omarchy-shell"
install -m 0755 "$repo_dir/user/omarchy-capture-screenshot" "$HOME/.local/bin/omarchy-capture-screenshot"
install -m 0755 "$repo_dir/user/omarchy-capture-region" "$HOME/.local/bin/omarchy-capture-region"
install -m 0755 "$repo_dir/user/omarchy-capture-screenrecording" "$HOME/.local/bin/omarchy-capture-screenrecording"
install -m 0755 "$repo_dir/user/plasmarchy-session-start" "$HOME/.local/bin/plasmarchy-session-start"
install -m 0755 "$repo_dir/user/plasmarchy-sync-wallpaper" "$HOME/.local/bin/plasmarchy-sync-wallpaper"
install -m 0755 "$repo_dir/user/plasmarchy-quicklaunch" "$HOME/.local/bin/plasmarchy-quicklaunch"
install -m 0755 "$repo_dir/user/plasmarchy-open-agent" "$HOME/.local/bin/plasmarchy-open-agent"
install -m 0755 "$repo_dir/user/plasmarchy-agent-menu-refresh" "$HOME/.local/bin/plasmarchy-agent-menu-refresh"
install -m 0755 "$repo_dir/user/plasmarchy-themes-handler" "$HOME/.local/bin/plasmarchy-themes-handler"
install -m 0755 "$repo_dir/user/plasma-hybrid.hook" "$HOME/.config/omarchy/hooks/theme-set.d/plasma-hybrid.hook"
install -m 0644 "$repo_dir/user/org.plasmarchy.themes.desktop" \
  "$HOME/.local/share/applications/org.plasmarchy.themes.desktop"
"$HOME/.local/bin/plasmarchy-agent-menu-refresh"

# Derive Plasma's exact installed Folder View containment and add the Omarchy
# theme chooser to its blank-desktop contextual actions. The user copy shadows
# the package with the same plugin ID; package-owned files remain untouched.
desktop_containment_source=/usr/share/plasma/plasmoids/org.kde.desktopcontainment
folder_metadata_source=/usr/share/plasma/plasmoids/org.kde.plasma.folder/metadata.json
desktop_containment_target=$HOME/.local/share/plasma/plasmoids/org.kde.plasma.folder
[[ -f $desktop_containment_source/contents/ui/FolderViewLayer.qml && -f $folder_metadata_source ]] || {
  printf '%s\n' 'The installed Plasma Folder View containment is incomplete.' >&2
  exit 1
}
rm -rf -- "$desktop_containment_target"
cp -a -- "$desktop_containment_source" "$desktop_containment_target"
jq 'del(."X-Plasma-RootPath")' "$folder_metadata_source" | \
  atomic_write "$desktop_containment_target/metadata.json" 0644
patch --silent --forward -d "$desktop_containment_target" -p1 \
  < "$repo_dir/patches/desktop-containment-themes.patch"

# Omarchy defaults to imv, whose intentionally minimal tiling-WM surface has
# no visible window controls in Plasma. Use KDE's native viewer so images have
# normal move, minimize, maximize, and close behavior.
for image_mime in image/png image/jpeg image/gif image/bmp image/webp image/tiff image/svg+xml image/x-xcf image/x-portable-pixmap image/x-xbitmap; do
  kwriteconfig6 --file mimeapps.list --group 'Default Applications' \
    --key "$image_mime" org.kde.gwenview.desktop
done
kwriteconfig6 --file mimeapps.list --group 'Default Applications' \
  --key x-scheme-handler/plasmarchy org.plasmarchy.themes.desktop

# Plasma owns the hardware power key in this hybrid session because logind is
# configured to ignore it. Make a tap suspend immediately while retaining a
# deliberate long press as the emergency power-down action.
for power_profile in AC Battery LowBattery; do
  kwriteconfig6 --file powerdevilrc --group "$power_profile" \
    --group SuspendAndShutdown --key PowerButtonAction 1
  kwriteconfig6 --file powerdevilrc --group "$power_profile" \
    --group SuspendAndShutdown --key PowerDownAction 8
  kwriteconfig6 --file powerdevilrc --group "$power_profile" \
    --group SuspendAndShutdown --key SleepMode 1
done
systemctl --user try-restart plasma-powerdevil.service >/dev/null 2>&1 || true
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

rm -rf -- "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop"
cp -a -- "$repo_dir/user/kwin/scripts/plasmarchy-show-desktop" \
  "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop"
kwriteconfig6 --file kwinrc --group Plugins \
  --key plasmarchy-show-desktopEnabled true --notify
if qdbus6 org.kde.KWin /Scripting >/dev/null 2>&1; then
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
    plasmarchy-show-desktop >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "$HOME/.local/share/kwin/scripts/plasmarchy-show-desktop/contents/code/main.js" \
    plasmarchy-show-desktop >/dev/null 2>&1 || true
  qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null 2>&1 || true
fi

# KScreenLocker loads its UI from a Plasma Shell package. Derive a complete,
# version-matched package locally, replacing only the lock frontend.
plasma_shell_source=/usr/share/plasma/shells/org.kde.plasma.desktop
plasma_shell_target=$HOME/.local/share/plasma/shells/org.omarchy.plasma.hybrid
omarchy_sddm_assets=/usr/share/sddm/themes/omarchy
[[ -f $plasma_shell_source/contents/lockscreen/LockScreenUi.qml ]] || {
  printf '%s\n' 'The installed Plasma shell does not provide its expected lock screen.' >&2
  exit 1
}
[[ -f $omarchy_sddm_assets/logo.png ]] || {
  printf '%s\n' 'The installed Omarchy login assets were not found.' >&2
  exit 1
}
rm -rf -- "$plasma_shell_target"
cp -a -- "$plasma_shell_source" "$plasma_shell_target"
perl -pi -e 's/"Id": "org\.kde\.plasma\.desktop"/"Id": "org.omarchy.plasma.hybrid"/' \
  "$plasma_shell_target/metadata.json"
install -m 0644 "$repo_dir/user/lockscreen/LockScreenUi.qml" \
  "$plasma_shell_target/contents/lockscreen/LockScreenUi.qml"
mkdir -p "$plasma_shell_target/contents/lockscreen/assets"
for asset in logo.png lock.png lock-failed.png entry.png entry-failed.png bullet.png; do
  install -m 0644 "$omarchy_sddm_assets/$asset" \
    "$plasma_shell_target/contents/lockscreen/assets/$asset"
done
kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme --notify org.omarchy.plasma.hybrid
# Plasma 6 selects the lock screen from the active Plasma Shell package.
# Keep the legacy Theme key above for older releases, and select the derived
# package through the current ShellPackage key for Plasma 6.
kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage org.omarchy.plasma.hybrid

# Replace Spectacle's Print shortcut with the Omarchy workflow. Spectacle stays
# available on Meta+Shift+S and remains the KWin-compatible capture backend.
capture_desktop=$HOME/.local/share/applications/org.omarchy.capture.desktop
install -m 0644 "$repo_dir/user/org.omarchy.capture.desktop" "$capture_desktop"
kwriteconfig6 --file kglobalshortcutsrc --group org_kde_spectacle_desktop --key _launch \
  $'Meta+Shift+S,Print\tMeta+Shift+S,Launch Spectacle'
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
if systemctl --user is-active plasma-kglobalaccel.service >/dev/null 2>&1; then
  systemctl --user restart plasma-kglobalaccel.service
  for attempt in 1 2 3 4 5; do
    qdbus6 --literal org.kde.kglobalaccel /kglobalaccel \
      org.kde.KGlobalAccel.getGlobalShortcutsByKey 16777225 2>/dev/null | \
      grep -Fq 'org.omarchy.capture.desktop' && break
    sleep 1
  done
  # Remove the underscored component identity used by the first preview. The
  # desktop service's canonical dotted id remains the only Print owner.
  qdbus6 org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister \
    org_omarchy_capture_desktop _launch >/dev/null 2>&1 || true
  # Force Spectacle's active shortcut to Meta+Shift+S only. The config write
  # above preserves its default metadata; this D-Bus call resolves the live
  # ownership conflict without waiting for another login.
  busctl --user call org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel setShortcut \
    asaiu 4 org.kde.spectacle.desktop _launch Spectacle 'Launch Spectacle' \
    1 301989971 4 >/dev/null
fi

# Keep SDDM's minimal login, but skip Plasma's second branded startup screen.
kwriteconfig6 --file ksplashrc --group KSplash --key Theme --notify None
kwriteconfig6 --file ksplashrc --group KSplash --key Engine --notify none

desktop_file=$HOME/.config/autostart/plasma-omarchy-bar.desktop
generate_autostart_entry() {
  printf '%s\n' '[Desktop Entry]'
  printf '%s\n' 'Type=Application'
  printf '%s\n' 'Name=Omarchy Bar for Plasma'
  printf '%s\n' 'Comment=Sync the Omarchy theme and run its bar in KDE Plasma'
  printf 'Exec=env OMARCHY_PATH=%s %s/.local/bin/plasmarchy-session-start\n' "$omarchy_root" "$HOME"
  printf '%s\n' 'OnlyShowIn=KDE;'
  printf '%s\n' 'X-KDE-autostart-after=panel'
  printf '%s\n' 'X-KDE-StartupNotify=false'
}
generate_autostart_entry | atomic_write "$desktop_file" 0644

if $replace_panel && qdbus6 org.kde.plasmashell /PlasmaShell >/dev/null 2>&1; then
  qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
    'var ps = panels(); for (var i = ps.length - 1; i >= 0; --i) ps[i].remove();' >/dev/null
fi

if $with_sddm; then
  [[ -d /usr/share/sddm/themes/omarchy ]] || {
    printf '%s\n' 'The Omarchy SDDM theme is not installed.' >&2
    exit 1
  }
  assert_system_path_safe /usr/local/share/sddm/themes
  assert_system_path_safe /etc/sddm.conf.d
  sudo mkdir -p /usr/local/share/sddm/themes /etc/sddm.conf.d
  mkdir -p "$backup_dir/etc/sddm.conf.d"
  for config_file in /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d/autologin.conf.disabled /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf; do
    backup_root_file "$config_file" "$backup_dir/etc/sddm.conf.d/$(basename -- "$config_file")"
  done
  sddm_target=/usr/local/share/sddm/themes/omarchy-plasma
  assert_system_path_safe "$sddm_target"
  sddm_staging=$(sudo mktemp -d --tmpdir=/usr/local/share/sddm/themes .plasmarchy-theme.XXXXXX)
  sudo cp -a -- /usr/share/sddm/themes/omarchy/. "$sddm_staging/"
  sudo install -m 0644 "$repo_dir/system/sddm/Main.qml" "$sddm_staging/Main.qml"
  sudo install -m 0644 "$repo_dir/system/sddm/metadata.desktop" "$sddm_staging/metadata.desktop"
  sudo sync -f "$sddm_staging"
  assert_system_path_safe "$sddm_target"
  sudo rm -rf -- "$sddm_target"
  sudo mv -T -- "$sddm_staging" "$sddm_target"
  sudo sync -f /usr/local/share/sddm/themes
  printf '%s\n' '[Theme]' 'ThemeDir=/usr/local/share/sddm/themes' 'Current=omarchy-plasma' | \
    atomic_sudo_write /etc/sddm.conf.d/zz-omarchy-plasma-theme.conf 0644
  if sudo test -e /etc/sddm.conf.d/autologin.conf; then
    assert_system_path_safe /etc/sddm.conf.d/autologin.conf
    assert_system_path_safe /etc/sddm.conf.d/autologin.conf.disabled
    sudo mv -T -- /etc/sddm.conf.d/autologin.conf /etc/sddm.conf.d/autologin.conf.disabled
  fi
  printf '%s\n' 'with_sddm=true' | atomic_write "$state_dir/system-install.env" 0600
else
  printf '%s\n' 'with_sddm=false' | atomic_write "$state_dir/system-install.env" 0600
fi

if [[ -L $state_dir/latest-backup ]]; then
  legacy_backup=$(readlink -f -- "$state_dir/latest-backup")
  case "$legacy_backup" in
    "$state_dir/backups/"*) rm -f -- "$state_dir/latest-backup" ;;
    *) printf '%s\n' 'Refusing an unsafe legacy latest-backup symlink.' >&2; exit 1 ;;
  esac
fi
printf '%s\n' "$backup_dir" | atomic_write "$state_dir/latest-backup" 0600
printf 'installed_at=%q\nbackup_dir=%q\n' "$stamp" "$backup_dir" | \
  atomic_write "$state_dir/install.env" 0600

"$repo_dir/doctor.sh" || true

if [[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]]; then
  systemctl --user try-restart plasma-plasmashell.service >/dev/null 2>&1 || true
  # The qs process command contains the configuration directory, not the
  # shell.qml filename. Ask Quickshell to stop the exact instance so updates
  # cannot leave an old plugin component running behind the new files.
  qs kill --any-display --path "$HOME/.config/quickshell/plasma-omarchy" >/dev/null 2>&1 || true
  env OMARCHY_PATH="$omarchy_root" qs --no-duplicate --daemonize --path "$HOME/.config/quickshell/plasma-omarchy"
fi

printf '\nInstalled Plasmarchy. Log out and choose Plasma if this is a new Plasma installation.\n'
printf 'Backup: %s\n' "$backup_dir"
