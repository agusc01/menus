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
cat > "$workspace/bin/wifi_saved" <<'MOCK'
#!/bin/sh
printf 'Home:5G\nOut of range\n'
MOCK
cat > "$workspace/bin/wifi_info" <<'MOCK'
#!/bin/sh
printf 'SSID: %s\nSignal: -44 dBm\n' "$1"
MOCK
cat > "$workspace/bin/wifi_connect_saved" <<'MOCK'
#!/bin/sh
printf 'connect:%s\n' "$1" >> "$MENU_TEST_ACTIONS"
MOCK
cat > "$workspace/bin/wifi_disconnect" <<'MOCK'
#!/bin/sh
printf 'disconnect:%s\n' "$1" >> "$MENU_TEST_ACTIONS"
MOCK
cat > "$workspace/bin/wifi_forget_saved" <<'MOCK'
#!/bin/sh
printf 'forget:%s:%s\n' "$1" "$2" >> "$MENU_TEST_ACTIONS"
MOCK
cat > "$workspace/bin/wifi_join_new" <<'MOCK'
#!/bin/sh
IFS= read -r password || exit 1
[ "$password" = 'samplepass123' ] || exit 1
printf 'join:%s:%s\n' "$1" "${#password}" >> "$MENU_TEST_ACTIONS"
MOCK
cat > "$workspace/bin/dmenu" <<'MOCK'
#!/bin/sh
printf '%s\n' "$@" >> "$MENU_TEST_DMENU_ARGS"
echo CALL >> "$MENU_TEST_DMENU_CALLS"
cat >/dev/null
[ "${MOCK_CANCEL:-0}" = 1 ] && exit 1
case " $* " in
    *' -P '*) printf '%s\n' "${MOCK_PASSWORD:-samplepass123}" ;;
    *' -preview '*)
        [ "${MOCK_INVALID:-0}" = 1 ] && echo unknown || echo "${MOCK_NETWORK:-Home:5G}"
        ;;
    *'Forget Home:5G?'*|*'Disconnect Wi-Fi?'*)
        printf '%s\n' "${MOCK_CONFIRM:-No}"
        ;;
    *)
        printf '%s\n' "${MOCK_ACTION:-Cancel}"
        ;;
esac
MOCK
cat > "$workspace/bin/fzf" <<'MOCK'
#!/bin/sh
choices=$(cat)
[ "${MOCK_CANCEL:-0}" = 1 ] && exit 1
case " $* " in
    *'--preview='*) echo Home:5G ;;
    *)
        case "$choices" in
            "$(printf 'No\nYes')") printf '%s\n' "${MOCK_CONFIRM:-No}" ;;
            *) printf '%s\n' "${MOCK_ACTION:-Cancel}" ;;
        esac
        ;;
esac
MOCK
chmod +x "$workspace/bin/"*
PATH="$workspace/bin:$PATH"; export PATH
MENUS_HOME=$root; export MENUS_HOME
MENU_TEST_DMENU_ARGS="$workspace/dmenu-args"; export MENU_TEST_DMENU_ARGS
MENU_TEST_DMENU_CALLS="$workspace/dmenu-calls"; export MENU_TEST_DMENU_CALLS
MENU_TEST_ACTIONS="$workspace/actions"; export MENU_TEST_ACTIONS

# Existing network preview remains in the first chooser; next chooser is
# an explicit action selection, not an automatic connect.
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
[ "$(wc -l < "$MENU_TEST_DMENU_CALLS")" -eq 2 ] || {
    echo 'Error: Expected network chooser and action chooser.' >&2
    exit 1
}
grep -Fx -- '-title' "$MENU_TEST_DMENU_ARGS" >/dev/null
grep -Fx -- 'Wi-Fi Networks' "$MENU_TEST_DMENU_ARGS" >/dev/null
grep -Fx -- '-preview' "$MENU_TEST_DMENU_ARGS" >/dev/null
grep -Fx -- 'wifi_info' "$MENU_TEST_DMENU_ARGS" >/dev/null
[ ! -e "$MENU_TEST_ACTIONS" ] || exit 1

sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu fzf'
[ ! -e "$MENU_TEST_ACTIONS" ] || exit 1

MOCK_ACTION='Connect saved network'; export MOCK_ACTION
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
grep -Fx 'connect:Home:5G' "$MENU_TEST_ACTIONS" >/dev/null
: > "$MENU_TEST_ACTIONS"

MOCK_ACTION='Forget saved network'; export MOCK_ACTION
MOCK_CONFIRM=No; export MOCK_CONFIRM
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
[ ! -s "$MENU_TEST_ACTIONS" ] || {
    echo 'Error: Declined deletion reached backend.' >&2; exit 1
}
MOCK_CONFIRM=Yes; export MOCK_CONFIRM
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
grep -Fx 'forget:Home:5G:--confirm' "$MENU_TEST_ACTIONS" >/dev/null
: > "$MENU_TEST_ACTIONS"

MOCK_ACTION='Disconnect Wi-Fi'; export MOCK_ACTION
MOCK_CONFIRM=No; export MOCK_CONFIRM
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
[ ! -s "$MENU_TEST_ACTIONS" ] || {
    echo 'Error: Declined disconnect reached backend.' >&2; exit 1
}
MOCK_CONFIRM=Yes; export MOCK_CONFIRM
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
grep -Fx 'disconnect:--confirm' "$MENU_TEST_ACTIONS" >/dev/null

# fzf has the same confirmation barrier as dmenu.
MOCK_ACTION='Forget saved network'; export MOCK_ACTION
MOCK_CONFIRM=No; export MOCK_CONFIRM
: > "$MENU_TEST_ACTIONS"
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu fzf'
[ ! -s "$MENU_TEST_ACTIONS" ] || {
    echo 'Error: fzf declined forget reached backend.' >&2; exit 1
}
MOCK_CONFIRM=Yes; export MOCK_CONFIRM
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu fzf'
grep -Fx 'forget:Home:5G:--confirm' "$MENU_TEST_ACTIONS" >/dev/null

# New WPA2 enrollment is possible only through the explicit action and a
# masked password prompt. The fake backend checks stdin without logging it.
MOCK_NETWORK='Guest Lounge'; export MOCK_NETWORK
MOCK_ACTION='Join new WPA2 network'; export MOCK_ACTION
MOCK_PASSWORD='samplepass123'; export MOCK_PASSWORD
: > "$MENU_TEST_ACTIONS"
sh -c '. "$MENUS_HOME/lib/wifi-menu.sh"; wifi_menu dmenu'
grep -Fx 'join:Guest Lounge:13' "$MENU_TEST_ACTIONS" >/dev/null
grep -Fx -- '-P' "$MENU_TEST_DMENU_ARGS" >/dev/null
if grep -F 'samplepass123' "$MENU_TEST_DMENU_ARGS" >/dev/null; then
    echo 'Error: Secret appeared in dmenu arguments.' >&2; exit 1
fi
unset MOCK_NETWORK MOCK_PASSWORD
: > "$MENU_TEST_ACTIONS"

unset MOCK_ACTION MOCK_CONFIRM
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
