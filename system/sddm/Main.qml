import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#1a1b26"

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.toLowerCase().indexOf("plasma") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }
  readonly property bool hasMultipleKeyboardLayouts: keyboard.layouts.length > 1
  readonly property var currentKeyboardLayout: keyboard.layouts.length > 0
    ? keyboard.layouts[keyboard.currentLayout]
    : null

  function keyboardLayoutLabel(layout) {
    if (!layout)
      return ""

    var shortName = String(layout.shortName || "").trim().toLowerCase()
    return shortName === "us" ? "EN" : shortName.slice(0, 3).toUpperCase()
  }

  function switchKeyboardLayout() {
    if (!root.hasMultipleKeyboardLayouts)
      return

    // Never leave a partly typed password behind when the keymap changes.
    password.text = ""
    keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
    password.forceActiveFocus()
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: function(event) {
            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Space) {
              root.switchKeyboardLayout()
              event.accepted = true
              return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              sddm.login(root.currentUser, password.text, root.sessionIndex)
              event.accepted = true
            }
          }
        }
      }
    }

    Rectangle {
      width: keyboardLayoutText.implicitWidth + 28
      height: 30
      radius: 5
      anchors.horizontalCenter: parent.horizontalCenter
      visible: root.hasMultipleKeyboardLayouts
      color: keyboardLayoutMouse.containsMouse ? "#25283a" : "transparent"
      border.width: 1
      border.color: keyboardLayoutMouse.containsMouse ? "#a9b1d6" : "#565f89"

      Text {
        id: keyboardLayoutText
        anchors.centerIn: parent
        text: "LANG  " + root.keyboardLayoutLabel(root.currentKeyboardLayout)
        color: "#c0caf5"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        font.bold: true
      }

      MouseArea {
        id: keyboardLayoutMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.switchKeyboardLayout()
      }
    }

  }

  Component.onCompleted: password.forceActiveFocus()
}
