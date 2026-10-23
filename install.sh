#!/bin/sh
set -eu
root=$(CDPATH= cd "$(dirname "$0")" && pwd)
source_script="$root/bin/menu-wifi"
installed_dir="$HOME/.local/share/menus/bin"
installed_script="$installed_dir/menu-wifi"
bin_dir="$HOME/.local/bin"

[ -f "$source_script" ] && [ -f "$root/lib/wifi-menu.sh" ] || {
    echo 'Error: Invalid menus checkout.' >&2
    exit 1
}
for name in dmenu_wifi fzf_wifi; do
    target="$bin_dir/$name"
    if [ -e "$target" ] || [ -L "$target" ]; then
        if [ "$(readlink "$target" 2>/dev/null || :)" != "$installed_script" ]; then
            echo "Error: Existing command not managed by menus: $target" >&2
            exit 1
        fi
    fi
done
if [ -e "$installed_script" ] || [ -L "$installed_script" ]; then
    if [ -L "$installed_script" ] ||
       ! grep -F '# menus-managed: agusc01/menus' "$installed_script" >/dev/null 2>&1; then
        echo "Error: Existing executable is not managed by menus: $installed_script" >&2
        exit 1
    fi
fi
mkdir -vp "$installed_dir"
mkdir -vp "$bin_dir"
cp -v "$source_script" "$installed_script"
chmod +x "$installed_script"
for name in dmenu_wifi fzf_wifi; do
    target="$bin_dir/$name"
    if [ ! -L "$target" ]; then
        ln -sv "$installed_script" "$target"
    fi
done
echo 'Menu frontends installed. Install sh commands and dmenu/fzf separately.'
