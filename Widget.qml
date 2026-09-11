import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon for the bluetooth-mouse-touchpad automation. Always visible, like
// omarchy.microphone -- NOT like Stay Awake / Night Light / Screen Recording,
// which hide until hovered. Those all extend `BarIndicator`, which layers a
// hide-unless-active-or-host-revealed opacity system on top for their
// specific "cluster of many small indicators" use case; `omarchy.microphone`
// (see its real source, .../bar/widgets/Microphone.qml) instead wraps a plain
// `BarIconButton` inside an always-visible `BarWidget`, which has no such
// concealment. That's the base this follows, so the icon behaves the same
// way microphone/screen-recording *icons themselves* do: always present,
// full accent color while active, dimmer foreground color while not.
//
// The icon is drawn with plain QML Rectangles (filled body + a
// background-colored notch) rather than a font glyph, sized to fill the same
// icon canvas every built-in icon's glyph renders into.
//
// State comes from ~/.local/state/omarchy/mouse-or-trackpad.json, written by
// the daemon on every change; `watchChanges` on the FileView means this
// updates the instant the daemon does, no polling.
//
// NOTE for future edits: this plugin is loaded through a symlink
// (~/.config/omarchy/plugins/simacek.mouse-or-trackpad -> ~/plugins/...), and
// the shell's file watcher does not follow symlinks. Edits here will NOT
// hot-reload -- run `omarchy restart shell` and re-check after every change.
BarWidget {
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

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.touchpadDisabled
    tooltipText: root.touchpadDisabled
      ? "Touchpad disabled — " + (root.mouseName || "Bluetooth mouse") + " connected"
      : "Touchpad active"

    iconComponent: Component {
      Item {
        anchors.fill: parent

        Rectangle {
          id: body
          anchors.centerIn: parent
          width: 7
          height: 9
          radius: 2
          color: button.active ? button.activeColor : button.foreground
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
}
