import QtQuick
import Quickshell
import Quickshell.Io
import org.kde.kirigami as Kirigami
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.tasks"

  property var tasks: []
  property string lastActivatedId: ""

  function refresh() {
    if (!taskQuery.running) taskQuery.running = true
  }

  function applyListing(output) {
    var next = []
    var lines = String(output || "").split("\n")
    for (var i = 0; i < lines.length; ++i) {
      if (!lines[i].trim()) continue
      var fields = lines[i].split("\t")
      if (fields.length < 4) continue
      next.push({
        id: fields[0],
        title: fields[1] || "Window",
        icon: fields[2] || "application-x-executable",
        minimized: fields[3] === "true"
      })
    }
    tasks = next
  }

  function activateTask(task) {
    if (!task) return

    // KWin keeps focus on the client when its layer-shell bar is clicked. A
    // second click on the task we just activated can therefore use KWin's own
    // minimize action, matching Plasma's normal task-manager toggle.
    if (!task.minimized && lastActivatedId === task.id) {
      Quickshell.execDetached([
        "qdbus6", "org.kde.kglobalaccel", "/component/kwin",
        "org.kde.kglobalaccel.Component.invokeShortcut", "Window Minimize"
      ])
      lastActivatedId = ""
      refreshDelay.restart()
      return
    }

    Quickshell.execDetached([
      "qdbus6", "org.kde.KWin", "/WindowsRunner",
      "org.kde.krunner1.Run", task.id, ""
    ])
    lastActivatedId = task.id
    refreshDelay.restart()
  }

  Process {
    id: taskQuery
    command: [Quickshell.env("HOME") + "/.config/omarchy/plugins/plasma.tasks/tasks.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyListing(text)
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshDelay
    interval: 250
    repeat: false
    onTriggered: root.refresh()
  }

  visible: !vertical && tasks.length > 0
  implicitWidth: visible ? taskRow.implicitWidth : 0
  implicitHeight: barSize

  Row {
    id: taskRow
    anchors.fill: parent
    spacing: Style.space(2)

    Repeater {
      model: root.tasks

      delegate: Item {
        id: task
        required property var modelData
        readonly property bool minimized: modelData.minimized === true

        width: root.barSize
        height: root.barSize

        Rectangle {
          anchors.fill: parent
          anchors.margins: Style.space(2)
          radius: Style.cornerRadius
          color: mouse.containsMouse
              ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.foreground,
                                   root.bar ? root.bar.urgent : Color.accent)
              : "transparent"

          Behavior on color { ColorAnimation { duration: 140 } }
        }

        Kirigami.Icon {
          anchors.centerIn: parent
          width: Style.space(18)
          height: width
          source: task.modelData.icon
          opacity: task.minimized ? 0.52 : 1

          Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          width: task.minimized ? Style.space(5) : Style.space(12)
          height: 2
          radius: 1
          color: root.bar ? root.bar.urgent : Color.accent
          opacity: task.minimized ? 0.45 : 1

          Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: function(event) {
            root.activateTask(task.modelData)
          }

          onEntered: if (root.bar)
            root.bar.showTooltip(task, task.modelData.title + (task.minimized ? " · minimized" : ""))
          onExited: if (root.bar) root.bar.hideTooltip(task)
        }
      }
    }
  }
}
