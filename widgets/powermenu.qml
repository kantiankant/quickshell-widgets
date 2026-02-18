
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property string armedButton: ""

    PanelWindow {
        id: win

        anchors.top:    true
        anchors.bottom: true
        anchors.left:   true
        anchors.right:  true

        color: "#00000000"

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // ── Dim backdrop ───────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            focus: true

            Keys.onEscapePressed: Qt.quit()

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (root.armedButton !== "") {
                        root.armedButton = ""   // disarm on backdrop click
                    } else {
                        Qt.quit()               // dismiss if nothing armed
                    }
                }
            }

            // ── Frosted glass card ─────────────────────────────────────
            Rectangle {
                anchors.centerIn: parent
                width:  320
                height: column.height + 48
                radius: 20
                color:  Qt.rgba(1, 1, 1, 0.18)
                border.color: Qt.rgba(1, 1, 1, 0.30)
                border.width: 1

                Rectangle {
                    anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                    width: parent.width * 0.5; height: 1; radius: 1
                    color: Qt.rgba(1, 1, 1, 0.40)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    id: column
                    anchors {
                        top: parent.top
                        topMargin: 24
                        horizontalCenter: parent.horizontalCenter
                    }
                    spacing: 10
                    width: 272

                    PowerButton {
                        buttonId: "logout"
                        label:    "Logout"
                        icon:     "\uf011"
                        onConfirmed: {
                            runner.command = ["hyprctl", "dispatch", "exit", "0"]
                            runner.running = true
                        }
                    }

                    PowerButton {
                        buttonId: "reboot"
                        label:    "Reboot"
                        icon:     "\uf021"
                        onConfirmed: {
                            runner.command = ["systemctl", "reboot"]
                            runner.running = true
                        }
                    }

                    PowerButton {
                        buttonId: "poweroff"
                        label:    "Power Off"
                        icon:     "\uf011"
                        onConfirmed: {
                            runner.command = ["systemctl", "poweroff"]
                            runner.running = true
                        }
                    }
                }
            }
        }

        Process {
            id: runner
            running: false
        }
    }

    // ── Button component ───────────────────────────────────────────────
    component PowerButton: Rectangle {
        id: btn

        signal confirmed

        property string buttonId: ""
        property string label:    ""
        property string icon:     ""

        // Armed if root says we are. Disarms automatically when
        // root.armedButton changes to something else. No signals needed.
        property bool armed: root.armedButton === buttonId

        width:  parent.width
        height: 52
        radius: 14

        color: armed
               ? Qt.rgba(1, 0.3, 0.3, 0.30)
               : hovered
                 ? Qt.rgba(1, 1, 1, 0.22)
                 : Qt.rgba(1, 1, 1, 0.10)

        border.color: armed
                      ? Qt.rgba(1, 0.4, 0.4, 0.50)
                      : Qt.rgba(1, 1, 1, 0.20)
        border.width: 1

        property bool hovered: false

        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors {
                left: parent.left
                leftMargin: 18
                verticalCenter: parent.verticalCenter
            }
            spacing: 14

            Text {
                text: btn.icon
                font.family:    "Symbols Nerd Font"
                font.pixelSize: 18
                color: btn.armed ? Qt.rgba(1, 0.6, 0.6, 1) : Qt.rgba(0, 0, 0, 0.70)
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: btn.armed ? btn.label + " — confirm?" : btn.label
                font.family:    "SF Pro Display"
                font.pixelSize: 15
                font.weight:    Font.Medium
                color: btn.armed ? Qt.rgba(1, 0.5, 0.5, 1) : Qt.rgba(0, 0, 0, 0.80)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered:  btn.hovered = true
            onExited:   btn.hovered = false
            onClicked: {
                if (btn.armed) {
                    btn.confirmed()
                } else {
                    root.armedButton = btn.buttonId
                }
            }
        }
    }
}
