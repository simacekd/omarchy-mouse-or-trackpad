import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar indicator for the bluetooth-mouse-touchpad automation (bin/, installed
// as a systemd --user service). Shows the touchpad icon in the normal
// foreground color while the trackpad is in control, and in the theme's
// urgent/accent color while a Bluetooth mouse has taken over. Click toggles
// the whole automation on/off -- the same action as the Trigger > Toggle menu
// entry -- so there is exactly one place the enable/disable command lives.
//
// State comes from ~/.local/state/omarchy/mouse-or-trackpad.json, written by
// the daemon on every change; `watchChanges` on the FileView means this
// updates the instant the daemon does, no polling.
BarWidget {
  id: root
  moduleName: "simacek.mouse-or-trackpad"

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/mouse-or-trackpad.json"
  readonly property string toggleCommand:
    "systemctl --user is-enabled --quiet bluetooth-mouse-touchpad.service" +
    " && { systemctl --user disable --now bluetooth-mouse-touchpad.service; " +
    "bluetooth-mouse-touchpad --restore; }" +
    " || systemctl --user enable --now bluetooth-mouse-touchpad.service"

  property bool touchpadDisabled: false
  property string mouseName: ""

  implicitWidth: barSize
  implicitHeight: barSize

  function _apply(raw) {
    try {
      var data = JSON.parse(raw)
      root.touchpadDisabled = !!data.touchpadDisabled
      root.mouseName = String(data.mouse || "")
    } catch (e) {
      root.touchpadDisabled = false
      root.mouseName = ""
    }
  }

  function tooltipText() {
    if (root.touchpadDisabled) return "Touchpad disabled — " + (root.mouseName || "Bluetooth mouse") + " connected"
    return "Touchpad active"
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root._apply(text())
    onLoadFailed: root._apply("")
  }

  Text {
    anchors.centerIn: parent
    text: "󰟸"
    color: root.touchpadDisabled ? (root.bar ? root.bar.urgent : Color.accent) : (root.bar ? root.bar.barForeground : Color.foreground)
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.bar) root.bar.run(root.toggleCommand)
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
