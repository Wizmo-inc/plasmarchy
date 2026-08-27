import QtQuick
import Quickshell
import Quickshell.Io
import org.kde.kirigami as Kirigami
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.show-desktop"

  property bool showingDesktop: false

  function refresh() {
    if (!stateQuery.running) stateQuery.running = true
  }

  function toggleDesktop() {
    var next = !showingDesktop
    showingDesktop = next
    Quickshell.execDetached([
      "qdbus6", "org.kde.KWin", "/KWin",
      "org.kde.KWin.showDesktop", next ? "true" : "false"
    ])
    refreshDelay.restart()
  }

  Process {
    id: stateQuery
    command: ["qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.showingDesktop"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.showingDesktop = String(text).trim() === "true"
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshDelay
    interval: 180
    repeat: false
    onTriggered: root.refresh()
  }

  implicitWidth: !vertical ? barSize + Style.space(3) : barSize
  implicitHeight: barSize

  Rectangle {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: 1
    height: Style.space(16)
    radius: 1
    color: root.bar ? root.bar.barForeground : Color.foreground
    opacity: 0.22
  }

  Item {
    id: button
    anchors.right: parent.right
    width: root.barSize
    height: root.barSize

    Rectangle {
      anchors.fill: parent
      anchors.margins: Style.space(2)
      radius: Style.cornerRadius
      color: root.showingDesktop
          ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.foreground,
                               root.bar ? root.bar.urgent : Color.accent)
          : (mouse.containsMouse
              ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.foreground,
                                   root.bar ? root.bar.urgent : Color.accent)
              : "transparent")

      Behavior on color { ColorAnimation { duration: 140 } }
    }

    Kirigami.Icon {
      anchors.centerIn: parent
      width: Style.space(17)
      height: width
      source: "computer"
      opacity: root.showingDesktop ? 1 : 0.82
      scale: mouse.containsMouse ? 1.1 : 1

      Behavior on opacity { NumberAnimation { duration: 140 } }
      Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: root.toggleDesktop()
      onEntered: if (root.bar)
        root.bar.showTooltip(button, root.showingDesktop ? "Restore windows" : "Show desktop")
      onExited: if (root.bar) root.bar.hideTooltip(button)
    }
  }
}
