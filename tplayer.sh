#!/bin/bash
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
source $controlfolder/device_info.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR=/$directory/ports/tplayer
CONFDIR="$GAMEDIR/conf/"
mkdir -p "$GAMEDIR/conf"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

$ESUDO mkdir -p "/run/user/$(id -u)/pulse"
$ESUDO chmod 700 "/run/user/$(id -u)"
$ESUDO chown $(id -u):$(id -g) "/run/user/$(id -u)" "/run/user/$(id -u)/pulse"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

amixer set 'Playback Path' 'SPK' 2>/dev/null
amixer sset Master 80% 2>/dev/null
amixer sset PCM 80% 2>/dev/null
unset SDL_AUDIODRIVER

cd $GAMEDIR
export XDG_DATA_HOME="$CONFDIR"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"

chmod +x ./love
$GPTOKEYB "love" &
./love gui

$ESUDO kill -9 $(pidof gptokeyb)
$ESUDO systemctl restart oga_events &
printf "\033c" > /dev/tty1
