import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.show-desktop"

  property bool showingDesktop: false
  readonly property bool opened: showingDesktop

  function open() {
    if (!showingDesktop) toggle()
  }

  function close() {
    if (showingDesktop) toggle()
  }

  function toggle() {
    showingDesktop = !showingDesktop
    Quickshell.execDetached([
      "qdbus6", "org.kde.kglobalaccel", "/component/kwin",
      "org.kde.kglobalaccel.Component.invokeShortcut", "Plasmarchy Show Desktop"
    ])
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    fontSize: 16
    horizontalMargin: 8
    active: root.showingDesktop
    tooltipText: root.showingDesktop ? "Restore windows" : "Show desktop"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
