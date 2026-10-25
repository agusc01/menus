# menus

Shared lightweight menu flows for dmenu (X11) and fzf (console), using the
separate [agusc01/sh](https://github.com/agusc01/sh) command library.
No Bash, Fish, Rofi, NetworkManager, or retired `linux-tools`,
`linux-setup`, `linux-doctor` dependency.

## Wi-Fi (inspection and saved-profile actions)

- `dmenu_wifi`: show a title above the search field, and the selected
  network's live information in a right-side dmenu preview panel. Requires
  the updated [agusc01/dmenu](https://github.com/agusc01/dmenu) fork with
  `-title` and `-preview` support (feature branch `feat/header-preview-pane`
  until merged).
- `dmenu_wifi` shows one network preview screen and then an action chooser.
- `fzf_wifi`: select the same SSIDs with a dynamic `wifi_info` preview.

Network browsing remains read-only. Choosing a network now opens an explicit
action chooser. A saved network can be connected or forgotten; disconnection
is also available. Forget and disconnect have separate confirmation screens,
with **No** as the default. Selecting a network never changes Wi-Fi by itself.
Unsaved networks are joinable only when their advertised security is supported by the new masked WPA2 flow.
No default dmenu prompt should be used for Wi-Fi passwords.
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

The graphical menu launches `wifi_info` as a preview command through
our fork of dmenu, directly passing the highlighted SSID as an argument.
No shell interpolation is used. Press Escape to cancel; selecting a network
just closes the menu and does not connect to it. The fzf interface keeps
its independent live preview and prints the chosen network's details.

Install the updated dmenu executable before trying `dmenu_wifi`:

```sh
cd "$HOME/.config/dmenu"
git fetch origin
git switch feat/header-preview-pane
make clean && make
doas make install
```

The action chooser requires the `wifi_connect_saved`, `wifi_disconnect`, and
`wifi_forget_saved` commands from the sibling `agusc01/sh`
`feat/wifi-saved-actions` branch. To use the new actions, update both
repositories and rerun `sh install.sh` inside `sh` (new command links), then
run the menu installer again. This branch is stacked on the read-only preview
branch, so it must be merged after the original Wi-Fi menu PR.

Tests (mock `wifi_list`, `wifi_saved`, Wi-Fi writes, dmenu and fzf):

```sh
sh tests/wifi-menu.sh
```


### Joining a new network

An unsaved, visible network now offers **Join new WPA2 network**. Choosing
that action opens a masked password prompt using the suckless `dmenu -P`
patch, adapted for our dmenu fork and vendored as a historical diff under
`agusc01/dmenu/patches/dmenu-password-5.0.diff`. On the terminal frontend,
`fzf` has no password-masking feature, so the menu reads from `/dev/tty`
with echo temporarily disabled and always restores the terminal mode.

No password is passed in an executable's arguments, displayed in a preview,
or stored in a menu-managed file. It is sent through standard input to
`wifi_join_new SSID`, which lives in the independent `agusc01/sh`
`feat/wifi-join-new` branch. The backend only enrolls WPA2-Personal
networks; other network types are rejected with a clear message.

Required test branches until the PRs are merged:
- dmenu: `feat/masked-password-input`
- sh: `feat/wifi-join-new`
- menus: `feat/wifi-join-new`

Always run the mocked tests first; real joining will modify the
wpa_supplicant configuration and may disconnect an existing network.

For unsaved SSIDs, the action menu offers WPA2 enrollment only if
`wifi_join_supported 'SSID'` from the updated `sh` package succeeds.
Unsupported, ambiguous and stale scan entries remain view-only.
After `wifi_scan`, give the wpa_supplicant cache a few seconds to update
before reopening the menu.

WPA2/WPA3 transition hotspots advertising flags such as
`[WPA2-PSK+SAE-CCMP][ESS]` are now joinable through their WPA2-PSK
capability. WPA3-only networks are still view-only until a separate SAE
implementation is available. `sh` remains responsible for validating the
scan and setting the corresponding `key_mgmt WPA-PSK` profile.

### Persisted versus temporary connections

Compatible, unsaved WPA2 networks now offer two **explicit** choices:

- `Join WPA2 temporarily`: keep a profile in the current `wpa_supplicant`
  process only; do not call `save_config`. This works even if disk saving
  is disabled, though connection and DHCP still must be verified.
- `Join WPA2 and save`: save the new profile before switching; abort and
  roll back if `save_config` returns `FAIL`. The running connection remains
  unchanged on that initial persistence failure.

Both choices use the same masked password entry. There is no automatic
fallback: a failed persisted join must not silently change the active Wi-Fi.


### Checking IP and Internet; renewing DHCP

The action chooser now offers **Check current Internet** and
**Renew current DHCP**. Both apply to the CURRENTLY CONNECTED interface,
not necessarily to the SSID highlighted in the list. Checking Internet
prints the separate IPv4, default route, ICMP and DNS diagnostic results
to the launching terminal; it is never called by the live preview.

Renew current DHCP requires explicit No/Yes confirmation and then invokes
the standalone sh command wifi_dhcp_renew --confirm. That backend only
signals a verified already-running BusyBox udhcpc process. It does not
spawn a competing DHCP daemon or reset the interface. Root-owned DHCP
clients may require doas approval in a terminal.

Persistence setup is a separate explicit root-owned operation documented
in agusc01/sh/scripts/enable-wpa-saving.sh. The menu never edits the
wpa_supplicant.conf file or reloads services itself. If save_config fails,
users can still select the existing **Join WPA2 temporarily** action.

## Save and enable Wi-Fi auto-reconnect

Saved networks now offer **Enable auto-reconnect** in the action chooser.
This calls wifi_enable_saved SSID --confirm after a Yes/No confirmation.
The backend enables the chosen saved profile with `enable_network ID no-connect`
and persists the resulting state with save_config, without switching away
from the current Wi-Fi.

When a user manually switches to a saved or new SSID, the backend also
restores previously enabled profiles in no-connect mode. Already disabled
profiles remain disabled until the user explicitly enables them.

After using Enable auto-reconnect, verify with:

    wpa_cli -i wlan0 list_networks

An enabled inactive profile should no longer show [DISABLED].
