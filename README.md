# Mouse or Trackpad (`simacek.mouse-or-trackpad`)

Automatically disables your laptop's trackpad while a Bluetooth mouse is
connected, and shows an Omarchy bar icon for which one currently has control.

## What it does

- **Daemon** (`bin/bluetooth-mouse-touchpad`, run as a `systemd --user`
  service) watches BlueZ over D-Bus for any paired **mouse** connecting or
  disconnecting, and disables/re-enables the trackpad accordingly via
  `hyprctl eval "hl.device(...)"`.
- **"Bluetooth mouse"** is detected generically — BlueZ's `Icon` property
  reporting `input-mouse`, or (fallback) a Class-of-Device major class of
  Peripheral with a pointer/combo subtype — so it isn't tied to one device's
  MAC address; any paired Bluetooth mouse triggers it.
- **Dual-node touchpads handled correctly.** Some touchpads (an ALPS
  touchpad on a Dell Latitude, for one) report themselves to Hyprland as two
  separate logical mouse devices for the same physical hardware. Omarchy's
  own `omarchy toggle touchpad` only ever disables the first one it finds,
  which silently leaves the trackpad half-working. This daemon disables
  *every* device matching `touchpad|trackpad` in `hyprctl devices`, so it
  works whether your hardware exposes one node or several.
- **Bar icon** (`Widget.qml`) shows the trackpad glyph in your theme's normal
  foreground color while the trackpad is active, and in the accent/urgent
  color while a Bluetooth mouse has taken over — hover for a tooltip naming
  the connected mouse. **Click the icon to turn the whole automation on or
  off.**

## Install

```bash
git clone https://github.com/simacekd/omarchy-mouse-or-trackpad ~/plugins/mouse-or-trackpad
ln -sf ~/plugins/mouse-or-trackpad ~/.config/omarchy/plugins/simacek.mouse-or-trackpad

# Put the daemon on PATH -- the bar widget and the optional menu row below
# both invoke it by bare name (`bluetooth-mouse-touchpad --restore`)
mkdir -p ~/.local/bin
ln -sf ~/.config/omarchy/plugins/simacek.mouse-or-trackpad/bin/bluetooth-mouse-touchpad ~/.local/bin/

# Add the bar icon next to the built-in indicators cluster (Stay Awake, Night
# Light, etc.) -- move it elsewhere with `omarchy bar move ... --section ...`
omarchy bar move simacek.mouse-or-trackpad --section center --after omarchy.indicators

# Install and enable the background service
mkdir -p ~/.config/systemd/user
ln -sf ~/.config/omarchy/plugins/simacek.mouse-or-trackpad/systemd/bluetooth-mouse-touchpad.service \
  ~/.config/systemd/user/bluetooth-mouse-touchpad.service
systemctl --user daemon-reload
systemctl --user enable --now bluetooth-mouse-touchpad.service
```

Needs `jq` and `busctl`/`dbus-monitor` (part of any systemd/dbus desktop), and
a Bluetooth mouse actually paired via `bluetoothctl`/the Bluetooth bar panel —
the daemon only reacts to *paired* devices.

### Optional: menu toggle

If you also use Omarchy's `~/.config/omarchy/extensions/omarchy-menu.jsonc`,
add a row under the built-in Trigger → Toggle menu so you can flip it from
there too, not just the bar icon:

```jsonc
"trigger.toggle.bluetooth-mouse-touchpad": {
  "icon": "󰟸",
  "label": "Auto-Disable Touchpad (BT Mouse)",
  "description": "Disable the touchpad automatically while any Bluetooth mouse is connected, re-enable it when disconnected",
  "checked": "systemctl --user is-enabled --quiet bluetooth-mouse-touchpad.service",
  "action": "systemctl --user is-enabled --quiet bluetooth-mouse-touchpad.service && { systemctl --user disable --now bluetooth-mouse-touchpad.service; bluetooth-mouse-touchpad --restore; } || systemctl --user enable --now bluetooth-mouse-touchpad.service"
}
```

## Uninstall

```bash
systemctl --user disable --now bluetooth-mouse-touchpad.service
rm ~/.config/systemd/user/bluetooth-mouse-touchpad.service
omarchy plugin disable simacek.mouse-or-trackpad   # or just:
rm ~/.config/omarchy/plugins/simacek.mouse-or-trackpad   # unlink (source stays in ~/plugins)
```

## Files

| File | Role |
|------|------|
| `bin/bluetooth-mouse-touchpad` | the daemon: BlueZ watcher + `hyprctl` device toggler + state-file writer |
| `systemd/bluetooth-mouse-touchpad.service` | `systemd --user` unit, `WantedBy=graphical-session.target` |
| `Widget.qml` | bar icon: reads the daemon's state file live, click to toggle |
| `manifest.json` | plugin id, entry point |

State lives in `~/.local/state/omarchy/mouse-or-trackpad.json`
(`{"touchpadDisabled": bool, "mouse": "name", "updatedAt": epoch}`), written
by the daemon on every change and watched live by the widget — no polling.

## Why not `omarchy toggle touchpad`?

That's Omarchy's own built-in toggle and is worth trying first for a
one-off manual disable. This plugin exists because (a) it needed to react
automatically to Bluetooth connect/disconnect events, and (b) on hardware
that exposes a touchpad as more than one logical device, the built-in
toggle only disables the first one it finds and silently leaves the
trackpad partially working — see "Dual-node touchpads handled correctly"
above.
