class_name JellySound
extends Node

var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds = {}
var current = ""
var profile: JellyProfile
var voice_index = 0

func setup(p: JellyProfile):
	profile = p
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 12:
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for key in ["hover","click","back","charge","dash","push","hit","bounce","absorb","pickup","heal","hurt","win","lose","warning","jelly_tap","jelly_slam","shell_tink","jelly_pop"]:
		sounds[key] = load("res://assets/audio/"+key+".wav")
	update_volume()

func update_volume():
	if music:
		music.volume_db = linear_to_db(maxf(0.0001,profile.data.master*profile.data.music*0.65))

func play(key: String):
	if DisplayServer.get_name()=="headless": return
	if not sounds.has(key): return
	var v = voices[voice_index % voices.size()]
	voice_index += 1
	v.stream = sounds[key]
	v.pitch_scale = randf_range(0.94,1.06)
	v.volume_db = linear_to_db(maxf(0.0001,profile.data.master*profile.data.sfx*0.55))
	v.play()

func impact(kind:String,strength:float):
	var key="shell_tink" if kind=="armor" else ("bounce" if kind=="blocked" else ("hurt" if kind=="hurt" else ("jelly_slam" if strength>=1.35 else "jelly_tap")))
	play(key)

func song(key: String):
	if DisplayServer.get_name()=="headless": return
	if current == key: return
	current = key
	music.stream = load("res://assets/audio/"+key+".wav")
	if music.stream is AudioStreamWAV:
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_end = int(music.stream.get_length()*music.stream.mix_rate)
	music.play()
	update_volume()

func shutdown():
	if music:
		music.stop()
		music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	sounds.clear()

func _exit_tree():
	shutdown()
