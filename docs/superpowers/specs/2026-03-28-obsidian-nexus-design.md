# Obsidian Nexus — Design Specification

> A 3D interactive data vault for navigating 432 notes of knowledge in cyberpunk space

## 1. Project Overview

**Obsidian Nexus** transforms an Obsidian vault into a navigable 3D cyberpunk environment built in Godot 4 with a Vulkan renderer. The user moves through three distinct visual layers — an orbital knowledge graph, a neon data cityscape, and first-person corridors — each representing the same 432 notes at different scales of immersion.

| Attribute | Value |
|-----------|-------|
| Engine | Godot 4.x (Vulkan Forward+) |
| Target Hardware | RTX 4070 Ti, i7-10700K, 32GB RAM |
| Target Resolution | 1440p @ 60+ FPS |
| Vault Size | 432 notes, 1,541 links, 58 folders, 489 tags |
| Data Source | Local Obsidian vault (markdown on disk) |
| Data Sync | Hybrid: parse + cache + filesystem watch for hot-reload |
| Architecture | Layer Scenes + VaultDataBus (autoload singleton) |

## 2. The Three Layers

### 2.1 Orbital Graph (Macro Layer)

A 3D force-directed graph floating in deep space. Each note is a glowing node — size scales with backlink count, color shifts from cold blue (isolated) to hot orange/white (hub nodes like `facility-7` at 25 backlinks). Links are visible edges rendered as energy filaments. Clusters form naturally around high-connectivity hubs.

- **Camera:** Free-flight (6DOF) — orbit, pan, zoom through the constellation
- **Transition down:** Click a cluster → camera dives through it, city materializes around you
- **Atmosphere:** Deep void, sparse blue fog, distant star-field particle backdrop
- **Color temp:** Cold — blues, indigos, cyan accents. Hub nodes glow warm as exceptions.

### 2.2 Data Cityscape (Mid Layer)

A cyberpunk cityscape. Each folder is a distinct district with an architectural identity. Each note is a monolith/tower — height scales with word count, emission intensity with connection count. Links between notes in the same district are visible as light beams at street level. Cross-district links arc overhead like power lines.

- **Camera:** Grounded first-person (WASD + mouse look) — walk streets between towers
- **Transition up:** Press `Space` → camera ascends, city shrinks, graph fades in
- **Transition down:** Approach a tower and interact → camera enters, corridor scene loads
- **Atmosphere:** Dense volumetric fog, neon signs, ambient particle motes, reflective wet streets
- **Color temp:** Mixed — blue structural lighting, orange data emission, purple ambient fog

### 2.3 Note Corridors (Micro Layer)

First-person corridors inside a data structure. The current note's content is rendered on the walls as holographic text with scan-line effects. Outgoing links are doorways/portals at the end of hallways — walk through one to travel to the linked note. Backlinks appear as sealed doors behind you with titles visible. Tags are glowing symbols embedded in the floor/ceiling.

- **Camera:** Grounded first-person — walk the hallway, turn to read walls
- **Transition up:** Press `Space` → camera pulls back through the ceiling into the city
- **Transition sideways:** Walk through a link-doorway → corridor morphs into the linked note
- **Atmosphere:** Tight, moody — fog hugging the floor, warm amber glow, code rain on walls
- **Color temp:** Warm — orange/amber text, red accent lighting, ember particles

## 3. Data Pipeline

### 3.1 VaultDataBus (Autoload Singleton)

Central data authority. Parses the Obsidian vault, maintains the knowledge graph in memory, and signals layer scenes when data changes.

**First Launch:**
```
Obsidian vault (disk) → VaultParser → NoteGraph (in-memory) → Cache (JSON) → Signal layers to build
```

**Subsequent Launches:**
```
Cache (JSON) → NoteGraph (in-memory) → Diff against vault (disk) → Patch changed notes → Signal layers
```

**Hot Reload (vault changes while running):**
```
FileSystemWatcher detects .md change → VaultParser re-parses single file → NoteGraph patches → emit note_updated(note_id) → active layer rebuilds that single node/tower/panel
```

### 3.2 Note Data Model

