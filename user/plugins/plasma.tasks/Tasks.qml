import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.tasks"

  property var launchers: setting("launchers", [
    { title: "Files", icon: "system-file-manager", command: ["dolphin"] },
    { title: "Terminal", icon: "utilities-terminal", command: ["omarchy-launch-terminal"] },
    { title: "Google Chrome", icon: "google-chrome", command: ["omarchy-launch-browser"] }
  ])
  property var tasks: []
  property string lastActivatedId: ""
  property var contextTask: null

  function refresh() {
    if (!taskQuery.running) taskQuery.running = true
  }

  function launchApp(launcher) {
    if (!launcher || !launcher.command || launcher.command.length === 0) return
    Quickshell.execDetached(launcher.command)
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

  function requestCloseTask(task) {
    if (!task) return
    contextTask = task
    Quickshell.execDetached([
      "qdbus6", "org.kde.KWin", "/WindowsRunner",
      "org.kde.krunner1.Run", task.id, ""
    ])
    closeDelay.restart()
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

  Timer {
    id: closeDelay
    interval: 180
    repeat: false
    onTriggered: {
      Quickshell.execDetached([
        "qdbus6", "org.kde.kglobalaccel", "/component/kwin",
        "org.kde.kglobalaccel.Component.invokeShortcut", "Window Close"
      ])
      root.lastActivatedId = ""
      refreshDelay.restart()
    }
  }

  QQC.Menu {
    id: taskMenu
    width: Style.space(120)
    popupType: QQC.Popup.Window
    modal: false
    closePolicy: QQC.Popup.CloseOnEscape
               | QQC.Popup.CloseOnPressOutside
               | QQC.Popup.CloseOnReleaseOutside
    padding: Style.space(5)

    background: Rectangle {
      color: Color.menu.background
      radius: Style.cornerRadius
      border.width: 1
      border.color: Color.menu.border
    }

    QQC.MenuItem {
      id: closeAction
      text: "Close window"
      height: Style.space(38)
      onTriggered: root.requestCloseTask(root.contextTask)
      contentItem: Text {
        text: closeAction.text
        color: closeAction.highlighted ? Color.menu.selectedText : Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      background: Rectangle {
        color: closeAction.highlighted ? Color.menu.selectedBackground : "transparent"
        radius: Style.cornerRadius
      }
    }
  }

  visible: !vertical && (launchers.length > 0 || tasks.length > 0)
  implicitWidth: visible ? taskRow.implicitWidth : 0
  implicitHeight: barSize

  Row {
    id: taskRow
    anchors.fill: parent
    spacing: Style.space(2)

    Repeater {
      model: root.launchers

      delegate: Item {
        id: launcher
        required property var modelData

        width: root.barSize
        height: root.barSize

        Rectangle {
          anchors.fill: parent
          anchors.margins: Style.space(2)
          radius: Style.cornerRadius
          color: launcherMouse.containsMouse
              ? Style.hoverFillFor(root.bar ? root.bar.barForeground : Color.foreground,
                                   root.bar ? root.bar.urgent : Color.accent)
              : "transparent"

          Behavior on color { ColorAnimation { duration: 140 } }
        }

        Kirigami.Icon {
          anchors.centerIn: parent
          width: Style.space(18)
          height: width
          source: launcher.modelData.icon || "application-x-executable"
          scale: launcherMouse.containsMouse ? 1.13 : 1

          Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
          }
        }

        MouseArea {
          id: launcherMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: root.launchApp(launcher.modelData)
          onEntered: if (root.bar)
            root.bar.showTooltip(launcher, "Launch " + (launcher.modelData.title || "application"))
          onExited: if (root.bar) root.bar.hideTooltip(launcher)
        }
      }
    }

    Rectangle {
      visible: root.launchers.length > 0 && root.tasks.length > 0
      width: visible ? 1 : 0
      height: Style.space(16)
      anchors.verticalCenter: parent.verticalCenter
      radius: 1
      color: root.bar ? root.bar.barForeground : Color.foreground
      opacity: 0.22
    }

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
            if (event.button === Qt.RightButton) {
              if (root.bar) root.bar.hideTooltip(task)
              root.contextTask = task.modelData
              taskMenu.popup()
            } else if (event.button === Qt.MiddleButton) {
              root.requestCloseTask(task.modelData)
            } else {
              root.activateTask(task.modelData)
            }
          }

          onEntered: if (root.bar)
            root.bar.showTooltip(task, task.modelData.title + (task.minimized ? " · minimized" : ""))
          onExited: if (root.bar) root.bar.hideTooltip(task)
        }
      }
    }
  }
}
