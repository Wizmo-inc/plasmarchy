#!/bin/bash

# KWin intentionally restricts its private task-management Wayland protocol
# to Plasma. Its WindowsRunner D-Bus interface is public, compositor-native,
# and includes minimized windows, so expose that as a small tabular model.

desktop_roots=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  /usr/local/share/applications
  /usr/share/applications
)
desktop_entry_cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/plasmarchy/desktop-entries

remember_desktop_entry() {
  local key=$1 file=$2 temporary=
  mkdir -p -m 0700 "$desktop_entry_cache_dir"
  temporary=$(mktemp "$desktop_entry_cache_dir/.entry.XXXXXX") || return
  chmod 0600 "$temporary"
  printf '%s\n' "$file" >"$temporary"
  mv -f "$temporary" "$desktop_entry_cache_dir/$key"
}

desktop_entry_for_window() {
  local desktop_id=${1%.desktop}
  local resource_class=$2
  local pid=$3
  local web_host= file= root= startup_class= exec_line= executable= cache_key= cache_file=
  executable=$(basename "$(readlink -f "/proc/$pid/exe" 2>/dev/null)" 2>/dev/null)
  cache_key=$(sed 's/[^[:alnum:]._-]/_/g' <<<"${desktop_id:-$resource_class}")

  # KWin normally gives us a desktop-file ID, not an icon name. Resolve the
  # corresponding Desktop Entry so its icon and launch command can be reused.
  for root in "${desktop_roots[@]}"; do
    file=$root/$desktop_id.desktop
    if [[ -f $file ]]; then
      printf '%s\n' "$file"
      return
    fi
  done

  # Slow metadata matching is cached by KWin identity. The Desktop Entry is
  # still read fresh for its icon and label, so package updates remain visible.
  cache_file=$desktop_entry_cache_dir/$cache_key
  if [[ -f $cache_file ]]; then
    IFS= read -r file <"$cache_file"
    if [[ -f $file ]]; then
      printf '%s\n' "$file"
      return
    fi
  fi

  # Development builds and some cross-platform bundles expose their binary
  # name to KWin while installing a reverse-DNS Desktop Entry. Match the
  # standard StartupWMClass or executable so their launcher is discoverable.
  for root in "${desktop_roots[@]}"; do
    [[ -d $root ]] || continue
    while IFS= read -r -d '' file; do
      startup_class=$(sed -n 's/^StartupWMClass=//p' "$file" | head -n 1)
      exec_line=$(sed -n 's/^Exec=//p' "$file" | head -n 1)
      if [[ ( -n $startup_class && ( ${startup_class,,} == ${desktop_id,,} || ${startup_class,,} == ${resource_class,,} ) )
         || ( -n $executable && " ${exec_line,,} " == *"/${executable,,} "* )
         || ( -n $executable && " ${exec_line,,} " == " ${executable,,} "* ) ]]; then
        remember_desktop_entry "$cache_key" "$file"
        printf '%s\n' "$file"
        return
      fi
    done < <(find "$root" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
  done

  # Chrome web-app windows use a generated WM class rather than the friendly
  # .desktop filename. Match its host against the launcher's Exec URL.
  if [[ $resource_class == chrome-* ]]; then
    web_host=${resource_class#chrome-}
    web_host=${web_host%%__*}
    for root in "${desktop_roots[@]}"; do
      [[ -d $root ]] || continue
      while IFS= read -r -d '' file; do
        grep -Fqi -- "$web_host" "$file" || continue
        remember_desktop_entry "$cache_key" "$file"
        printf '%s\n' "$file"
        return
      done < <(find "$root" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done
  fi
}

project_icon_for_process() {
  local pid=$1 desktop_id=$2 resource_class=$3
  local cwd= candidate=
  cwd=$(readlink -f "/proc/$pid/cwd" 2>/dev/null) || return
  [[ $cwd == "$HOME"/* ]] || return

  # Common layouts used by Tauri, Electron, and native app projects. Keep the
  # search explicit and shallow so an uninstalled development build can expose
  # its artwork without scanning an entire source tree every refresh.
  for candidate in \
    "$cwd/assets/$resource_class.png" \
    "$cwd/assets/$desktop_id.png" \
    "$cwd/assets/icon.png" \
    "$cwd/src-tauri/icons/32x32.png" \
    "$cwd/src-tauri/icons/icon.png" \
    "$cwd/icons/$resource_class.png" \
    "$cwd/icons/$desktop_id.png" \
    "$cwd/icon.png" \
    "$cwd/icon.svg"; do
    [[ -f $candidate ]] && printf '%s\n' "$candidate" && return
  done
}

fallback_icon_for_app() {
  local identity=$1 title=$2 cache_dir= key= initial= hue= file= temporary=
  cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/plasmarchy/task-icons
  key=$(sed 's/[^[:alnum:]._-]/_/g' <<<"${identity:-unknown}")
  initial=$(tr -cd '[:alnum:]' <<<"${title:-$identity}" | head -c 1 | tr '[:lower:]' '[:upper:]')
  [[ -n $initial ]] || initial='?'
  hue=$(cksum <<<"$key" | awk '{print $1 % 360}')
  file=$cache_dir/$key.svg
  if [[ ! -f $file ]]; then
    mkdir -p -m 0700 "$cache_dir"
    temporary=$(mktemp "$cache_dir/.icon.XXXXXX") || return
    chmod 0600 "$temporary"
    printf '%s\n' \
      '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">' \
      "<defs><linearGradient id=\"g\" x2=\"1\" y2=\"1\"><stop stop-color=\"hsl($hue 78% 58%)\"/><stop offset=\"1\" stop-color=\"hsl($(((hue + 55) % 360)) 72% 38%)\"/></linearGradient></defs>" \
      '<rect x="3" y="3" width="58" height="58" rx="15" fill="url(#g)"/>' \
      '<rect x="3.75" y="3.75" width="56.5" height="56.5" rx="14.25" fill="none" stroke="white" stroke-opacity=".34" stroke-width="1.5"/>' \
      "<text x=\"32\" y=\"42\" text-anchor=\"middle\" fill=\"white\" font-family=\"sans-serif\" font-size=\"30\" font-weight=\"700\">$initial</text>" \
      '</svg>' >"$temporary"
    mv -f "$temporary" "$file"
  fi
  printf '%s\n' "$file"
}

desktop_id_from_entry() {
  local file=$1 root= relative=
  for root in "${desktop_roots[@]}"; do
    [[ $file == "$root/"* ]] || continue
    relative=${file#"$root/"}
    relative=${relative%.desktop}
    printf '%s\n' "${relative//\//-}"
    return
  done
}

qdbus6 --literal org.kde.KWin /WindowsRunner org.kde.krunner1.Match '' 2>/dev/null |
  perl -ne '
    # Match only stable window UUIDs here. KWin may emit unescaped quotes in
    # captions (common for browser tab titles), so parsing runner title fields
    # would silently omit otherwise valid windows.
    while (/"(0_\{[0-9a-fA-F-]+\})"/g) {
      my $id = $1;
      next if $seen{$id}++;
      print "$id\n";
    }
  ' |
  while IFS= read -r id; do
    uuid=${id#0_}
    info=$(qdbus6 --literal org.kde.KWin /KWin org.kde.KWin.getWindowInfo "$uuid" 2>/dev/null)
    title=$(sed -n 's/.*"caption" = \[Variant(QString): "\(.*\)"\], "clientMachine".*/\1/p' <<<"$info")
    minimized=$(sed -n 's/.*"minimized" = \[Variant(bool): \(true\|false\)\].*/\1/p' <<<"$info")
    desktop_file=$(sed -n 's/.*"desktopFile" = \[Variant(QString): "\([^"]*\)"\].*/\1/p' <<<"$info")
    resource_class=$(sed -n 's/.*"resourceClass" = \[Variant(QString): "\([^"]*\)"\].*/\1/p' <<<"$info")
    pid=$(sed -n 's/.*"pid" = \[Variant(int): \([0-9]*\)\].*/\1/p' <<<"$info")
    skip_taskbar=$(sed -n 's/.*"skipTaskbar" = \[Variant(bool): \(true\|false\)\].*/\1/p' <<<"$info")
    title=${title//$'\t'/ }
    title=${title//$'\n'/ }
    title=${title//\\n/ }
    [[ -n $title && $resource_class != quickshell && $skip_taskbar != true ]] || continue
    desktop_entry= launcher_id= icon= app_name=
    if [[ $resource_class == org.omarchy.agent ]]; then
      # The agent is a shell-owned window and intentionally has no Desktop Entry.
      icon=omarchy
    else
      desktop_entry=$(desktop_entry_for_window "$desktop_file" "$resource_class" "$pid")
    fi
    if [[ -n $desktop_entry ]]; then
      icon=$(sed -n 's/^Icon=//p' "$desktop_entry" | head -n 1)
      app_name=$(sed -n 's/^Name=//p' "$desktop_entry" | head -n 1)
      launcher_id=$(desktop_id_from_entry "$desktop_entry")
    fi
    if [[ -z $icon ]]; then
      theme_icon=$(kiconfinder6 "${desktop_file:-$resource_class}" 22 2>/dev/null || true)
      [[ -n $theme_icon ]] && icon=${desktop_file:-$resource_class}
    fi
    [[ -n $icon ]] || icon=$(project_icon_for_process "$pid" "$desktop_file" "$resource_class")
    if [[ -z $icon ]]; then
      icon=$(fallback_icon_for_app "${resource_class:-$desktop_file}" "$title")
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$id" "$title" "$icon" "${minimized:-false}" "$launcher_id" "$app_name"
  done
