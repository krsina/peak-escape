extends Node

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var sounds: Dictionary = {}

const SFX_POOL_SIZE := 8
const SAMPLE_RATE := 22050

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	music_player_b = AudioStreamPlayer.new()
	music_player_b.bus = "Master"
	add_child(music_player_b)
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
	_generate_sounds()

func _generate_sounds() -> void:
	sounds["jump"] = _make_tone(480, 0.1, 0.25, 600)
	sounds["land"] = _make_tone(120, 0.08, 0.15, 80)
	sounds["land_hard"] = _make_tone(80, 0.15, 0.22, 50)
	sounds["grab"] = _make_noise(0.06, 0.12)
	sounds["slide"] = _make_noise(0.3, 0.05)
	sounds["hurt"] = _make_tone(300, 0.25, 0.2, 120)
	sounds["death"] = _make_tone(200, 0.6, 0.22, 60)
	sounds["pickup"] = _make_arpeggio([523, 659, 784], 0.08, 0.18)
	sounds["checkpoint"] = _make_arpeggio([392, 494, 587, 784], 0.12, 0.15)
	sounds["helicopter"] = _make_arpeggio([523, 659, 784, 1047], 0.2, 0.2)
	sounds["menu_select"] = _make_tone(660, 0.05, 0.1, 660)
	sounds["menu_confirm"] = _make_tone(880, 0.1, 0.12, 880)
	sounds["crumble"] = _make_noise(0.4, 0.15)
	sounds["wind"] = _make_noise(0.8, 0.06)
	sounds["use_item"] = _make_tone(440, 0.15, 0.12, 600)
	sounds["wall_jump"] = _make_tone(520, 0.1, 0.22, 700)
	sounds["mantle"] = _make_tone(350, 0.12, 0.12, 450)
	sounds["heal"] = _make_arpeggio([440, 554, 659], 0.1, 0.15)
	sounds["spring"] = _make_tone(300, 0.15, 0.2, 800)

func play_sfx(sound_name: String) -> void:
	if sound_name not in sounds:
		push_warning("AudioManager: unknown sound '%s'" % sound_name)
		return
	var vol: float = SaveManager.data.get("sfx_volume", 0.4)
	if vol <= 0.0:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sounds[sound_name]
			p.volume_db = linear_to_db(vol)
			p.play()
			return
	sfx_players[0].stream = sounds[sound_name]
	sfx_players[0].volume_db = linear_to_db(vol)
	sfx_players[0].play()

func _make_tone(freq: float, duration: float, amp: float, end_freq: float = -1.0) -> AudioStreamWAV:
	if end_freq < 0:
		end_freq = freq
	var samples := int(SAMPLE_RATE * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = SAMPLE_RATE
	var buf := PackedByteArray()
	buf.resize(samples)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var p := t / duration
		var f := lerpf(freq, end_freq, p)
		var envelope := minf(1.0, minf(t * 40.0, (duration - t) * 40.0))
		var v := sin(t * f * TAU) * amp * envelope
		buf[i] = int(clampf((v * 0.5 + 0.5) * 255.0, 0, 255))
	audio.data = buf
	return audio

func _make_noise(duration: float, amp: float) -> AudioStreamWAV:
	var samples := int(SAMPLE_RATE * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = SAMPLE_RATE
	var buf := PackedByteArray()
	buf.resize(samples)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var envelope := minf(1.0, minf(t * 20.0, (duration - t) * 15.0))
		var v := (randf() * 2.0 - 1.0) * amp * envelope
		buf[i] = int(clampf((v * 0.5 + 0.5) * 255.0, 0, 255))
	audio.data = buf
	return audio

func _make_arpeggio(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var total := note_dur * freqs.size()
	var samples := int(SAMPLE_RATE * total)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = SAMPLE_RATE
	var buf := PackedByteArray()
	buf.resize(samples)
	for i in samples:
		var t := float(i) / SAMPLE_RATE
		var note_idx := mini(int(t / note_dur), freqs.size() - 1)
		var note_t := fmod(t, note_dur)
		var envelope := minf(1.0, minf(note_t * 40.0, (note_dur - note_t) * 20.0))
		var v := sin(note_t * freqs[note_idx] * TAU) * amp * envelope
		buf[i] = int(clampf((v * 0.5 + 0.5) * 255.0, 0, 255))
	audio.data = buf
	return audio
