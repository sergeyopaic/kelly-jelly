class_name JellyProfile
extends RefCounted

var path = "user://profile.json"
var recovered = false
var data = {"version":1,"unlocked":1,"medals":[0,0,0,0,0,0],"scores":[0,0,0,0,0,0],"skin":0,"finished":false,"tutorial":false,"lang":"en","visual_english":false,"master":0.8,"music":0.65,"sfx":0.8,"shake":0.5,"flashes":true,"assist":false,"aim_help":true,"fullscreen":false,"vsync":true,"resolution":0,"bindings":{},"best_time":0.0,"best_mass":30.0,"best_kills":0.0,"runs":0.0,"last_run":{}}

func _init(test_path: String = ""):
	if test_path != "": path = test_path
	load_profile()

func load_profile():
	if not FileAccess.file_exists(path): return
	var parsed = read_json(path)
	if not valid(parsed):
		recovered = true
		parsed = read_json(path + ".bak") if FileAccess.file_exists(path + ".bak") else null
	if valid(parsed):
		for key in data:
			if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]): data[key] = parsed[key]
		# JSON numbers are floats, so explicitly accept validated numeric values.
		for key in ["unlocked","skin","resolution"]:
			if parsed.has(key): data[key] = int(parsed[key])
		data.unlocked = clampi(data.unlocked,1,6)
		data.skin = clampi(data.skin,0,3)
		data.resolution = clampi(data.resolution,0,2)
		if data.lang not in ["ru","en"]: data.lang="en"
		for key in ["master","music","sfx","shake"]: data[key]=clampf(data[key],0,1)

func read_json(file_path: String):
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) == OK: return parser.data
	return null

func valid(value) -> bool:
	if not (value is Dictionary and value.get("version",0) == 1 and value.get("medals") is Array and value.medals.size() == 6 and value.get("scores") is Array and value.scores.size() == 6): return false
	for key in ["medals","scores"]:
		for v in value[key]:
			if not (v is float or v is int) or not is_finite(v) or v<0: return false
	for key in ["unlocked","skin","resolution"]:
		if value.has(key) and not (value[key] is float or value[key] is int): return false
	return true

func save():
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		var previous = read_json(path)
		if valid(previous):
			DirAccess.copy_absolute(path,path+".bak")
	return DirAccess.rename_absolute(path+".tmp",path) == OK

func medals() -> int:
	var count = 0
	for bits in data.medals:
		for bit in [1,2,4]:
			if int(bits) & bit: count += 1
	return count

func record(level: int, score: int, clean: bool, chain: int):
	var bits = 1 | (2 if clean else 0) | (4 if chain >= 4 else 0)
	data.medals[level] = int(data.medals[level]) | bits
	data.scores[level] = maxi(int(data.scores[level]),score)
	data.unlocked = maxi(data.unlocked,mini(6,level+2))
	if level == 5: data.finished = true
	save()

func record_run(time: float,mass: float,kills: int,level: int,seed_value: int):
	data.best_time=maxf(data.best_time,time)
	data.best_mass=maxf(data.best_mass,mass)
	data.best_kills=maxf(data.best_kills,kills)
	data.runs+=1.0
	data.last_run={"time":time,"mass":mass,"kills":kills,"level":level,"seed":seed_value}
	save()
