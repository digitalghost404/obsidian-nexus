# Obsidian Nexus

A stunning 3D interactive cyberpunk data vault that transforms your Obsidian knowledge base into a navigable digital world. Built in Godot 4.6 with Vulkan Forward+ rendering.

![Obsidian Nexus](https://img.shields.io/badge/Godot-4.6-blue) ![License](https://img.shields.io/badge/license-MIT-green) ![Platform](https://img.shields.io/badge/platform-Linux-orange)

## Features

### Cyberpunk Data City
- **432 note towers** with detailed server-rack surface shaders (scrolling data lines, indicator lights, circuit traces)
- **Color temperature system** — blue (isolated notes) to orange (hub nodes with 20+ connections)
- **Treemap district layout** — folders mapped to city districts with towers packed inside
- **Tower labels and holographic readouts** above high-connection towers

### Central Nexus Hub
- **Three-tier cylindrical structure** with tower_surface shader panels
- **5 rotating rings** at different heights, speeds, and tilts (blue/orange alternating)
- **Scanner beams** — two rotating lighthouse lasers sweeping the city
- **Energy pulse waves** — expanding rings radiating outward every 3 seconds
- **8 orbiting holographic data panels** with schematic shader
- **3 particle systems** — rising core motes, orbital sparks, base embers
- **Vertical light beams** shooting upward from the crown
- **Vault statistics display** — "432 NODES | 1490 LINKS"

### Visual Effects
- **Circuit floor shader** — procedural PCB traces with animated data pulses, connection pads, tile seams
- **Digital sky dome** — horizon glow, spherical grid, falling data streams, flickering data stars
- **Code rain walls** — Matrix-style falling character glyphs (blue) on boundary walls
- **Hub circuit floor** — concentric ring traces with radial lines and rotating segments
- **40 floating data fragments** — actual note content drifting through the air
- **30 animated overhead data streams** with particle trails
- **1,280+ street-level particles** across a 4x4 grid of emitters
- **Fog volumes** at ground and upper atmosphere levels

### Post-Processing
- **ACES Filmic tonemapping** for cinematic contrast
- **SDFGI** (6 cascades) — global illumination with light bounce
- **SSIL** — screen-space indirect lighting from emissive surfaces
- **SSR** (128 steps) — reflective floor showing tower reflections
- **SSAO** — deep contact shadows between towers
- **Auto-exposure** — camera adapts like human eyes
- **Depth of field** — subtle blur at distance
- **Vignette + chromatic aberration + CRT scan lines** — sci-fi camera lens feel
- **Volumetric fog** with anisotropic scattering and temporal reprojection

### Terminal Boot Sequence
- Hacker-style startup with typing text animation
- Real vault statistics displayed during boot
- System check messages with "OK" confirmations
- Blinking cursor, fade transition to vault
- Audio: typing clicks, system beeps, startup chime

### Note Interaction
- **Hover** any tower — holographic preview panel (title, tags, content preview, connection count)
- **Click** a tower — full note viewer overlay with scrollable content and clickable linked notes
- **Click Nexus Hub** — search interface
- **`/` key** — search all notes by title/content
- **`T` key** — filter by tag
- **`M` key** — search interface
- **`P` key** — print camera position (debug)
- **`ESC`/`Q`** — close overlays

### Audio System
- **Ambient music** — 10-minute looping soundtrack
- **Interaction SFX** — hover blips, click whooshes, close tones, search activation, hub resonance
- **Boot sequence audio** — typing clicks, OK beeps, startup chime

### Minimap HUD
- Bottom-left corner minimap showing player position (white dot) and hub center (blue dot)

## Requirements

- **GPU:** NVIDIA RTX 4070 Ti (or equivalent with 12GB+ VRAM)
- **CPU:** Intel i7-10700K or better
- **RAM:** 32GB recommended
- **Engine:** Godot 4.6.x
- **OS:** Linux (tested on CachyOS/Arch)

## Setup

1. **Install Godot 4.6:**
   ```bash
   # Download from https://godotengine.org/download/linux/
   # Extract and place in PATH
   ```

2. **Import the project:**
   ```bash
   godot --headless --import --path ~/projects/obsidian-nexus
   ```

3. **Run:**
   ```bash
   OBSIDIAN_VAULT_PATH=/path/to/your/obsidian/vault godot --path ~/projects/obsidian-nexus
   ```

## Controls

| Key | Action |
|-----|--------|
| `WASD` | Move |
| `Shift` | Sprint |
| `Mouse` | Look around |
| `Left Click` | Open note / interact |
| `/` | Search notes |
| `T` | Tag filter |
| `M` / `Tab` | Search |
| `ESC` / `Q` | Close overlay |
| `P` | Print position (debug) |

## Architecture

```
obsidian-nexus/
├── autoloads/           # Global singletons
│   ├── vault_data_bus.gd    # Vault parser, cache, filesystem watcher
│   ├── vault_parser.gd      # Markdown/frontmatter/wikilink extraction
│   ├── note_graph.gd        # In-memory graph with force layout
│   ├── layer_manager.gd     # Scene management
│   ├── input_manager.gd     # Raycast hover/click detection
│   ├── ui_manager.gd        # Note viewer, search, minimap, screen FX
│   └── audio_manager.gd     # Music and SFX playback
├── layers/city/         # City layer
│   ├── city_layer.gd/tscn   # Main city scene builder
│   ├── tower_builder.gd     # Note → tower mesh generation
│   ├── nexus_hub.gd         # Central hub structure
│   ├── district_generator.gd # Treemap layout algorithm
│   └── city_beam_renderer.gd # Link beams between towers
├── shaders/             # Custom GLSL shaders
│   ├── tower_surface.gdshader    # Server rack panel aesthetic
│   ├── circuit_floor.gdshader    # PCB trace floor tiles
│   ├── hub_circuit.gdshader      # Concentric ring traces
│   ├── code_rain.gdshader        # Matrix-style falling characters
│   ├── digital_sky.gdshader      # Procedural sky dome
│   ├── wall_schematic.gdshader   # Holographic panel patterns
│   ├── node_glow.gdshader        # Temperature-based node emission
│   ├── hex_grid.gdshader         # Hexagonal overlay pattern
│   ├── holographic_text.gdshader # Scan-line text effect
│   ├── energy_pulse.gdshader     # Link beam pulse animation
│   └── screen_effects.gdshader   # Vignette/aberration/scanlines
├── camera/              # Camera controllers
│   ├── player_camera.gd/tscn # First-person CharacterBody3D
│   └── flight_camera.gd/tscn # 6DOF free-flight
├── audio/               # Sound assets
│   ├── ambient_loop.ogg      # Background music (10min loop)
│   └── sfx_*.ogg             # Interaction sound effects
├── particles/           # GPU particle scenes
├── boot_sequence.gd/tscn    # Terminal startup sequence
└── main.gd/tscn             # Entry point
```

## Configuration

| Setting | Value |
|---------|-------|
| Renderer | Vulkan Forward+ |
| Resolution | 3440x1440 (ultrawide) |
| Window | Borderless fullscreen |
| Target | 60+ FPS |
| VRAM Usage | ~4-5GB |

## Data Pipeline

```
Obsidian vault (markdown files on disk)
  → VaultParser (extracts title, tags, wikilinks, content)
  → NoteGraph (in-memory graph with backlinks, tag index)
  → JSON cache (fast reload on subsequent launches)
  → FileSystemWatcher (hot-reload on vault changes)
  → City layer (towers, beams, hub, particles)
```

## Roadmap

### v2 — AI-Powered Nexus Hub
- [ ] Local LLM integration via Ollama API
- [ ] Voice input via Whisper.cpp (speech-to-text)
- [ ] Voice output via Kokoro TTS (text-to-speech)
- [ ] The Nexus Hub becomes an AI brain you can talk to
- [ ] Context-aware responses using vault knowledge

## Credits

Built with [Godot Engine](https://godotengine.org/) 4.6 and [Claude Code](https://claude.ai/claude-code).
