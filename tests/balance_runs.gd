extends SceneTree

var game
var rows:Array=[]
var tag="baseline"

func _initialize(): call_deferred("run")

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag=arg.trim_prefix("--tag=")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	game.profile=JellyProfile.new("user://balance25.json")
	game.profile.data.assist=false;game.sound.profile=game.profile
	for seed_value in [271828,1847,90501,90502,90503,90504,90505,90506]:
		game.start_run(seed_value)
		var a:RunArena=game.arena
		a.set_physics_process(false);a.bot=true
		a.finished.disconnect(game.show_result);a.choose_upgrade.disconnect(game.show_upgrades)
		a.choose_upgrade.connect(func(): a.grant_upgrade(a.choices()[0]))
		var checkpoints:Array=[]
		var peak_enemies=0
		var max_mass=30.0
		for tick in 48000:
			a._physics_process(1.0/60)
			peak_enemies=maxi(peak_enemies,a.enemies.size());max_mass=maxf(max_mass,a.mass)
			if tick%3600==0: checkpoints.append({"t":snappedf(a.elapsed,.1),"mass":snappedf(a.mass,.1),"hp":a.hp,"level":a.level,"kills":a.kills})
			if a.ended or a.elapsed>=600: break
			if tick%600==0: await process_frame
		var row={"seed":seed_value,"survived":not a.ended,"time":snappedf(a.elapsed,.1),"mass":snappedf(a.mass,.1),"level":a.level,"kills":a.kills,"boss_kills":a.boss_kills,"damage_taken":a.hurt_count,"hp":a.hp,"max_hp":a.max_hp,"peak_enemies":peak_enemies,"upgrades":a.upgrades.duplicate(),"checkpoints":checkpoints}
		rows.append(row)
		print("BALANCE_RUN ",JSON.stringify(row))
		game.stop_arena();await process_frame
	var report={"tag":tag,"seconds_per_seed":600,"runs":rows,"scope":"Fixed seeds, existing combat bot, random first offered upgrade, assist off. No health or damage overrides; not a human playtest."}
	var file=FileAccess.open("res://docs/balance25_"+tag+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	game.queue_free();await process_frame;quit()
