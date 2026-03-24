# Specter Scanner

A local-only iPhone app that turns your phone into a paranormal detection device. Point it at porcelain dolls and discover their haunted backstories. Designed for kids — spooky-fun, not horror.

## Overview

Specter Scanner is a ghost detection **simulator** for kids to use at their grandmother's house. The house has glass cases filled with old porcelain dolls. Kids point their phone at the dolls and the app "detects" paranormal activity, building dossiers on each haunted doll.

This is an **investigation/detection simulator**, not a game with scores or catching mechanics. Think ghost hunting TV show for kids.

## Requirements

- **iOS 17.0+**
- **iPhone only** (no iPad layout)
- **Xcode 15.0+**
- No third-party dependencies — Apple frameworks only
- Fully offline — no networking, no accounts, no analytics

## Build & Run

1. Open `SpecterScanner/SpecterScanner.xcodeproj` in Xcode 15+
2. Select your iPhone device or simulator as the run target
3. Build and run (⌘R)

> **Note:** The camera and AR features require a physical device. The simulator will show a placeholder dark view instead of the camera feed.

The app ships with a **placeholder ML model** and **programmatic audio**. It will compile and run out of the box. See below for how to add real assets.

## How to Train the Real ML Model

The app uses a CoreML image classifier to identify individual dolls. Follow these steps to train a model with photos of your actual dolls:

### Step 1: Capture Training Photos

For each doll you want to detect:
- Take **20-30 photos** from various angles, distances, and lighting conditions
- Include close-ups, medium shots, and photos from the distance kids would typically scan
- Capture in the actual environment (grandmother's house) if possible
- Vary the background slightly between shots

### Step 2: Organize Photos

Create a folder structure like this:
```
TrainingData/
├── marguerite/          # 20-30 photos of this doll
├── little_edwin/        # 20-30 photos of this doll
├── the_duchess/         # ... and so on for each doll
├── penelope/
├── captain_ashworth/
├── rosalind/
├── the_twins/
├── baby_mae/
├── professor_wickham/
├── constance/
├── jolly_pete/
├── lady_vesper/
└── background/          # 50+ photos of random items, walls, furniture, empty spaces
```

> **Important:** Folder names must match the `classificationLabel` field in `DollProfiles.json`.

### Step 3: Train with Create ML

1. Open Xcode → File → New → Project → Create ML → Image Classification
2. Drag your `TrainingData/` folder into the training data area
3. Set these recommended parameters:
   - **Max Iterations:** 25 (default is fine for this use case)
   - **Augmentations:** Enable Crop, Rotate, Blur, Exposure, Noise, Flip
4. Click "Train"
5. Review the accuracy metrics — aim for **90%+** validation accuracy
6. Export the trained model: File → Export → Core ML Model

### Step 4: Add to Project

1. Name the exported model `DollClassifier.mlmodel`
2. Replace the placeholder model at `SpecterScanner/ML/DollClassifier.mlmodel`
3. Ensure the model is included in the target's "Copy Bundle Resources" build phase
4. Build and run — the `ClassificationService` will automatically load the new model

### Tips for Better Accuracy

- The `background` category is critical — it prevents false positives on non-doll objects
- If a doll is frequently misidentified, add more training photos of that specific doll
- Include photos with the glass case reflection if kids will scan through glass
- The confidence threshold is set to 75% by default — adjust in `ClassificationService.swift` if needed

## How to Add Real Audio Assets

The app generates placeholder audio programmatically. To replace with real audio:

1. See `Resources/AudioAssetReadme.md` for detailed specifications of each audio file
2. Add `.mp3` files to `SpecterScanner/Resources/Audio/`
3. Ensure files are included in the Xcode target's "Copy Bundle Resources"
4. The `AudioService` automatically prefers real files over programmatic generation

Required files:
- `ambient_drone.mp3` — Looping background hum
- `detection_spike.mp3` — Detection alert sound
- `static_burst.mp3` — Brief static effect
- `evp_whisper_01.mp3` through `evp_whisper_06.mp3` — Eerie whisper effects

## How to Customize Doll Profiles

Edit `SpecterScanner/Resources/DollProfiles.json` to add, remove, or modify doll entries.

Each profile has:
```json
{
  "id": "doll_01",
  "classificationLabel": "marguerite",
  "name": "Marguerite",
  "hauntingType": "whisperer",
  "threatLevel": 3,
  "originStory": "A 2-3 sentence backstory...",
  "documentedActivity": [
    "Observation 1",
    "Observation 2",
    "Observation 3"
  ],
  "status": "under_observation"
}
```

- `classificationLabel` must match the ML model's training folder name
- `hauntingType` options: `whisperer`, `watcher`, `mover`, `weeper`, `mimic`, `trickster`
- `threatLevel`: 1 (Dormant) to 5 (Volatile)
- `status`: `under_observation` or `contained`

## Architecture

The app uses **MVVM** with clear separation of concerns:

- **Models/** — Data structures (DollProfile, HauntingType, ThreatLevel, DetectionEvent)
- **ViewModels/** — Business logic connecting services to views
- **Views/** — SwiftUI interface components
- **Services/** — Camera, ML classification, haptics, audio, proximity simulation
- **Utils/** — Visual effects (glitch shader, waveform generator)
- **ML/** — CoreML model bundle
- **Resources/** — Audio assets, doll profiles JSON, fonts

## Features

- **Launch Ritual** — Atmospheric boot-up sequence with fake system logs
- **Scanner View** — Full-screen camera with ghost-hunting HUD overlays
- **Real-time Detection** — CoreML-powered doll identification through the camera
- **Detection Alerts** — Dramatic full-screen alerts with glitch effects
- **Doll Dossiers** — Classified case file cards with backstories for each doll
- **Case File Collection** — Track which dolls have been discovered
- **Haptic Feedback** — Core Haptics patterns for ambient tension and detection events
- **Programmatic Audio** — Synthesized ambient drones, static bursts, and EVP whispers
- **Scare Level Toggle** — Junior Investigator (friendlier) vs Senior Agent (creepier)

## License

Private project — not for distribution.
