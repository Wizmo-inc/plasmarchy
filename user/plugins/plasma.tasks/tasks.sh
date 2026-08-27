#!/bin/bash

# KWin intentionally restricts its private task-management Wayland protocol
# to Plasma. Its WindowsRunner D-Bus interface is public, compositor-native,
# and includes minimized windows, so expose that as a small tabular model.

qdbus6 --literal org.kde.KWin /WindowsRunner org.kde.krunner1.Match '' 2>/dev/null |
  perl -ne '
    while (/\[Argument: \(sssida\{sv\}\) "((?:\\.|[^"])*)", "((?:\\.|[^"])*)", "((?:\\.|[^"])*)",/g) {
      my ($id, $title, $icon) = ($1, $2, $3);
      next unless $id =~ /^0_/;
      next if $seen{$id}++;
      for ($title, $icon) { s/\\"/"/g; s/\\n/ /g; s/\t/ /g; }
      print "$id\t$title\t$icon\n";
    }
  ' |
  while IFS=$'\t' read -r id title icon; do
    uuid=${id#0_}
    info=$(qdbus6 --literal org.kde.KWin /KWin org.kde.KWin.getWindowInfo "$uuid" 2>/dev/null)
    minimized=$(sed -n 's/.*"minimized" = \[Variant(bool): \(true\|false\)\].*/\1/p' <<<"$info")
    desktop_file=$(sed -n 's/.*"desktopFile" = \[Variant(QString): "\([^"]*\)"\].*/\1/p' <<<"$info")
    resource_class=$(sed -n 's/.*"resourceClass" = \[Variant(QString): "\([^"]*\)"\].*/\1/p' <<<"$info")
    [[ -n $title && $resource_class != quickshell ]] || continue
    [[ -n $icon ]] || icon=$desktop_file
    [[ -n $icon ]] || icon=$resource_class
    [[ -n $icon ]] || icon=application-x-executable
    printf '%s\t%s\t%s\t%s\n' "$id" "$title" "$icon" "${minimized:-false}"
  done
