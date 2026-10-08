import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property real contentPreferredWidth: 320 * Style.uiScaleRatio
    property real contentPreferredHeight: 96 * Style.uiScaleRatio
    readonly property var geometryPlaceholder: root
    readonly property bool allowAttach: true

    property real level: 0
    property real target: 0

    anchors.fill: parent

    Process {
        id: reader
        command: ["brightnessctl", "-d", "kbd_backlight", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",");
                if (f.length >= 5 && Number(f[4]) > 0)
                    root.level = Number(f[2]) / Number(f[4]);
            }
        }
    }

    Process {
        id: writer
    }

    // Coalesces slider drags into at most one brightnessctl run at a time.
    Timer {
        id: apply
        interval: 40
        onTriggered: {
            if (writer.running) {
                restart();
                return;
            }
            writer.command = ["brightnessctl", "-q", "-d", "kbd_backlight", "set", Math.round(root.target * 100) + "%"];
            writer.running = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
            text: "Keyboard backlight"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightBold
        }

        NValueSlider {
            Layout.fillWidth: true
            from: 0
            to: 1
            stepSize: 0.05
            value: root.level
            text: Math.round(value * 100) + "%"
            onMoved: value => {
                root.level = value;
                root.target = value;
                apply.restart();
            }
        }
    }
}