| Field | Source | Used By |
|-------|--------|---------|
| title | Filename / frontmatter | All layers (labels) |
| content | Markdown body | Corridor (wall text) |
| folder | File path | City (district assignment) |
| tags[] | Frontmatter + inline #tags | Tag filter, floor symbols |
| outgoing_links[] | `[[wikilinks]]` in body | Graph edges, city beams, corridor doorways |
| backlinks[] | Computed inverse of outgoing | Graph edges, corridor sealed doors |
| word_count | Body length | City (tower height) |
| connection_count | outgoing + backlinks | Graph (node size), City (emission), color temperature |
| last_modified | File mtime | Cache invalidation, hot-reload |

## 4. Navigation & Interaction

### 4.1 Movement: Grounded + Elevate

- **City/Corridor:** First-person — WASD move, mouse look, Shift sprint
- **Graph:** Free-flight — WASD + QE (up/down), mouse look, scroll for speed
- **Layer shift:** `Space` to ascend (grounded → graph), click node to descend (graph → city/corridor)
- **Transitions:** Smooth 1.5s camera animation with motion blur + DoF during travel

### 4.2 Interactions

| Feature | Trigger | Behavior |
|---------|---------|----------|
| Hover Preview | Crosshair over note (any layer) | Holographic panel: title, tags, connection count, first ~200 chars. Glitch-in animation. |
| Focus & Expand | Click note | Camera orbits to face it. Panels unfold with full rendered markdown. Connected notes pulse. Esc to close. |
| Link Travel | Click link while focused | Camera travels along the beam/doorway to the connected note. 1s cinematic flight. |
| Search Beacon | `/` key | Search bar overlay. Matches light up as beacons across world. Non-matches dim to 10% opacity. Select → warp. |
| Tag Filter | `T` key | Tag wheel (489 tags). Select tag(s) → non-matching notes fade to ghost wireframes. Stackable. |

## 5. Visual Effects Pipeline

**Target:** 1440p @ 60+ FPS — estimated ~8-9GB VRAM with all effects on RTX 4070 Ti (12GB).

| Effect | Godot Feature | Usage | GPU Cost |
|--------|--------------|-------|----------|
| Volumetric Fog | VolumetricFog + FogVolume | Dense in corridors, sparse in graph. Light shafts from data cores. | Med-High |
| Bloom & Glow | Environment Glow | All emissive surfaces bleed light. Notes glow by connection count. | Low-Med |
| GPU Particles | GPUParticles3D | Ambient motes, link sparks, cascade on note open, corridor dust, embers. | Low |
| SDFGI | Environment SDFGI | Bounced light — orange node bleeds onto surfaces, blue reflects off floors. | High |
| SSR | Environment SSR | Reflective corridor floors, wet city streets. | Med |
| SSAO | Environment SSAO | Contact shadows under structures, between cubes, in corners. | Low-Med |
| DoF | Camera3D DoF | **Contextual:** active during Focus & Expand, Link Travel. Off during navigation. | Low-Med |
| Custom Shaders | Shader language | Holographic text, code rain, energy pulses, hex grids, chromatic aberration on layer shift. | Varies |

### 5.1 Key Custom Shaders

- **Holographic Text:** Markdown rendered to viewport texture → applied to wall mesh with scan-line overlay, subtle horizontal jitter, and alpha flicker
- **Code Rain:** Procedural matrix-style falling characters on corridor walls — uses a glyph texture atlas + vertex shader for scroll
- **Energy Pulse:** Link beams pulse with a traveling wave (sine-based UV offset on emission channel) — speed indicates link strength
- **Hex Grid:** Procedural hexagonal pattern on building surfaces — subtle, overlaid on base material with additive blending
- **Layer Shift Aberration:** Chromatic aberration + screen distortion during the 1.5s layer transition — sells the "phasing between dimensions" feel

## 6. Project Architecture

### 6.1 Scene Tree

