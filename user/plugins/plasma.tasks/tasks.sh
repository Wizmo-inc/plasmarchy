#!/bin/bash

# KWin intentionally restricts its private task-management Wayland protocol
# to Plasma. Its WindowsRunner D-Bus interface is public, compositor-native,
# and includes minimized windows, so expose that as a small tabular model.

desktop_roots=(
  "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  /usr/local/share/applications
  /usr/share/applications
)

icon_from_desktop_file() {
  local desktop_id=${1%.desktop}
  local resource_class=$2
  local web_host= file= root= icon=

  # KWin normally gives us a desktop-file ID, not an icon name. Resolve the
  # corresponding Desktop Entry so apps such as Konsole do not show KDE's
  # generic unknown-file glyph.
  for root in "${desktop_roots[@]}"; do
    file=$root/$desktop_id.desktop
    if [[ -f $file ]]; then
      icon=$(sed -n 's/^Icon=//p' "$file" | head -n 1)
      [[ -n $icon ]] && printf '%s\n' "$icon" && return
    fi
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
        icon=$(sed -n 's/^Icon=//p' "$file" | head -n 1)
        [[ -n $icon ]] && printf '%s\n' "$icon" && return
      done < <(find "$root" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
    done
  fi

  # The agent is a shell-owned window and intentionally has no Desktop Entry.
  [[ $resource_class == org.omarchy.agent ]] && printf '%s\n' omarchy
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
    skip_taskbar=$(sed -n 's/.*"skipTaskbar" = \[Variant(bool): \(true\|false\)\].*/\1/p' <<<"$info")
    title=${title//$'\t'/ }
    title=${title//$'\n'/ }
    title=${title//\\n/ }
    [[ -n $title && $resource_class != quickshell && $skip_taskbar != true ]] || continue
    icon=$(icon_from_desktop_file "$desktop_file" "$resource_class")
    [[ -n $icon ]] || icon=$desktop_file
    [[ -n $icon ]] || icon=$resource_class
    [[ -n $icon ]] || icon=application-x-executable
    printf '%s\t%s\t%s\t%s\n' "$id" "$title" "$icon" "${minimized:-false}"
  done
