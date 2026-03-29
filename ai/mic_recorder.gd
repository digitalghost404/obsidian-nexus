extends Node
class_name MicRecorder

## Microphone recording via AudioEffectCapture on a dedicated "MicCapture" bus.
## Records raw PCM 16-bit 16kHz mono audio and exports as WAV bytes.

signal recording_level(amplitude: float)

const SAMPLE_RATE: int = 16000
const MIX_RATE: int = 44100  # Godot's internal mix rate (AudioServer default)

var _capture_effect: AudioEffectCapture
var _bus_index: int = -1
var _is_recording: bool = false
var _recorded_frames: PackedVector2Array = PackedVector2Array()
var _level_timer: float = 0.0
const LEVEL_UPDATE_INTERVAL: float = 0.05  # 20 Hz updates for waveform display

func _ready() -> void:
	_setup_audio_bus()

func _setup_audio_bus() -> void:
	# Create a dedicated audio bus for mic capture
	var bus_name: String = "MicCapture"
	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index == -1:
		_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_bus_index)
		AudioServer.set_bus_name(_bus_index, bus_name)

	# Mute the bus so captured audio doesn't play through speakers
	AudioServer.set_bus_mute(_bus_index, true)

	# Add AudioEffectCapture to the bus
	_capture_effect = AudioEffectCapture.new()
	# Clear any existing effects first
	while AudioServer.get_bus_effect_count(_bus_index) > 0:
		AudioServer.remove_bus_effect(_bus_index, 0)
	AudioServer.add_bus_effect(_bus_index, _capture_effect)

	print("MicRecorder: audio bus '%s' (index %d) configured with capture effect" % [bus_name, _bus_index])

func start_recording() -> void:
	if _is_recording:
		return
	_recorded_frames.clear()
	_capture_effect.clear_buffer()
	_is_recording = true
	print("MicRecorder: recording started")

func stop_recording() -> PackedByteArray:
	if not _is_recording:
		return PackedByteArray()
	_is_recording = false

	# Flush remaining frames from capture buffer
	_flush_capture_buffer()

	print("MicRecorder: recording stopped, %d frames captured" % _recorded_frames.size())

	if _recorded_frames.size() == 0:
		push_warning("MicRecorder: no audio frames captured — is the microphone connected?")
		return PackedByteArray()

	# Convert stereo frames to mono 16-bit PCM, downsample from MIX_RATE to SAMPLE_RATE
	var mono_samples: PackedFloat32Array = _to_mono_resampled(_recorded_frames)
	var wav_bytes: PackedByteArray = _encode_wav(mono_samples)
	return wav_bytes

func _process(delta: float) -> void:
	if not _is_recording:
		return

	_flush_capture_buffer()

	# Emit amplitude levels at regular intervals for the listening indicator
	_level_timer += delta
	if _level_timer >= LEVEL_UPDATE_INTERVAL:
		_level_timer = 0.0
		var amplitude: float = _compute_recent_amplitude()
		recording_level.emit(amplitude)

func _flush_capture_buffer() -> void:
	if not _capture_effect:
		return
	var frames_available: int = _capture_effect.get_frames_available()
	if frames_available > 0:
		var frames: PackedVector2Array = _capture_effect.get_buffer(frames_available)
		_recorded_frames.append_array(frames)

func _compute_recent_amplitude() -> float:
	## Returns the RMS amplitude of the most recent ~1024 frames
	var count: int = mini(_recorded_frames.size(), 1024)
	if count == 0:
		return 0.0
	var sum: float = 0.0
	var start: int = _recorded_frames.size() - count
	for i in range(start, _recorded_frames.size()):
		var frame: Vector2 = _recorded_frames[i]
		var mono: float = (frame.x + frame.y) * 0.5
		sum += mono * mono
	return sqrt(sum / float(count))

func _to_mono_resampled(frames: PackedVector2Array) -> PackedFloat32Array:
	## Converts stereo frames at MIX_RATE to mono at SAMPLE_RATE using linear interpolation
	var ratio: float = float(SAMPLE_RATE) / float(MIX_RATE)
	var output_length: int = int(frames.size() * ratio)
	var output := PackedFloat32Array()
	output.resize(output_length)

	for i in range(output_length):
		var src_pos: float = float(i) / ratio
		var src_index: int = int(src_pos)
		var frac: float = src_pos - float(src_index)

		var sample_a: float = 0.0
		var sample_b: float = 0.0
		if src_index < frames.size():
			sample_a = (frames[src_index].x + frames[src_index].y) * 0.5
		if src_index + 1 < frames.size():
			sample_b = (frames[src_index + 1].x + frames[src_index + 1].y) * 0.5
		else:
			sample_b = sample_a

		output[i] = lerpf(sample_a, sample_b, frac)

	return output

func _encode_wav(samples: PackedFloat32Array) -> PackedByteArray:
	## Encodes float32 PCM samples into a WAV file (16-bit, mono, SAMPLE_RATE Hz)
	var num_samples: int = samples.size()
	var bytes_per_sample: int = 2  # 16-bit
	var data_size: int = num_samples * bytes_per_sample
	var file_size: int = 36 + data_size  # WAV header is 44 bytes, file_size = total - 8

	var wav := PackedByteArray()
	wav.resize(44 + data_size)

	# RIFF header
	wav[0] = 0x52; wav[1] = 0x49; wav[2] = 0x46; wav[3] = 0x46  # "RIFF"
	wav.encode_u32(4, file_size)
	wav[8] = 0x57; wav[9] = 0x41; wav[10] = 0x56; wav[11] = 0x45  # "WAVE"

	# fmt subchunk
	wav[12] = 0x66; wav[13] = 0x6D; wav[14] = 0x74; wav[15] = 0x20  # "fmt "
	wav.encode_u32(16, 16)  # Subchunk1Size (16 for PCM)
	wav.encode_u16(20, 1)   # AudioFormat (1 = PCM)
	wav.encode_u16(22, 1)   # NumChannels (mono)
	wav.encode_u32(24, SAMPLE_RATE)  # SampleRate
	wav.encode_u32(28, SAMPLE_RATE * bytes_per_sample)  # ByteRate
	wav.encode_u16(32, bytes_per_sample)  # BlockAlign
	wav.encode_u16(34, 16)  # BitsPerSample

	# data subchunk
	wav[36] = 0x64; wav[37] = 0x61; wav[38] = 0x74; wav[39] = 0x61  # "data"
	wav.encode_u32(40, data_size)

	# Write PCM samples as signed 16-bit integers
	for i in range(num_samples):
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var int_sample: int = int(clamped * 32767.0)
		wav.encode_s16(44 + i * 2, int_sample)

	return wav

func is_recording() -> bool:
	return _is_recording