```
Autoloads (global singletons):
├── VaultDataBus — vault parser, cache, note graph, filesystem watcher
├── LayerManager — handles transitions between Graph/City/Corridor scenes
├── InputManager — maps inputs, manages mode switching (grounded vs flight)
└── UIManager — search overlay, tag wheel, hover previews (CanvasLayer)

Layer Scenes (swapped by LayerManager):
├── GraphLayer.tscn — force-directed graph, node meshes, edge lines
├── CityLayer.tscn — district layout, tower meshes, street-level environment
└── CorridorLayer.tscn — hallway generator, wall panels, doorway portals

Shared Resources:
├── shaders/ — holographic_text.gdshader, code_rain.gdshader, energy_pulse.gdshader, hex_grid.gdshader
├── materials/ — base materials for nodes, buildings, walls, floors
├── particles/ — GPU particle scenes (motes, sparks, embers, dust)
└── themes/ — WorldEnvironment presets per layer (fog, GI, SSR settings)
```

### 6.2 Data Flow

**Startup:**
```
main.gd → VaultDataBus.initialize(vault_path) → parse/cache → LayerManager.load_default_layer()
```

**Layer Transition (ascend):**
```
InputManager detects Space → LayerManager.transition_to(GraphLayer)
  → capture current camera transform
  → fade out CityLayer, animate camera to graph position
  → instantiate GraphLayer, feed VaultDataBus data
  → fade in GraphLayer, free CityLayer
```

**Note Focus:**
```
Player clicks note → active layer emits note_focused(note_id)
  → UIManager shows expanded panel (rendered markdown)
  → VaultDataBus.get_links(note_id) → active layer highlights connected notes
```

**Hot Reload:**
```
FileSystemWatcher detects change → VaultDataBus.reload_note(path)
  → re-parse single .md → update NoteGraph → emit note_updated(note_id)
  → active layer rebuilds that single node/tower/panel
```

## 7. Spatial Layout

### 7.1 Graph Layer — Force-Directed 3D

Computed at parse time, cached with positions. Uses a spring-electric model: linked notes attract, all notes repel. Run for ~500 iterations on first parse. Hub nodes naturally center, clusters form by connectivity. Positions stored in cache for instant reload.

### 7.2 City Layer — District Grid

Each folder maps to a rectangular district. Districts arranged by a treemap algorithm (folder size = area). Within each district, notes are placed in a grid — tower height = word count, spacing proportional to connection density. Streets form naturally between grid rows. District boundaries marked by light-wall fences with the folder name as a neon sign.

### 7.3 Corridor Layer — Procedural Hallway

Generated per-note on demand. Main hallway length scales with content length. Wall panels placed every N characters of content. Outgoing links spawn branching hallways ahead (doorways with target note title). Backlinks spawn sealed doors behind. T-junctions for notes with many links. The layout is deterministic from the note's data so it's always consistent.

## 8. Performance Strategy

| Technique | Layer | Purpose |
|-----------|-------|---------|
| LOD (Level of Detail) | Graph, City | Distant notes render as simple glowing points. Detail increases on approach. |
| Frustum culling | All | Godot built-in. Only visible nodes are rendered. |
| Instanced rendering | Graph, City | MultiMeshInstance3D for note nodes/towers — one draw call for hundreds of identical meshes. |
| Shader LOD | City | Distant buildings use simplified shaders (no hex grid, no scan lines). |
| Particle budgets | All | Max particle counts per layer. Corridor: 5K. City: 20K. Graph: 10K. |
| Lazy corridor gen | Corridor | Corridors built on entry, freed on exit. Only 1 corridor in memory at a time. |
| Async hot-reload | All | File parsing on thread. Scene update on main thread. No frame drops during reload. |

## 9. Color Temperature System

Color encodes meaning across all layers:

| Connection Count | Color | Temperature | Examples |
|-----------------|-------|-------------|----------|
| 0 (isolated) | Deep blue | Cold | 26 orphan notes |
| 1-3 (low) | Blue-indigo | Cool | Average notes (3.58 avg connections) |
| 4-10 (medium) | Purple-violet | Neutral | Well-connected notes |
| 11-20 (high) | Orange-amber | Warm | Key topic notes |
| 20+ (hub) | Orange-white | Hot | facility-7 (25), the foundation (25), the liberators (24) |

This gradient is applied consistently: node glow in graph, tower emission in city, ambient light in corridors.
