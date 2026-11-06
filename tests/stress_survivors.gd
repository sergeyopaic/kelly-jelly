extends SceneTree

var game
var a:RunArena
var runs=0
var max_enemies=0
var max_items=0
var max_mass=30.0
var kills=0
var deaths=0
var orbit_ticks=0

func _initialize(): call_deferred("run")

func next_run():
	runs+=1
	game.start_run(90500+runs)
	a=game.arena
	a.set_physics_process(false)
	a.finished.disconnect(game.show_result)
	a.choose_upgrade.disconnect(game.show_upgrades)
	a.choose_upgrade.connect(func(): a.grant_upgrade(a.choices()[0]))
	a.boss_reward.disconnect(game.show_boss_reward)
	a.boss_reward.connect(func(): a.accept_boss_reward())
	a.bot=true

func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	game.profile=JellyProfile.new("user://survivors_stress.json")
	game.profile.data.assist=false
	game.sound.profile=game.profile
	next_run()
	var begun=Time.get_ticks_msec()
	for tick in 72000:
		a._physics_process(1.0/60)
		if a.orbit_rank>0 and a.dash_left>0: orbit_ticks+=1
		max_enemies=maxi(max_enemies,a.enemies.size())
		max_items=maxi(max_items,a.items.size())
		max_mass=maxf(max_mass,a.mass)
		if a.ended and not a.death_animating:
			deaths+=1;kills+=a.kills;next_run()
		if tick%600==0: await process_frame
	kills+=a.kills
	var report={"simulated_seconds":1200,"wall_seconds":(Time.get_ticks_msec()-begun)/1000.0,"runs":runs,"deaths":deaths,"kills":kills,"maximum_mass":max_mass,"maximum_enemies":max_enemies,"maximum_items":max_items,"assist":false,"scope":"20 simulated minutes of ordinary bot combat, restarting after death; no health or damage cheats. Not a human playthrough or rendering benchmark."}
	report["orbit_dash_ticks"]=orbit_ticks
	var file=FileAccess.open("res://docs/survivors_stress_death.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STRESS_REPORT ",JSON.stringify(report))
	game.queue_free();await process_frame
	quit(0 if max_enemies<=110 and max_items<=220 else 1)
