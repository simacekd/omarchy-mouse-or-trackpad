import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar indicator for the bluetooth-mouse-touchpad automation. Extends the same
// BarIndicator base every built-in indicator uses (Stay Awake, Night Light,
// DND, ...), so it gets identical sizing, dim/reveal-on-hover, and click
// behavior for free instead of hand-rolled approximations of them:
//   - full color + always visible while active (a Bluetooth mouse has taken
//     over the trackpad)
//   - dimmed and hidden until hovered while inactive (trackpad in control)
//   - click anywhere on it to toggle the whole automation on/off
//
// The icon itself is drawn with plain QML Rectangles (filled body + a
// background-colored notch) rather than a font glyph, sized to fill the same
// icon canvas every indicator's glyph renders into -- so it matches their
// size exactly without hand-picking pixel dimensions.
//
// State comes from ~/.local/state/omarchy/mouse-or-trackpad.json, written by
// the daemon on every change; `watchChanges` on the FileView means this
// updates the instant the daemon does, no polling.
//
// NOTE for future edits: this plugin is loaded through a symlink
// (~/.config/omarchy/plugins/simacek.mouse-or-trackpad -> ~/plugins/...), and
// the shell's file watcher does not follow symlinks. Edits here will NOT
// hot-reload -- run `omarchy restart shell` and re-check after every change.
BarIndicator {
  id: root
  moduleName: "simacek.mouse-or-trackpad"
  property var settings: ({})

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/mouse-or-trackpad.json"
  readonly property string toggleCommand:
    "systemctl --user is-enabled --quiet bluetooth-mouse-touchpad.service" +
    " && { systemctl --user disable --now bluetooth-mouse-touchpad.service; " +
    "bluetooth-mouse-touchpad --restore; }" +
    " || systemctl --user enable --now bluetooth-mouse-touchpad.service"

  property bool touchpadDisabled: false
  property string mouseName: ""

  active: touchpadDisabled
  activeTooltipText: "Touchpad disabled — " + (mouseName || "Bluetooth mouse") + " connected"
  inactiveTooltipText: "Touchpad active"

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

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root._apply(text())
    onLoadFailed: root._apply("")
  }

  // Fixed pixel sizes, not percentages of the icon canvas -- measured against
  // a screenshot of the real Stay Awake glyph (14x13px) rather than trusted
  // from Style.bar.iconCanvas, which did not match what actually rendered.
  iconComponent: Component {
    Item {
      anchors.fill: parent

      Rectangle {
        id: body
        anchors.centerIn: parent
        width: 7
        height: 9
        radius: 2
        color: root.active ? root.activeColor : root.foreground
      }

      Rectangle {
        width: 1
        height: 2
        anchors.top: body.top
        anchors.topMargin: 1
        anchors.horizontalCenter: body.horizontalCenter
        color: root.bar ? root.bar.background : Color.background
      }
    }
  }

  onPressed: function() {
    if (root.bar) root.bar.run(root.toggleCommand)
  }
}
