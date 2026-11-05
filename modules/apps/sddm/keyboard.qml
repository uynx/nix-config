import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Components
import QtQuick.Layouts

KeyboardLayout {
    inputMode: InputEngine.InputMode.Latin
    keyWeight: 160
    readonly property real normalKeyWidth: normalKey.width
    readonly property bool shifted: InputContext.shiftActive && !InputContext.capsLockActive
    KeyboardRow {
        Key {
            key: shifted ? Qt.Key_AsciiTilde : Qt.Key_QuoteLeft
            text: shifted ? "~" : "`"
        }
        Key {
            key: shifted ? Qt.Key_Exclam : Qt.Key_1
            text: shifted ? "!" : "1"
        }
        Key {
            key: shifted ? Qt.Key_At : Qt.Key_2
            text: shifted ? "@" : "2"
        }
        Key {
            key: shifted ? Qt.Key_NumberSign : Qt.Key_3
            text: shifted ? "#" : "3"
        }
        Key {
            key: shifted ? Qt.Key_Dollar : Qt.Key_4
            text: shifted ? "$" : "4"
        }
        Key {
            key: shifted ? Qt.Key_Percent : Qt.Key_5
            text: shifted ? "%" : "5"
        }
        Key {
            key: shifted ? Qt.Key_AsciiCircum : Qt.Key_6
            text: shifted ? "^" : "6"
        }
        Key {
            key: shifted ? Qt.Key_Ampersand : Qt.Key_7
            text: shifted ? "&" : "7"
        }
        Key {
            key: shifted ? Qt.Key_Asterisk : Qt.Key_8
            text: shifted ? "*" : "8"
        }
        Key {
            key: shifted ? Qt.Key_ParenLeft : Qt.Key_9
            text: shifted ? "(" : "9"
        }
        Key {
            key: shifted ? Qt.Key_ParenRight : Qt.Key_0
            text: shifted ? ")" : "0"
        }
        Key {
            key: shifted ? Qt.Key_Underscore : Qt.Key_Minus
            text: shifted ? "_" : "-"
        }
        Key {
            key: shifted ? Qt.Key_Plus : Qt.Key_Equal
            text: shifted ? "+" : "="
        }
        BackspaceKey {
            weight: 1.6 * normalKeyWidth
            Layout.fillWidth: false
        }
    }
    KeyboardRow {
        Key {
            key: Qt.Key_Tab
            text: "\t"
            displayText: "Tab"
            weight: 1.5 * normalKeyWidth
            Layout.fillWidth: false
        }
        Key {
            id: normalKey
            key: Qt.Key_Q
            text: "q"
        }
        Key {
            key: Qt.Key_W
            text: "w"
        }
        Key {
            key: Qt.Key_E
            text: "e"
        }
        Key {
            key: Qt.Key_R
            text: "r"
        }
        Key {
            key: Qt.Key_T
            text: "t"
        }
        Key {
            key: Qt.Key_Y
            text: "y"
        }
        Key {
            key: Qt.Key_U
            text: "u"
        }
        Key {
            key: Qt.Key_I
            text: "i"
        }
        Key {
            key: Qt.Key_O
            text: "o"
        }
        Key {
            key: Qt.Key_P
            text: "p"
        }
        Key {
            key: shifted ? Qt.Key_BraceLeft : Qt.Key_BracketLeft
            text: shifted ? "{" : "["
        }
        Key {
            key: shifted ? Qt.Key_BraceRight : Qt.Key_BracketRight
            text: shifted ? "}" : "]"
        }
        Key {
            key: shifted ? Qt.Key_Bar : Qt.Key_Backslash
            text: shifted ? "|" : "\\"
        }
    }
    KeyboardRow {
        FillerKey {
            weight: 0.8 * normalKeyWidth
            Layout.fillWidth: false
        }
        Key {
            key: Qt.Key_A
            text: "a"
        }
        Key {
            key: Qt.Key_S
            text: "s"
        }
        Key {
            key: Qt.Key_D
            text: "d"
        }
        Key {
            key: Qt.Key_F
            text: "f"
        }
        Key {
            key: Qt.Key_G
            text: "g"
        }
        Key {
            key: Qt.Key_H
            text: "h"
        }
        Key {
            key: Qt.Key_J
            text: "j"
        }
        Key {
            key: Qt.Key_K
            text: "k"
        }
        Key {
            key: Qt.Key_L
            text: "l"
        }
        Key {
            key: shifted ? Qt.Key_Colon : Qt.Key_Semicolon
            text: shifted ? ":" : ";"
        }
        Key {
            key: shifted ? Qt.Key_QuoteDbl : Qt.Key_Apostrophe
            text: shifted ? "\"" : "'"
        }
        EnterKey {
            weight: 1.8 * normalKeyWidth
            Layout.fillWidth: false
        }
    }
    KeyboardRow {
        ShiftKey {
            weight: 2.0 * normalKeyWidth
            Layout.fillWidth: false
        }
        Key {
            key: Qt.Key_Z
            text: "z"
        }
        Key {
            key: Qt.Key_X
            text: "x"
        }
        Key {
            key: Qt.Key_C
            text: "c"
        }
        Key {
            key: Qt.Key_V
            text: "v"
        }
        Key {
            key: Qt.Key_B
            text: "b"
        }
        Key {
            key: Qt.Key_N
            text: "n"
        }
        Key {
            key: Qt.Key_M
            text: "m"
        }
        Key {
            key: shifted ? Qt.Key_Less : Qt.Key_Comma
            text: shifted ? "<" : ","
        }
        Key {
            key: shifted ? Qt.Key_Greater : Qt.Key_Period
            text: shifted ? ">" : "."
        }
        Key {
            key: shifted ? Qt.Key_Question : Qt.Key_Slash
            text: shifted ? "?" : "/"
        }
        ShiftKey {
            weight: 2.0 * normalKeyWidth
            Layout.fillWidth: false
        }
    }
    KeyboardRow {
        HideKeyboardKey {
            weight: 1.5 * normalKeyWidth
            Layout.fillWidth: false
        }
        SpaceKey {
        }
    }
}
