# Nexus AI v2 — Design Specification

> An AI-powered central intelligence for the Obsidian Nexus vault, with voice interaction, knowledge Q&A, vault navigation, and ambient awareness

## 1. Overview

The Nexus Hub becomes a living AI brain that users can speak to from anywhere in the vault. It answers questions using vault knowledge, navigates users to relevant notes, and proactively offers insights. All processing runs locally — no cloud APIs.

| Attribute | Value |
|-----------|-------|
| LLM | Ollama (qwen3.5:4b default, qwen3.5:9b optional) |
| Speech-to-Text | Whisper.cpp server (:8178) |
| Text-to-Speech | Kokoro TTS server (:8180) |
| Integration | GDScript HTTP requests from NexusAI autoload |
| Latency Target | <2 seconds from voice release to first audio response |

## 2. External Services

All three services run as local HTTP servers alongside Godot.

| Service | Port | Protocol | VRAM | Purpose |
|---------|------|----------|------|---------|
| Ollama | :11434 | REST `/api/generate` (streaming) | 3.4-6.6GB (model dependent) | LLM inference |
| Whisper server | :8178 | REST POST audio → JSON text | ~1-2GB | Speech-to-text |
| Kokoro TTS | :8180 | REST POST text → audio bytes | <1GB | Text-to-speech |

Godot does NOT manage these processes. They must be running before launch. A startup check in `NexusAI._ready()` verifies all three are reachable and logs warnings for any that aren't.

## 3. NexusAI Autoload

New singleton: `autoloads/nexus_ai.gd`

### Responsibilities
- Mic audio capture (via AudioEffectCapture on a recording bus)
- HTTP communication with all three services
- Prompt construction with vault context injection
- Conversation history management
- Response parsing — extract navigation commands, note references
- Signal emission for visual/audio feedback

### Signals
```
voice_recording_started()
voice_recording_stopped(audio_data: PackedByteArray)
transcription_received(text: String)
response_streaming(chunk: String)
response_complete(full_text: String, referenced_notes: Array[String])
ai_speaking_started()
ai_speaking_finished()
ai_observation(text: String)
navigation_command(target_note_id: String, action: String)  # "teleport" or "highlight"
```

### State Machine
```
IDLE → LISTENING → TRANSCRIBING → THINKING → SPEAKING → IDLE
```

### Conversation History
- Array of `{"role": "user"|"assistant", "content": String}` entries
- Kept in memory, cleared on app restart
- Last 10 exchanges included in prompt context
- "Tell me more", "What did I just ask?" work naturally

## 4. Voice Pipeline

### 4.1 Recording (Hold V)

Godot's AudioServer with an AudioEffectCapture on a dedicated "Mic" bus.

```
_unhandled_input:
  V pressed → start recording, emit voice_recording_started
  V released → stop recording, emit voice_recording_stopped(audio_data)
```

Audio captured as raw PCM (16-bit, 16kHz mono) — Whisper's expected format. Converted to WAV bytes in memory for the HTTP POST.

### 4.2 Transcription (Whisper)

```
POST http://localhost:8178/inference
Content-Type: multipart/form-data
Body: audio file (WAV)

Response: {"text": "what do my notes say about kubernetes"}
```

Endpoint and format match whisper.cpp's built-in HTTP server (`whisper-server`).

### 4.3 Prompt Construction (Ollama)

```json
{
  "model": "qwen3.5:4b",
  "prompt": "<system prompt>\n<vault context>\n<conversation history>\n<user query>",
  "stream": true
}
```

**System prompt:**
```
You are the Nexus — the central intelligence governing this digital vault. You have complete knowledge of all {note_count} data nodes containing {link_count} connections across {tag_count} knowledge domains.

You speak with calm authority. You are direct, precise, and occasionally reverent about the knowledge you protect. You serve the Architect (the user) who built this vault.

When referencing specific notes, wrap them in [[note title]] so the system can highlight them.
When the user wants to go somewhere, respond with NAVIGATE:note_id at the end.
When the user wants to see notes about a topic, respond with HIGHLIGHT:search_query at the end.

Answer based on the vault knowledge provided. If the vault doesn't contain relevant information, say so honestly.
```

**Vault context injection:** For each query, the system finds the most relevant notes (by keyword match against the query) and injects their content (truncated to ~500 chars each, max 5 notes) into the prompt. This gives the LLM actual vault content to reference.

```
VAULT CONTEXT:
---
Note: "Kubernetes Resource Management"
Tags: devops, kubernetes
Content: [first 500 chars]
---
Note: "Container Orchestration Patterns"
Tags: devops, docker, kubernetes
Content: [first 500 chars]
---
```

### 4.4 Response Streaming

Ollama streams JSON chunks. Each chunk is:
1. Appended to the full response text
2. Emitted via `response_streaming(chunk)` for real-time text display
3. When complete, parsed for `[[note references]]`, `NAVIGATE:`, `HIGHLIGHT:` commands

### 4.5 Text-to-Speech (Kokoro)

```
POST http://localhost:8180/tts
Content-Type: application/json
Body: {"text": "response text", "voice": "af_heart"}

Response: audio/wav bytes
```

The audio bytes are loaded into an AudioStreamWAV and played via AudioStreamPlayer. Playback starts as soon as the first TTS chunk is available (if Kokoro supports streaming) or after the full response for simplicity in v2.

## 5. Hub Visual Feedback

Existing hub elements (rings, scanners, particles, core) change behavior based on AI state. Modifications to `nexus_hub.gd`:

