#!/bin/sh
# Shared Wi-Fi menu flow for dmenu and fzf. Network operations live in sh.

wifi_menu_action_choice() {
    menu_mode=$1
    menu_title=$2
    menu_options=$3
    case "$menu_mode" in
        dmenu)
            printf '%s\n' "$menu_options" |
                dmenu -i -c -l 6 -title "$menu_title" -p 'Action'
            ;;
        fzf)
            printf '%s\n' "$menu_options" |
                fzf --height=60% --reverse --prompt='Action > '
            ;;
    esac
}

wifi_menu_confirm() {
    confirm_mode=$1
    confirm_message=$2
    # Default selection is No; confirmation requires explicitly choosing Yes.
    answer=$(wifi_menu_action_choice "$confirm_mode" "$confirm_message" \
        "$(printf 'No\nYes')") || return 1
    [ "$answer" = Yes ]
}


# Only the password bytes go through stdin to the sh backend. Neither
# password nor derived PSK is ever part of a process command line.
wifi_menu_join_new() {
    join_mode=$1
    join_network=$2
    join_persistence=$3
    # The password travels on stdin. This option only controls whether the
    # backend explicitly saves the new profile or leaves it in memory.
    case "$join_persistence" in
        temporary) set -- --temporary "$join_network" ;;
        saved) set -- "$join_network" ;;
        *) echo 'Error: Unknown Wi-Fi persistence choice.' >&2; return 2 ;;
    esac
    command -v wifi_join_new >/dev/null 2>&1 || {
        echo 'Error: Update agusc01/sh to enable WPA2 enrollment.' >&2
        return 1
    }
    case "$join_mode" in
        dmenu)
            # -P is the suckless password patch, integrated in our fork.
            join_password=$(printf '' |
                dmenu -P -c -title "Password for $join_network" -p 'Password') || return 0
            [ -n "$join_password" ] || return 0
            printf '%s\n' "$join_password" | wifi_join_new "$@"
            join_password=''
            ;;
        fzf)
            # fzf has no native password mask. Read from the controlling TTY
            # with echo disabled, restoring its mode even on interruption.
            (
                if [ ! -r /dev/tty ]; then
                    echo 'Error: A terminal is required for masked password input.' >&2
                    exit 1
                fi
                saved_tty=$(stty -g </dev/tty) || exit 1
                trap 'stty "$saved_tty" </dev/tty' 0
                trap 'exit 130' 1 2 3 15
                stty -echo </dev/tty || exit 1
                printf 'WPA2 password for %s: ' "$join_network" >/dev/tty
                IFS= read -r join_password </dev/tty || exit 1
                printf '\n' >/dev/tty
                stty "$saved_tty" </dev/tty
                trap - 0 1 2 3 15
                [ -n "$join_password" ] || exit 0
                printf '%s\n' "$join_password" | wifi_join_new "$@"
                join_password=''
            )
            ;;
    esac
}

wifi_menu() {
    mode=$1
    command -v wifi_list >/dev/null 2>&1 &&
    command -v wifi_info >/dev/null 2>&1 || {
        echo 'Error: Install agusc01/sh Wi-Fi commands first.' >&2
        return 1
    }

    visible=$(wifi_list) || return 1
    # Include out-of-range saved networks so they can still be managed.
    saved=''
    if command -v wifi_saved >/dev/null 2>&1; then
        saved=$(wifi_saved 2>/dev/null) || saved=''
    fi
    networks=$(printf '%s\n%s\n' "$visible" "$saved" |
        awk 'NF && !seen[$0]++ { print }')
    [ -n "$networks" ] || {
        echo 'No Wi-Fi networks available. Try wifi_scan and reopen the menu.' >&2
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

    # dmenu accepts typed text; never act on an unknown SSID.
    if ! printf '%s\n' "$networks" | grep -F -x -- "$selected" >/dev/null; then
        echo 'Error: Selection is not an available SSID.' >&2
        return 1
    fi

    if printf '%s\n' "$saved" | grep -F -x -- "$selected" >/dev/null; then
        options=$(printf 'Connect saved network\nForget saved network\nCheck current Internet\nRenew current DHCP\nDisconnect Wi-Fi\nCancel')
    elif command -v wifi_join_supported >/dev/null 2>&1 &&
         wifi_join_supported "$selected" >/dev/null 2>&1; then
        options=$(printf 'Join WPA2 temporarily\nJoin WPA2 and save\nCheck current Internet\nRenew current DHCP\nDisconnect Wi-Fi\nCancel')
    else
        # Avoid prompting for credentials on open, WPA3-only, enterprise,
        # mixed-security, or stale/offline SSIDs.
        options=$(printf 'Unsupported network (view only)\nCheck current Internet\nRenew current DHCP\nDisconnect Wi-Fi\nCancel')
    fi
    action=$(wifi_menu_action_choice "$mode" "$selected" "$options") || return 0

    case "$action" in
        'Join WPA2 temporarily')
            wifi_menu_join_new "$mode" "$selected" temporary
            ;;
        'Join WPA2 and save')
            wifi_menu_join_new "$mode" "$selected" saved
            ;;
        'Connect saved network')
            command -v wifi_connect_saved >/dev/null 2>&1 || {
                echo 'Error: Update agusc01/sh to use Wi-Fi actions.' >&2
                return 1
            }
            wifi_connect_saved "$selected"
            ;;
        'Forget saved network')
            command -v wifi_forget_saved >/dev/null 2>&1 || {
                echo 'Error: Update agusc01/sh to use Wi-Fi actions.' >&2
                return 1
            }
            if wifi_menu_confirm "$mode" "Forget $selected?"; then
                wifi_forget_saved "$selected" --confirm
            fi
            ;;
        'Check current Internet')
            command -v wifi_internet_status >/dev/null 2>&1 || {
                echo 'Error: Update agusc01/sh to check Internet.' >&2
                return 1
            }
            wifi_internet_status
            ;;
        'Renew current DHCP')
            command -v wifi_dhcp_renew >/dev/null 2>&1 || {
                echo 'Error: Update agusc01/sh to renew DHCP.' >&2
                return 1
            }
            if wifi_menu_confirm "$mode" 'Renew DHCP on CURRENT Wi-Fi?'; then
                wifi_dhcp_renew --confirm
            fi
            ;;
        'Disconnect Wi-Fi')
            command -v wifi_disconnect >/dev/null 2>&1 || {
                echo 'Error: Update agusc01/sh to use Wi-Fi actions.' >&2
                return 1
            }
            if wifi_menu_confirm "$mode" 'Disconnect Wi-Fi?'; then
                wifi_disconnect --confirm
            fi
            ;;
        'Unsupported network (view only)'|'Cancel'|'')
            return 0
            ;;
        *)
            echo 'Error: Invalid Wi-Fi action.' >&2
            return 1
            ;;
    esac
}
