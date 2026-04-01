# 🎵 TPlayer v2.0

A lightweight music player for the R36S handheld, built with Love2D.

**Original project by [TyraNight](https://github.com/TyraNight/TPlayer)**
**v2.0 modifications by [ValeriaRoyal](https://github.com/ValeriaRoyal)**

## What's New in v2.0

- **Album Browser** — navigate your music library by album with cover art thumbnails
- **Track List** — see all songs in an album and pick what to play
- **Repeat A-B** — loop a specific section of a song (press Y)
- **Shuffle & Repeat** — shuffle mode (L1) and repeat off/one/all (R1)
- **Scrolling Titles** — long song titles scroll horizontally
- **Dynamic Background** — background color extracted from album cover art
- **Improved Audio** — fixed PulseAudio issues, no distortion
- **Lock Controls** — prevent accidental presses (SELECT + R1)
- **Battery & Clock** — always visible in the top bar
- **Removed D-pad volume** — use the hardware volume buttons instead

## Controls

### Album Screen
| Button | Action |
|--------|--------|
| D-Pad Up/Down | Navigate albums |
| A | Open album |
| START + SELECT | Quit |

### Track List Screen
| Button | Action |
|--------|--------|
| D-Pad Up/Down | Navigate tracks |
| A | Play track |
| B | Back to albums |

### Now Playing Screen
| Button | Action |
|--------|--------|
| A | Play / Pause |
| D-Pad Left/Right | Previous / Next track |
| Left Stick | Analog seek (rewind / forward) |
| L1 | Toggle shuffle |
| R1 | Cycle repeat (off → one → all) |
| Y | Repeat A-B (1st: set A, 2nd: set B, 3rd: clear) |
| B | Back to track list |
| SELECT + R1 | Lock / Unlock controls |
| START + SELECT | Quit |

## Installation (ArkOS)

1. Download the release archive
2. Extract and copy `tplayer.sh` and the `tplayer/` folder to `EasyRoms/ports/`
3. Create album folders inside `tplayer/gui/music/`:

```
music/
├── Artist - Album Name/
│   ├── cover.jpg       (recommended: 300x300)
│   ├── 01 Song.mp3
│   ├── 02 Song.mp3
│   └── ...
├── Another Artist - Album/
│   ├── cover.jpg
│   └── ...
```

4. Launch TPlayer from the **Ports** section

## Supported Formats

- MP3
- FLAC
- OGG Vorbis

## Cover Art

- Place a `cover.jpg` or `cover.png` inside each album folder
- Recommended size: **300x300 pixels** (larger images may fail on R36S hardware)
- The background color is automatically extracted from the cover art

## Tested On

- R36S with ArkOS
- Should work on other Anbernic devices running ArkOS or Knulli

## Credits

- **TyraNight** — Original TPlayer concept, Love2D implementation, ID3 parser, UI design
- **ValeriaRoyal** — v2.0 album browser, track list, A-B repeat, shuffle/repeat modes, audio fixes, dynamic background improvements

## License

GPL-3.0 — see [LICENSE](LICENSE)
