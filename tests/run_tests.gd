extends SceneTree

var failures: Array[String] = []
var checks = 0
var game

func check(condition: bool,message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error("CHECK FAILED: "+message)

func _initialize():
	call_deferred("run")

func run():
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.profile = JellyProfile.new("user://invariant_test.json")
	game.profile.data.assist = false
	game.sound.profile = game.profile
	check(GameData.radius(29)==12 and GameData.radius(30)==16,"first form threshold")
	check(GameData.radius(69)==16 and GameData.radius(70)==21,"second form threshold")
	for m in [0,1,4,5,29,30,69,70,100]:
		for charge in [0.1,0.4,0.8]:
			for light in [false,true]:
				var stats = GameData.dash_stats(m,charge,light)
				check(stats.cost<=m and stats.cost>=0,"mass cost bounds")
	game.start_level(0,false)
	var a = game.arena
	a.set_physics_process(false)
	a.items.clear()
	a.mass = 70
	a.charge = .8
	a.charging = true
	a.release_dash()
	check(a.mass==55 and a.dash_damage==4,"dash snapshots mass before spending")
	var total = 0.0
	for item in a.items: total += item.value
	check(total==15,"mass conserved by full dash")
	a.items.clear()
	a.mass = 20
	a.charge = .1
	a.charging = true
	a.release_dash()
	total = 0
	for item in a.items: total += item.value
	check(total==5,"mass conserved with remainder")
	a.mass = 0
	a.charge = .8
	a.charging = true
	a.release_dash()
	check(a.mass==0 and a.dash_damage==2,"zero mass has usable dash")
	a.enemies.clear()
	a.spawn_enemy(2,Vector2(500,250))
	var e = a.enemies[0]
	e.state="approach"
	e.face=Vector2.RIGHT
	a.hit_enemy(e,2,Vector2.RIGHT*100,45)
	var hp_after = e.hp
	a.hit_enemy(e,2,Vector2.RIGHT*100,45)
	check(e.hp==hp_after,"same dash cannot double hit target")
	a.enemies.clear()
	a.spawn_enemy(5,Vector2(500,250))
	e=a.enemies[0]
	e.state="attack"
	a.hit_enemy(e,4,Vector2.ZERO,46)
	check(e.hp==28,"boss armor active")
	e.state="rest"
	a.hit_enemy(e,4,Vector2.ZERO,47)
	check(e.hp==24,"boss recovery vulnerable")
	a.grant_upgrade(4)
	a.grant_upgrade(4)
	check(a.max_hp==6 and a.upgrades.count(4)==1,"upgrade cannot stack twice")
	a.hp=5
	a.shield=true
	a.hurt()
	check(a.hp==5 and not a.shield,"shell blocks first hit")
	a.invincible=0
	a.hurt()
	check(a.hp==4,"next hit damages normally")
	a.active=true
	a.charging=true
	game.show_pause()
	check(not a.active and not a.charging,"pause cancels charge")
	game.resume()
	check(a.active,"resume restores play")
	# Trigger every content path, using explicit scripted damage for state-transition coverage.
	for level in 6:
		game.start_level(level,false)
		a=game.arena
		a.set_physics_process(false)
		for wave in 3:
			a.enemies.clear()
			a.start_wave()
			check(a.wave==wave and a.enemies.size()>0,"level %s wave %s populated"%[level+1,wave+1])
			for enemy in a.enemies:
				enemy.state="rest"
				a.hit_enemy(enemy,100,Vector2.ZERO,100+wave)
				check(enemy.state in ["stunned","defeated"],"enemy can be defeated")
			if wave<2: a.grant_upgrade(wave)
		a.finish(true)
		check(a.ended and game.screen=="result","result screen reached")
	check(game.profile.data.finished,"campaign finish recorded")
	var old = int(game.profile.data.medals[5])
	game.profile.record(5,0,false,0)
	check(int(game.profile.data.medals[5])==old,"medals never lost")
	game.profile.data.lang="en"
	game.profile.save()
	var restored = JellyProfile.new("user://invariant_test.json")
	check(restored.data.finished and restored.data.lang=="en","profile roundtrip")
	var file = FileAccess.open("user://invariant_test.json",FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered = JellyProfile.new("user://invariant_test.json")
	check(recovered.recovered and recovered.data.finished,"corrupt save restores backup")
	for language in ["ru","en"]:
		game.profile.data.lang=language
		game.show_menu()
		game.show_map()
		game.show_settings("menu")
		game.show_help("menu")
		game.show_credits()
		game.show_final()
		check(game.screen=="final","all UI screens built in "+language)
	var report={"checks":checks,"failures":failures,"scope":"Deterministic invariants and scripted state transitions; not a manual playthrough."}
	file=FileAccess.open("res://docs/test_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("TEST_REPORT ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