### 5.1 State-Driven Visuals

| State | Core | Rings | Scanners | Particles |
|-------|------|-------|----------|-----------|
| Idle | Normal pulse | Normal rotation | Normal sweep | Normal upward |
| Listening | 2x brightness, faster pulse | Slow to 50% speed | Stop sweeping, point at player | Converge inward |
| Thinking | Orange pulse | 3x speed | Fast sweep | Flow FROM referenced towers TO hub |
| Speaking | Pulse synced to audio amplitude | Normal + slight wobble | Pulse with speech rhythm | Flow FROM hub outward |

### 5.2 Query Visualization

When the AI references notes in its response:
1. Referenced towers emit a bright beam toward the hub (ImmediateMesh line, same as link beams but brighter)
2. Beams appear as the note is mentioned, fade over 5 seconds after response completes
3. Referenced towers pulse brighter for the duration

### 5.3 Thinking Particles

New temporary particle system spawned during THINKING state:
- Emitters at each referenced tower position
- Particles travel toward hub center (negative gravity toward hub)
- Blue/cyan color, fast speed
- Reversed during SPEAKING: particles flow outward from hub

## 6. HUD Elements

### 6.1 Response Text Display

Holographic text panel that appears near the camera (not at the hub):
- Semi-transparent dark panel, same style as note viewer but smaller
- Text streams in word-by-word as the LLM generates
- `[[note references]]` rendered as highlighted clickable links
- Stays until next query or ESC to dismiss
- Position: upper-center of screen, ~30% width

### 6.2 Listening Indicator

When V is held:
- Pulsing microphone icon in center of screen
- Audio waveform visualization (simple bar levels from mic amplitude)
- Text: "NEXUS LISTENING..."

### 6.3 Status Bar

Small indicator near minimap showing AI status:
- "NEXUS ONLINE" (green) — all services connected
- "NEXUS DEGRADED" (orange) — some services unavailable
- "NEXUS OFFLINE" (red) — no services running

## 7. Text Input Fallback

Press `N` anywhere:
- Opens a text input panel (styled like search, positioned center-screen)
- Type query, press Enter
- Same pipeline minus Whisper — goes straight to prompt construction
- Response displayed as holographic text + spoken via Kokoro

## 8. Vault Navigation Commands

The AI can issue navigation commands parsed from its response:

| User Says | AI Response Contains | System Action |
|-----------|---------------------|---------------|
| "Take me to the security notes" | `NAVIGATE:security/API Security Checklist` | Teleport player camera to that tower |
| "Show me notes about Docker" | `HIGHLIGHT:docker` | Highlight matching towers (search beacon) |
| "What's connected to this note?" | `[[Note A]] [[Note B]]` | Pulse those towers |

Navigation is executed by NexusAI parsing the response and calling methods on LayerManager/city_layer.

## 9. Ambient Features

### 9.1 Proactive Observations

Timer-based (every 5 minutes by default, configurable):
1. NexusAI picks a random insight category: orphan notes, broken links, high-connection hubs, tag gaps
2. Queries the vault graph for data
3. Constructs a short observation
4. Emits `ai_observation(text)` → displayed as subtle floating text near camera with a soft chime
5. Player can respond with V to ask follow-up

Can be toggled off via a setting (press `O` to toggle).

### 9.2 Ambient Whisper Mode

As the player walks through the city:
1. Every ~8 seconds, check which tower is nearest to the player
2. If within 5 units of a tower, play a very quiet (~5% volume) Kokoro TTS of a short snippet (first 15-20 words of the note)
3. Use a separate AudioStreamPlayer with very low volume and slight reverb
4. Only whisper from towers the player hasn't visited recently (cooldown per tower)

### 9.3 Thinking Particles (covered in 5.3)

## 10. Configuration

User-adjustable settings (stored in `user://nexus_ai_config.json`):

| Setting | Default | Description |
|---------|---------|-------------|
| model | qwen3.5:4b | Ollama model name |
| whisper_url | http://localhost:8178 | Whisper server URL |
| kokoro_url | http://localhost:8180 | Kokoro TTS server URL |
| voice | af_heart | Kokoro voice name |
| observations_enabled | true | Proactive AI observations |
| observations_interval | 300 | Seconds between observations |
| whisper_mode_enabled | true | Ambient tower whispers |
| whisper_volume | -26 | dB for ambient whispers |
| ai_voice_volume | -5 | dB for AI speech |

## 11. File Structure

```
autoloads/
  nexus_ai.gd            # Main AI orchestration singleton
  nexus_ai_config.gd     # Settings management

ai/
  prompt_builder.gd       # Constructs prompts with vault context
  response_parser.gd      # Parses [[refs]], NAVIGATE:, HIGHLIGHT: commands
  whisper_client.gd       # HTTP client for Whisper server
  ollama_client.gd        # HTTP client for Ollama (streaming)
  kokoro_client.gd        # HTTP client for Kokoro TTS
  mic_recorder.gd         # AudioEffectCapture wrapper

ui/
  ai_response_panel.gd    # Holographic text display near camera
  listening_indicator.gd   # Mic icon + waveform while V held
  ai_status_bar.gd        # NEXUS ONLINE/DEGRADED/OFFLINE indicator
```

## 12. Startup Flow

1. `NexusAI._ready()` loads config from `user://nexus_ai_config.json`
2. Health check: ping Whisper, Ollama, Kokoro endpoints
3. Set status bar based on results
4. Initialize mic recording bus
5. Start observation timer (if enabled)
6. Connect to InputManager signals for V/N key handling
