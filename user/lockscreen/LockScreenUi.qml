// SPDX-License-Identifier: MIT
// Minimal Omarchy frontend for Plasma's existing screen-lock authenticator.

import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.kscreenlocker as ScreenLocker

Item {
    id: lockScreenUi

    property bool loginFailed: false
    property string statusMessage: ""

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.View

    function clearPassword() {
        password.text = ""
        password.forceActiveFocus()
    }

    function submitPassword() {
        if (password.text.length > 0) {
            loginFailed = false
            statusMessage = ""
            authenticator.respond(password.text)
        }
    }

    Connections {
        target: authenticator

        function onFailed(kind) {
            lockScreenUi.loginFailed = true
            lockScreenUi.statusMessage = kind === ScreenLocker.Authenticator.Fingerprint
                ? "Fingerprint not recognized"
                : "Unlocking failed"
            lockScreenUi.clearPassword()
            authenticator.startAuthenticating()
        }

        function onSucceeded() {
            Qt.quit()
        }

        function onInfoMessageChanged() {
            lockScreenUi.statusMessage = authenticator.infoMessage
        }

        function onErrorMessageChanged() {
            lockScreenUi.statusMessage = authenticator.errorMessage
        }

        function onPromptChanged() {
            lockScreenUi.statusMessage = authenticator.prompt
        }

        function onPromptForSecretChanged() {
            password.forceActiveFocus()
        }
    }

    Connections {
        target: root

        function onClearPassword() {
            lockScreenUi.clearPassword()
        }

        function onNotificationRepeated() {
            failurePulse.restart()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
    }

    Column {
        id: loginColumn
        anchors.centerIn: parent
        spacing: 40

        Image {
            source: "assets/logo.png"
            width: Math.min(sourceSize.width, lockScreenUi.width * 0.65)
            height: sourceSize.width > 0
                ? Math.round(width * sourceSize.height / sourceSize.width)
                : 0
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15

            Image {
                source: lockScreenUi.loginFailed
                    ? "assets/lock-failed.png"
                    : "assets/lock.png"
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
                    source: lockScreenUi.loginFailed
                        ? "assets/entry-failed.png"
                        : "assets/entry.png"
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
                            source: "assets/bullet.png"
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
                    text: PasswordSync.password

                    onTextChanged: {
                        lockScreenUi.loginFailed = false
                        lockScreenUi.statusMessage = ""
                    }
                    onAccepted: lockScreenUi.submitPassword()
                }

                Binding {
                    target: PasswordSync
                    property: "password"
                    value: password.text
                }
            }
        }

        Text {
            width: Math.min(480, lockScreenUi.width * 0.8)
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: lockScreenUi.statusMessage || (
                authenticator.authenticatorTypes & ScreenLocker.Authenticator.Fingerprint
                    ? "Enter password or use fingerprint"
                    : "Enter password to unlock"
            )
            color: lockScreenUi.loginFailed
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.disabledTextColor
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
        }
    }

    SequentialAnimation {
        id: failurePulse
        NumberAnimation {
            target: loginColumn
            property: "opacity"
            to: 0.4
            duration: 90
        }
        NumberAnimation {
            target: loginColumn
            property: "opacity"
            to: 1
            duration: 160
        }
    }

    Component.onCompleted: {
        password.forceActiveFocus()
        authenticator.startAuthenticating()
    }
}
