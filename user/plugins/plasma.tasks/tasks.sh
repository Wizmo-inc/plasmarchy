#!/bin/bash

# KWin intentionally restricts its private task-management Wayland protocol
# to Plasma. Its WindowsRunner D-Bus interface is public, compositor-native,
# and includes minimized windows, so expose that as a small tabular model.

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
    icon=$desktop_file
    [[ -n $icon ]] || icon=$resource_class
    [[ -n $icon ]] || icon=application-x-executable
    printf '%s\t%s\t%s\t%s\n' "$id" "$title" "$icon" "${minimized:-false}"
  done
