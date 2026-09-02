import QtQuick
import Quickshell
import Quickshell.Io
import org.kde.kirigami as Kirigami
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "plasma.tasks"

  // Panel owns the reliable layer-shell popup lifecycle; keep the two bar
  // geometry conveniences that BarWidget previously supplied.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  property var launchers: setting("launchers", [
    { title: "Files", icon: "system-file-manager", command: ["dolphin"] },
    { title: "Terminal", icon: "utilities-terminal", command: ["omarchy-launch-terminal"] },
    { title: "Google Chrome", icon: "google-chrome", command: ["omarchy-launch-browser"] }
  ])
  property var tasks: []
  property string lastActivatedId: ""
  property var contextTask: null
  property var contextLauncher: null
  property real contextAnchorX: width / 2

  function showTaskMenu(anchor, task, launcher) {
    if (!anchor) return
    var point = anchor.mapToItem(root, anchor.width / 2, 0)
    contextAnchorX = Math.max(0, Math.min(root.width, point.x))
    contextTask = task
    contextLauncher = launcher
    open()
  }

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
    close()
    contextTask = task
    Quickshell.execDetached([
      "qdbus6", "org.kde.KWin", "/WindowsRunner",
      "org.kde.krunner1.Run", task.id, ""
    ])
    closeDelay.restart()
  }

  function requestPin(task) {
    if (!task || !task.desktopId) return
    close()
    Quickshell.execDetached([
      Quickshell.env("HOME") + "/.local/bin/plasmarchy-quicklaunch",
      "pin", task.desktopId, task.appName || task.title, task.icon
    ])
  }

  function requestUnpin(launcher) {
    if (!launcher || !launcher.desktopId) return
    close()
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

  // Keep the anchor alive while the task list refreshes every 1.5 seconds.
  // Anchoring directly to a Repeater delegate lets that delegate disappear
  // underneath an open menu when a fresh KWin listing replaces the model.
  Item {
    id: contextMenuAnchor
    x: root.contextAnchorX
    y: 0
    width: 1
    height: root.height
  }

  KeyboardPanel {
    id: taskMenu
    anchorItem: contextMenuAnchor
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: menuKeys
    contentWidth: taskMenu.fittedContentWidth(Style.space(190))
    contentHeight: taskMenu.fittedContentHeight(taskActionColumn.implicitHeight)

    PanelKeyCatcher {
      id: menuKeys
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: taskActionColumn
        width: parent.width
        spacing: Style.space(3)

        TaskMenuAction {
          shown: root.contextTask !== null
                 && root.contextLauncher === null
                 && Boolean(root.contextTask.desktopId)
                 && root.launcherForTask(root.contextTask) === null
          label: "Pin to Plasmarchy bar"
          onTriggered: root.requestPin(root.contextTask)
        }

        TaskMenuAction {
          shown: root.contextLauncher !== null
          label: "Unpin from Plasmarchy bar"
          onTriggered: root.requestUnpin(root.contextLauncher)
        }

        TaskMenuAction {
          shown: root.contextTask !== null
          label: "Close window"
          onTriggered: root.requestCloseTask(root.contextTask)
        }
      }
    }
  }

  component TaskMenuAction: Rectangle {
    id: actionRow

    property string label: ""
    property bool shown: true
    signal triggered()

    visible: shown
    width: parent ? parent.width : 0
    height: visible ? Style.space(38) : 0
    radius: Style.cornerRadius
    color: actionMouse.containsMouse
      ? Style.hoverFillFor(Color.popups.text, Color.accent)
      : "transparent"

    Text {
      anchors.fill: parent
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      text: actionRow.label
      color: actionMouse.containsMouse ? Color.accent : Color.popups.text
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: actionRow.triggered()
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
              root.showTaskMenu(launcher, launcher.matchingTask, launcher.modelData)
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
              root.showTaskMenu(task, task.modelData, null)
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
