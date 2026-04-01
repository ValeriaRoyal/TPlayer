# Changelog

## v2.0 (2026-04-01) — ValeriaRoyal

### New Features
- Album browser with cover art thumbnails
- Track list view with navigation
- Three-screen navigation: Albums → Tracks → Now Playing
- Repeat A-B: loop a specific section of a song (Y button)
- Shuffle mode (L1)
- Repeat modes: off / repeat one / repeat all (R1)
- Scrolling long titles
- Mini now-playing bar on album/track screens
- Dynamic background color from cover art with brightness boost

### Improvements
- Removed D-pad volume control (use hardware volume buttons)
- Fixed PulseAudio runtime directory creation for ArkOS
- Fixed cover art color extraction (was too dark to see)
- Cover images resized to 300x300 for R36S compatibility
- Protected audio loading with pcall (no crash on bad files)
- Cleaned up launcher script for ArkOS/PortMaster compatibility
- Battery percentage properly centered on icon
- Lock/unlock icon visible in top bar

### Bug Fixes
- Fixed embedded cover extraction from ID3v2 (pcall return values)
- Fixed cover search fallback (tries multiple candidates)
- Fixed audio distortion (removed forced ALSA driver, set volume to 80%)

---

## v1.2 (2026-03-09) — TyraNight

- Added lock system (SELECT + R1)
- Added clock display
- Added battery level indicator
- Added quit shortcut (START + SELECT)
- Tested on Anbernic devices running Knulli

## v1.1 (2026-03-02) — TyraNight

- Added analog seek using left thumbstick
- Added FLAC support
- Added OGG Vorbis support
- Improved default "no cover" image
- Fixed crash when using D-PAD with no music in folder

## v1.0 (2026-02-28) — TyraNight

- Initial release
- MP3 playback with Love2D
- Play/Pause, Next/Previous
- ID3v2 metadata reading (title, artist)
- Embedded cover art display
- Dynamic background color from cover art
- Volume control via D-PAD
