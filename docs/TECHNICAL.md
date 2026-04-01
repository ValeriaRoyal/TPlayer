# Technical Specification

## Architecture

TPlayer is a Love2D application that runs on the R36S handheld console via ArkOS.

### File Structure

```
ports/
├── tplayer.sh              # Launcher script (PortMaster compatible)
└── tplayer/
    ├── love                # Love2D binary (ARM64, v11.5)
    ├── libs/               # Love2D shared libraries
    ├── mn/libs/            # Additional shared libraries
    ├── conf/               # Runtime config (PulseAudio, save data)
    ├── gui/
    │   ├── main.lua        # Application code
    │   ├── cover_default.png
    │   ├── play_btn.png
    │   ├── pause_btn.png
    │   ├── battery.png
    │   ├── icon_lock.png
    │   ├── icon_unlock.png
    │   ├── instruction.png
    │   └── music/          # Music library (album folders)
    │       └── Artist - Album/
    │           ├── cover.jpg
    │           └── *.mp3
    ├── cover.png
    ├── gameinfo.xml
    └── port.json
```

### Launch Flow

1. ArkOS EmulationStation detects `tplayer.sh` in `ports/`
2. `tplayer.sh` sources PortMaster's `control.txt` and `device_info.txt`
3. Script creates PulseAudio runtime directory, sets volume, starts gptokeyb
4. Love2D launches with `gui/` as the working directory
5. `main.lua` scans `music/` for album folders and builds the library

### Screen Flow

```
[Albums] --A--> [Tracks] --A--> [Now Playing]
                [Tracks] <--B-- [Now Playing]
[Albums] <--B-- [Tracks]
```

## Hardware Constraints (R36S)

| Spec | Value |
|------|-------|
| CPU | RK3326 (ARM64) |
| RAM | 1 GB |
| Screen | 640x480 IPS |
| Storage | microSD (slot 1: OS+ROMs, slot 2: optional) |
| Audio | ALSA, speaker + headphone jack |
| Input | D-pad, ABXY, L1/L2/R1/R2, 2 analog sticks, Start/Select/Fn, volume buttons |

### Limitations

- **Cover art must be ≤300x300**: Larger images (e.g., 3000x3000) cause `love.image.newImageData` to fail silently on the R36S due to memory constraints
- **No touchscreen**: All navigation is via gamepad buttons
- **Love2D sandbox**: `love.filesystem` does not follow symlinks or see bind-mounted directories. Music must be physically present in the `gui/music/` directory
- **SD slot 2**: Attempted mount --bind, symlinks, and direct mount approaches. None worked reliably with Love2D's filesystem sandbox. Music must reside on slot 1 for now

## Technical Decisions

### Audio
- **SDL_AUDIODRIVER left unset**: Forcing `alsa` caused distortion ("buzzing"). Letting SDL auto-detect works correctly
- **System volume set to 80%**: 100% on both Master and PCM causes clipping/distortion on the R36S speaker
- **PulseAudio fix**: ArkOS doesn't create `/run/user/<uid>/pulse` by default. The launcher script creates it with sudo

### Cover Art & Background Color
- **File-based covers preferred**: Embedded ID3v2 APIC extraction works but is unreliable on R36S (2MB+ images in tags). External `cover.jpg` files are more reliable
- **Brightness boost**: The original `extractDominantColor` multiplied by 0.3, making dark album covers indistinguishable from the default background. v2.0 applies adaptive brightness boosting (minimum 0.35 intensity)
- **Cover search cascade**: Tries `trackname.jpg` → `trackname.png` → `cover.jpg` → `cover.png` → default

### ID3 Parsing
- Custom ID3v2 parser in pure Lua (no external dependencies)
- Reads TIT2 (title) and TPE1 (artist) frames
- APIC (cover) extraction available but not used in v2.0 (file-based covers preferred)

## Future Ideas

- **Music Square**: Mood-based playlist grid (manual tagging approach recommended over audio analysis due to hardware limits)
- **SD Card Slot 2 Support**: Needs a solution that works within Love2D's filesystem sandbox (possibly copying to /tmp at launch)
- **Equalizer**: Basic bass/treble control
- **Favorites**: Mark and filter favorite tracks
- **Playlist support**: Create and save custom playlists
- **OGG/FLAC Vorbis comment reading**: Basic implementation exists but needs improvement
