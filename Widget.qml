import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar indicator for the bluetooth-mouse-touchpad automation (bin/, installed
// as a systemd --user service). Draws a small mouse pictogram (outline body +
// button-split line) directly in QML rather than using a Nerd Font glyph --
// no font-coverage gamble, guaranteed to render. Shown in the theme's normal
// foreground color while the trackpad is in control, and in the accent/urgent
// color while a Bluetooth mouse has taken over. Click toggles the whole
// automation on/off -- the same action as the Trigger > Toggle menu entry --
// so there is exactly one place the enable/disable command lives.
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

  readonly property color iconColor: root.touchpadDisabled
    ? (root.bar ? root.bar.urgent : Color.accent)
    : (root.bar ? root.bar.barForeground : Color.foreground)

  // At real bar-icon size (~10x14px) an outline with `radius: width/2` turns
  // into an illegible blob under anti-aliasing -- confirmed by inspecting
  // rendered pixels directly, not by eyeballing a screenshot. A solid filled
  // shape with a background-colored notch (real contrast, not a thin
  // foreground line that blurs away) reads clearly as a mouse body instead.
  Item {
    id: mouseIcon
    anchors.centerIn: parent
    width: 10
    height: 14

    Rectangle {
      id: body
      anchors.fill: parent
      radius: 3
      color: root.iconColor
    }

    Rectangle {
      width: 2
      height: 4
      anchors.top: body.top
      anchors.topMargin: 1
      anchors.horizontalCenter: body.horizontalCenter
      color: root.bar ? root.bar.background : Color.background
    }
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
