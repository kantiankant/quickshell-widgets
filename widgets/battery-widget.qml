
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {

    PanelWindow {
        id: win

        // ── Corner cycling (0=BR, 1=BL, 2=TL, 3=TR) ───────────────────
        property int corner:  1 

        anchors.bottom: corner === 0 || corner === 1
        anchors.top:    corner === 2 || corner === 3
        anchors.right:  corner === 0 || corner === 3
        anchors.left:   corner === 1 || corner === 2

        margins {
            bottom: (corner === 0 || corner === 1) ? 16 : 0
            top:    (corner === 2 || corner === 3) ? 16 : 0
            right:  (corner === 0 || corner === 3) ? 16 : 0
            left:   (corner === 1 || corner === 2) ? 16 : 0
        }

        // ── Size — clamp between 80 and 240, starts at 120 ────────────
        property real widgetSize: 200 
        readonly property real minSize: 80
        readonly property real maxSize: 240

        implicitWidth:  widgetSize
        implicitHeight: widgetSize
        color: "#00000000"

        WlrLayershell.layer:         WlrLayer.Bottom
        WlrLayershell.exclusiveZone: 0


        // ── Battery state ──────────────────────────────────────────────
        property int    capacity: 100
        property string status:   "Unknown"
        property bool   charging: status === "Charging" || status === "Full"

        Process {
            command: [
                "bash", "-c",
                "while true; do " +
                "  cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 100; " +
                "  cat /sys/class/power_supply/BAT0/status   2>/dev/null || echo Unknown; " +
                "  sleep 30; " +
                "done"
            ]
            running: true
            stdout: SplitParser {
                property bool nextIsStatus: false
                onRead: (line) => {
                    if (!nextIsStatus) { win.capacity = parseInt(line.trim()) || 0; nextIsStatus = true }
                    else               { win.status   = line.trim();                nextIsStatus = false }
                }
            }
        }

        // ── Card background ────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: win.widgetSize * 0.20   // radius scales with size, naturally

            color: Qt.rgba(1, 1, 1, 0.15)

            Rectangle {
                anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter }
                width: parent.width * 0.5; height: 1; radius: 1
                color: Qt.rgba(1, 1, 1, 0.30)
            }

            // ── Left-click: cycle corners. Right-click drag: resize. ───
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // left click — cycle corners
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton)
                        win.corner = (win.corner + 1) % 4
                }

                // right-click drag — resize
                property real dragStartX:    0
                property real dragStartY:    0
                property real dragStartSize: 0

                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        dragStartX    = mouse.x
                        dragStartY    = mouse.y
                        dragStartSize = win.widgetSize
                    }
                }

                onPositionChanged: (mouse) => {
                    if (pressedButtons & Qt.RightButton) {
                        // Use the diagonal drag delta as the resize amount.
                        // Dragging down-right = bigger; up-left = smaller.
                        var dx    = mouse.x - dragStartX
                        var dy    = mouse.y - dragStartY
                        var delta = (dx + dy) / 2
                        var newSize = dragStartSize + delta
                        win.widgetSize = Math.max(win.minSize, Math.min(win.maxSize, newSize))
                    }
                }
            }

            // ── Arc canvas — scales with widget ───────────────────────
            Canvas {
                id: arc
                anchors.centerIn: parent
                width:  win.widgetSize * 0.733   // ~88 at default 120px
                height: win.widgetSize * 0.733

                readonly property real  arcRadius:  width * 0.432  // ~38 at 88px
                readonly property real  lineWidth:  Math.max(4, width * 0.08)
                readonly property color trackColor: Qt.rgba(0, 0, 0, 0.10)
                readonly property color fillColor:  win.capacity <= 20
                                                        ? "#ff453a"
                                                        : "#30d158"

                property real animatedCapacity: win.capacity
                Behavior on animatedCapacity {
                    NumberAnimation { duration: 900; easing.type: Easing.OutCubic }
                }

                onAnimatedCapacityChanged: requestPaint()
                onWidthChanged:            requestPaint()
                Component.onCompleted:     Qt.callLater(requestPaint)
                Connections {
                    target: win
                    function onCapacityChanged()   { arc.requestPaint() }
                    function onChargingChanged()   { arc.requestPaint() }
                    function onWidgetSizeChanged() { arc.requestPaint() }
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var cx = width  / 2
                    var cy = height / 2
                    var r  = arcRadius
                    var lw = lineWidth

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = trackColor
                    ctx.lineWidth   = lw
                    ctx.lineCap     = "round"
                    ctx.stroke()

                    var sweep = (animatedCapacity / 100) * Math.PI * 2
                    if (sweep > 0.01) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + sweep)
                        ctx.strokeStyle = fillColor
                        ctx.lineWidth   = lw
                        ctx.lineCap     = "round"
                        ctx.stroke()
                    }
                }
            }

            // ── Laptop icon ────────────────────────────────────────────
            Text {
                anchors { centerIn: parent; verticalCenterOffset: -(win.widgetSize * 0.05) }
                text: "\uf109"
                font.family:    "Symbols Nerd Font"
                font.pixelSize: win.widgetSize * 0.183   // ~22 at 120px
                color: win.capacity <= 20 ? "#ff453a" : Qt.rgba(0, 0, 0, 0.75)
            }

            // ── Percentage label ───────────────────────────────────────
            Text {
                anchors { centerIn: parent; verticalCenterOffset: win.widgetSize * 0.15 }
                text: win.capacity + "%"
                font.family:    "SF Pro Display"
                font.pixelSize: win.widgetSize * 0.092   // ~11 at 120px
                font.weight:    Font.Medium
                color: win.capacity <= 20 ? "#ff453a" : Qt.rgba(0, 0, 0, 0.50)
            }

            // ── Charging bolt ──────────────────────────────────────────
            Text {
                visible: win.charging
                anchors { right: parent.right; top: parent.top; margins: win.widgetSize * 0.083 }
                text: "\uf0e7"
                font.family:    "Symbols Nerd Font"
                font.pixelSize: win.widgetSize * 0.092
                color: "#30d158"
            }
        }
    }
}
