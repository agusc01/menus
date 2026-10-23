# menus

Shared lightweight menu flows for dmenu (X11) and fzf (console), using the
separate [agusc01/sh](https://github.com/agusc01/sh) command library.
No Bash, Fish, Rofi, NetworkManager, or retired `linux-tools`,
`linux-setup`, `linux-doctor` dependency.

## Wi-Fi (first, read-only milestone)

- `dmenu_wifi`: select a visible SSID and show its details in a second
  dmenu screen. A generic dynamic dmenu preview patch is planned separately.
- `fzf_wifi`: select the same SSIDs with a dynamic `wifi_info` preview.

These do **not** connect, disconnect or alter saved Wi-Fi settings.
`init-alpine` installs dmenu/fzf packages and Wi-Fi utilities. The `menus`
installer only installs its own user commands.

```sh
git clone https://github.com/agusc01/sh "$HOME/.config/sh"
git clone https://github.com/agusc01/menus "$HOME/.config/menus"
sh "$HOME/.config/sh/install.sh"
sh "$HOME/.config/menus/install.sh"
dmenu_wifi
fzf_wifi
```

The commands are created under `~/.local/bin`. If the Wi-Fi menu says the
scan is inaccessible, try `wifi_status`, `wifi_list`, and review the
`sh` Wi-Fi README. It intentionally never invokes `doas` or restarts
networking on its own.

Tests (mock `wifi_list`, `wifi_info`, dmenu and fzf):

```sh
sh tests/wifi-menu.sh
```
