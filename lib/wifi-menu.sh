#!/bin/sh
# Single Wi-Fi menu flow; only the selection backend differs.

wifi_menu() {
    mode=$1
    command -v wifi_list >/dev/null 2>&1 &&
    command -v wifi_info >/dev/null 2>&1 || {
        echo 'Error: Install agusc01/sh Wi-Fi commands first.' >&2
        return 1
    }

    networks=$(wifi_list) || return 1
    [ -n "$networks" ] || {
        echo 'No visible Wi-Fi networks. Try wifi_scan and reopen this menu.' >&2
        return 1
    }

    case "$mode" in
        dmenu)
            command -v dmenu >/dev/null 2>&1 || {
                echo 'Error: dmenu is missing.' >&2; return 1
            }
            selected=$(printf '%s\n' "$networks" |
                dmenu -i -c -l 10 -p 'Search' \
                    -title 'Wi-Fi Networks' \
                    -preview wifi_info \
                    -preview-title 'Network details' \
                    -preview-pos right -preview-size 45) || return 0
            ;;
        fzf)
            command -v fzf >/dev/null 2>&1 || {
                echo 'Error: fzf is missing.' >&2; return 1
            }
            selected=$(printf '%s\n' "$networks" |
                fzf --height=60% --reverse --prompt='Wi-Fi > ' \
                    --preview='wifi_info {}' --preview-window='right:50%') || return 0
            ;;
        *)
            echo 'Error: Unknown menu backend.' >&2
            return 2
            ;;
    esac
    [ -n "$selected" ] || return 0

    # dmenu allows arbitrary text; accept only an exact visible SSID.
    if ! printf '%s\n' "$networks" | grep -F -x -- "$selected" >/dev/null; then
        echo 'Error: Selection is not an available SSID.' >&2
        return 1
    fi
    # dmenu displayed the information while navigating; never open a second
    # screen or perform a network-changing action when an SSID is selected.
    if [ "$mode" = fzf ]; then
        wifi_info "$selected"
    fi
}
