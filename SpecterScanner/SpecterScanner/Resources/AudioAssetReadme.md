# Audio Asset Specifications — Specter Scanner

All audio files should be placed in `SpecterScanner/Resources/Audio/`.

## Required Audio Files

| Filename | Duration | Description |
|---|---|---|
| `ambient_drone.mp3` | 30-60s loop | Low, droning hum. Continuous bass tone around 80-120Hz with slow oscillation. Think furnace hum mixed with distant wind. Should loop seamlessly. Not scary, just atmospheric. |
| `detection_spike.mp3` | 1-2s | Sharp rising tone sweep from low to mid frequency (200Hz → 2kHz) over ~0.3s, followed by a brief burst of static crackle. Plays when an entity is positively detected. |
| `static_burst.mp3` | 0.5-1s | Brief burst of white noise / TV static. Used for transition glitch effects. Should start and end abruptly. |
| `evp_whisper_01.mp3` | 2-4s | Breathy, reverbed sound. NOT real words—just pitch-shifted sine tones with heavy reverb that vaguely suggest a whisper. Quiet and eerie. |
| `evp_whisper_02.mp3` | 2-4s | Similar to 01 but different pitch/timing. Slightly higher pitch. |
| `evp_whisper_03.mp3` | 2-4s | Variant with a slow fade-in quality, like something approaching. |
| `evp_whisper_04.mp3` | 2-4s | Two quick breathy blips with reverb tail. |
| `evp_whisper_05.mp3` | 2-4s | Lowest pitch variant. Almost sounds like a sigh. |
| `evp_whisper_06.mp3` | 2-4s | Longest variant with slow undulation. |

## Suggested Free Sources (CC0 / Royalty-Free)

- **Freesound.org** — Search for "drone ambient", "static burst", "whisper reverb", "EMF sweep"
- **Pixabay Audio** — Free sound effects, no attribution required
- **Mixkit.co** — Free sound effects library
- **BBC Sound Effects** — Some available under RemArc license for personal use
- **ZapSplat.com** — Free with attribution tier

## Volume Guidelines

**IMPORTANT: This app is designed for kids. No jump scares.**

- All audio should be mixed at moderate volume
- `ambient_drone.mp3`: Play at 20-30% system volume
- `detection_spike.mp3`: Play at 40-50% system volume (louder than ambient but not startling)
- `static_burst.mp3`: Play at 30-40% system volume
- `evp_whisper_*.mp3`: Play at 25-35% system volume

## Programmatic Fallbacks

The app includes programmatic audio generation as placeholders using `AVAudioEngine`. These are automatically used when the corresponding `.mp3` files are not found in the bundle:

- **Ambient drone**: Low sine wave (80-120Hz) with slow LFO modulation
- **Detection spike**: Linear frequency sweep from 200Hz to 2kHz over 0.3 seconds
- **Static burst**: White noise buffer played for 0.5 seconds
- **EVP whispers**: Reverbed sine wave blips at varying pitches with delay effects

To use real audio files, simply add the `.mp3` files to the `Resources/Audio/` folder and ensure they are included in the Xcode target's "Copy Bundle Resources" build phase. The `AudioService` will automatically prefer real files over programmatic generation.

## Audio Format Requirements

- Format: MP3 or M4A (MP3 preferred for compatibility)
- Sample rate: 44.1kHz
- Channels: Mono (stereo acceptable but unnecessary)
- Bit depth: 16-bit minimum
