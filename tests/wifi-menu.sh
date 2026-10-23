#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
workspace=$(mktemp -d)
trap 'rm -R "$workspace"' 0
mkdir -p "$workspace/bin"

cat > "$workspace/bin/wifi_list" <<'MOCK'
#!/bin/sh
printf 'Home:5G\nGuest Lounge\n'
MOCK
cat > "$workspace/bin/wifi_info" <<'MOCK'
#!/bin/sh
[ "$1" = Home:5G ] || exit 1
printf 'SSID: %s\nSignal: -44 dBm\n' "$1"
MOCK
cat > "$workspace/bin/dmenu" <<'MOCK'
#!/bin/sh
cat >/dev/null
[ "${MOCK_CANCEL:-0}" = 1 ] && exit 1
if [ "${MOCK_INVALID:-0}" = 1 ]; then
    echo unknown
else
    echo Home:5G
fi
MOCK
cat > "$workspace/bin/fzf" <<'MOCK'
#!/bin/sh
cat >/dev/null
[ "${MOCK_CANCEL:-0}" = 1 ] && exit 1
echo Home:5G
MOCK
chmod +x "$workspace/bin/"*
PATH="$workspace/bin:$PATH"; export PATH
MENUS_HOME=$root; export MENUS_HOME

sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu fzf' > "$workspace/output"
grep -F 'Signal: -44 dBm' "$workspace/output" >/dev/null
MOCK_CANCEL=1; export MOCK_CANCEL
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu fzf'
unset MOCK_CANCEL
MOCK_INVALID=1; export MOCK_INVALID
if sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu' >/dev/null 2>&1; then
    echo 'Error: Unknown SSID was accepted.' >&2
    exit 1
fi

sh -n "$root/bin/menu-wifi"
sh -n "$root/lib/wifi-menu.sh"
sh -n "$root/install.sh"
echo 'Wi-Fi menu tests passed.'
