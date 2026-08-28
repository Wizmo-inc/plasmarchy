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
  property var contextLauncher: null

  function normalizedDesktopId(value) {
    return String(value || "").replace(/\.desktop$/, "").toLowerCase()
  }

  function taskForLauncher(launcher) {
    var wanted = normalizedDesktopId(launcher ? launcher.desktopId : "")
    if (!wanted) return null
    for (var i = 0; i < tasks.length; ++i) {
      if (normalizedDesktopId(tasks[i].desktopId) === wanted) return tasks[i]
    }
    return null
  }

  function launcherForTask(task) {
    var wanted = normalizedDesktopId(task ? task.desktopId : "")
    if (!wanted) return null
    for (var i = 0; i < launchers.length; ++i) {
      if (normalizedDesktopId(launchers[i].desktopId) === wanted) return launchers[i]
    }
    return null
  }

  function unpinnedTasks() {
    var represented = {}
    var remaining = []
    for (var i = 0; i < tasks.length; ++i) {
      var id = normalizedDesktopId(tasks[i].desktopId)
      if (id && launcherForTask(tasks[i]) && !represented[id]) {
        represented[id] = true
      } else {
        remaining.push(tasks[i])
      }
    }
    return remaining
  }

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
        minimized: fields[3] === "true",
        desktopId: fields[4] || "",
        appName: fields[5] || ""
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

  function requestPin(task) {
    if (!task || !task.desktopId) return
    Quickshell.execDetached([
      Quickshell.env("HOME") + "/.local/bin/plasmarchy-quicklaunch",
      "pin", task.desktopId, task.appName || task.title, task.icon
    ])
  }

  function requestUnpin(launcher) {
    if (!launcher || !launcher.desktopId) return
    Quickshell.execDetached([
      Quickshell.env("HOME") + "/.local/bin/plasmarchy-quicklaunch",
      "unpin", launcher.desktopId, launcher.title || "Application", launcher.icon || ""
    ])
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
    width: Style.space(190)
    popupType: QQC.Popup.Window
    modal: false
    closePolicy: QQC.Popup.CloseOnEscape
               | QQC.Popup.CloseOnPressOutside
    padding: Style.space(5)

    background: Rectangle {
      color: Color.menu.background
      radius: Style.cornerRadius
      border.width: 1
      border.color: Color.menu.border
    }

    QQC.MenuItem {
      id: pinAction
      visible: root.contextTask !== null
               && root.contextLauncher === null
               && Boolean(root.contextTask.desktopId)
               && root.launcherForTask(root.contextTask) === null
      height: visible ? Style.space(38) : 0
      text: "Pin to Plasmarchy bar"
      onTriggered: root.requestPin(root.contextTask)
      contentItem: Text {
        text: pinAction.text
        color: pinAction.highlighted ? Color.menu.selectedText : Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      background: Rectangle {
        color: pinAction.highlighted ? Color.menu.selectedBackground : "transparent"
        radius: Style.cornerRadius
      }
    }

    QQC.MenuItem {
      id: unpinAction
      visible: root.contextLauncher !== null
      height: visible ? Style.space(38) : 0
      text: "Unpin from Plasmarchy bar"
      onTriggered: root.requestUnpin(root.contextLauncher)
      contentItem: Text {
        text: unpinAction.text
        color: unpinAction.highlighted ? Color.menu.selectedText : Color.menu.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
      background: Rectangle {
        color: unpinAction.highlighted ? Color.menu.selectedBackground : "transparent"
        radius: Style.cornerRadius
      }
    }

    QQC.MenuItem {
      id: closeAction
      visible: root.contextTask !== null
      height: visible ? Style.space(38) : 0
      text: "Close window"
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
        readonly property var matchingTask: root.taskForLauncher(modelData)

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

        Rectangle {
          visible: launcher.matchingTask !== null
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 1
          width: launcher.matchingTask && launcher.matchingTask.minimized ? Style.space(5) : Style.space(12)
          height: 2
          radius: 1
          color: root.bar ? root.bar.urgent : Color.accent
          opacity: launcher.matchingTask && launcher.matchingTask.minimized ? 0.45 : 1
        }

        MouseArea {
          id: launcherMouse
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor

          onClicked: function(event) {
            if (event.button === Qt.RightButton) {
              if (root.bar) root.bar.hideTooltip(launcher)
              root.contextLauncher = launcher.modelData
              root.contextTask = launcher.matchingTask
              taskMenu.popup(
                launcher,
                Math.round((launcher.width - taskMenu.width) / 2),
                -taskMenu.implicitHeight - Style.space(6)
              )
            } else if (event.button === Qt.MiddleButton && launcher.matchingTask) {
              root.requestCloseTask(launcher.matchingTask)
            } else if (launcher.matchingTask) {
              root.activateTask(launcher.matchingTask)
            } else {
              root.launchApp(launcher.modelData)
            }
          }
          onEntered: if (root.bar)
            root.bar.showTooltip(
              launcher,
              launcher.matchingTask
                ? launcher.modelData.title + (launcher.matchingTask.minimized ? " · minimized" : " · open")
                : "Launch " + (launcher.modelData.title || "application")
            )
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
      model: root.unpinnedTasks()

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
              root.contextLauncher = null
              taskMenu.popup(
                task,
                Math.round((task.width - taskMenu.width) / 2),
                -taskMenu.implicitHeight - Style.space(6)
              )
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
