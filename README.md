# obsidian-nexus

3D interactive visualization of an Obsidian vault built in Godot 4.4. Explore your knowledge graph as a navigable cyberpunk environment.

## Layers

1. **Orbital Graph** — Force-directed 3D graph with color-coded nodes representing notes and wikilink edges
2. **Data Cityscape** *(planned)* — Cyberpunk city where folders are districts and notes are towers
3. **Note Corridors** *(planned)* — First-person hallways inside notes with holographic text

## Architecture

| Component | Role |
|-----------|------|
| `VaultDataBus` | Autoload singleton managing vault state and events |
| `VaultParser` | Scans Obsidian vault, extracts markdown structure |
| `NoteGraph` | In-memory graph of notes (nodes) and wikilinks (edges) |
| `GraphLayer` | 3D visualization with force-directed layout |
| `FlightCamera` | First-person camera controller |

## Setup

1. Open the project in Godot 4.4+
2. Set your vault path via `OBSIDIAN_VAULT_PATH` env variable or `user://vault_config.txt`
3. Run the project

## Configuration

- **Renderer:** Vulkan Forward+
- **Resolution:** 2560x1440
- **Target:** 60+ FPS on RTX 4070 Ti

## Tech Stack

- Godot 4.4 (GDScript)
- Custom GLSL shaders (node glow effects)
