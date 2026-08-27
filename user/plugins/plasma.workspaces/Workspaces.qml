import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.workspaces"

  property int currentDesktop: 1
  property int desktopCount: 4

  function refresh() {
    if (!desktopQuery.running) desktopQuery.running = true
  }

  function focusDesktop(id) {
    currentDesktop = id
    desktopSwitch.command = [
      "qdbus6", "org.kde.KWin", "/KWin",
      "org.kde.KWin.setCurrentDesktop", String(id)
    ]
    if (!desktopSwitch.running) desktopSwitch.running = true
  }

  function desktopIds() {
    var values = []
    for (var i = 1; i <= Math.max(1, desktopCount); ++i) values.push(i)
    return values
  }

  Process {
    id: desktopQuery
    command: ["qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.currentDesktop"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = parseInt(text.trim())
        if (!isNaN(parsed) && parsed > 0) root.currentDesktop = parsed
      }
    }
  }

  Process {
    id: countQuery
    command: [
      "qdbus6", "org.kde.KWin", "/VirtualDesktopManager",
      "org.freedesktop.DBus.Properties.Get",
      "org.kde.KWin.VirtualDesktopManager", "count"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var match = text.match(/([0-9]+)/)
        if (match) root.desktopCount = Math.max(1, parseInt(match[1]))
      }
    }
  }

  Process {
    id: desktopSwitch
    onExited: root.refresh()
  }

  Timer {
    interval: 700
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refresh()
      if (!countQuery.running) countQuery.running = true
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.desktopIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.desktopIds()

      WidgetButton {
        required property int modelData
        readonly property bool focused: root.currentDesktop === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : String(modelData)
        opacity: focused ? 1 : 0.52
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: root.focusDesktop(modelData)
      }
    }
  }
}
