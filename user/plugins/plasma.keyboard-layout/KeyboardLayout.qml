import QtQuick
import org.kde.plasma.workspace.keyboardlayout
import qs.Ui

BarWidget {
  id: root
  moduleName: "plasma.keyboard-layout"

  readonly property bool hasMultipleLayouts: keyboardLayout.layoutsList.length > 1
  readonly property var currentLayout: keyboardLayout.layout < keyboardLayout.layoutsList.length
    ? keyboardLayout.layoutsList[keyboardLayout.layout]
    : null
  readonly property string layoutLabel: shortLabel(currentLayout)
  readonly property string layoutDescription: currentLayout
    ? String(currentLayout.longName || currentLayout.displayName || currentLayout.shortName || "")
    : ""

  function shortLabel(layout) {
    if (!layout) return ""

    var name = String(layout.shortName || "").trim().toLowerCase()
    // The XKB code identifies the US keymap, while the bar is communicating
    // the language selected by this layout pair.
    if (name === "us") return "EN"
    return name.slice(0, 3).toUpperCase()
  }

  visible: hasMultipleLayouts && layoutLabel !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  KeyboardLayout {
    id: keyboardLayout
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    horizontalMargin: 6
    tooltipText: root.layoutDescription + "\nLeft-click: next layout · Right-click: previous layout"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) keyboardLayout.switchToPreviousLayout()
      else if (buttonCode === Qt.LeftButton) keyboardLayout.switchToNextLayout()
    }

    onWheelMoved: function(delta) {
      if (delta > 0) keyboardLayout.switchToPreviousLayout()
      else if (delta < 0) keyboardLayout.switchToNextLayout()
    }
  }
}
