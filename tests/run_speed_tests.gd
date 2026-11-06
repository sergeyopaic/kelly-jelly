extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	game.profile=JellyProfile.new("user://speed_verification.json")
	game.sound.profile=game.profile
	var results=[]
	var failed=false
	for speed in [1,2,3]:
		game.start_run(275)
		game.arena.enemies.clear();game.arena.no_spawns=true
		game.game_speed=speed;game.sync_game_speed()
		# Discard resource-loading frame time before measuring the live engine.
		await process_frame
		await process_frame
		var initial=game.arena.elapsed
		var begun=Time.get_ticks_usec()
		await create_timer(.35,true,false,true).timeout
		var wall=(Time.get_ticks_usec()-begun)/1000000.0
		var simulated=game.arena.elapsed-initial
		var ratio=simulated/wall
		var passed=absf(ratio-speed)<.25
		failed=failed or not passed
		results.append({"speed":speed,"wall_seconds":wall,"game_seconds":simulated,"ratio":ratio,"passed":passed})
		game.stop_arena()
	var report={"measurements":results,"passed":not failed}
	var file=FileAccess.open("res://docs/game_speed_verification.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SPEED_REPORT ",JSON.stringify(report))
	game.queue_free();await process_frame
	quit(1 if failed else 0)
