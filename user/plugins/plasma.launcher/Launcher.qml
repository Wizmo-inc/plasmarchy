import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.launcher"

  function openOmarchyMenu(route) {
    Quickshell.execDetached([
      "qs", "ipc", "-n", "-p",
      Quickshell.env("HOME") + "/.config/quickshell/plasma-omarchy",
      "call", "--", "shell", "toggle", "omarchy.menu",
      JSON.stringify({ "menu": route || "root" })
    ])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "omarchy"
    horizontalMargin: 8
    tooltipText: "Applications"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton)
        Quickshell.execDetached(["krunner"])
      else if (buttonCode === Qt.MiddleButton)
        Quickshell.execDetached(["xdg-terminal-exec"])
      else
        root.openOmarchyMenu("root")
    }
  }
}
