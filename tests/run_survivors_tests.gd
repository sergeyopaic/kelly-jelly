extends SceneTree

var failures:Array=[]
var count=0
var game
var a:RunArena

func check(condition: bool,message: String):
	count+=1
	if not condition: failures.append(message);push_error(message)

func _initialize(): call_deferred("run")

func fresh():
	game.start_run(1234)
	a=game.arena
	a.set_physics_process(false)
	a.enemies.clear();a.items.clear();a.no_spawns=true

func enemy(weight: float,hp: int,kind: int=0) -> RunEnemy:
	var e=RunEnemy.new(kind,100+a.enemies.size(),Vector2(20,0),weight)
	e.state="approach";e.hp=hp;e.max_hp=hp
	a.enemies.append(e)
	return e

func run():
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false)
	game.profile=JellyProfile.new("user://survivors_invariants.json")
	game.profile.data.assist=false
	game.sound.profile=game.profile
	sprint_checks()
	impact_balance_checks()
	readability_checks()
	orbit_checks()
	world_progression_checks()
	sprite_direction_checks()
	death_animation_checks()
	game_speed_checks()
	level_transition_checks()
	for m in [30.0,300.0,3000.0,30000.0,3e6,3e9,3e12]:
		check(RunRules.radius(m)>0 and is_finite(RunRules.radius(m)),"finite radius at "+str(m))
		check(RunRules.zoom_for(m)>0 and RunRules.radius(m)*RunRules.zoom_for(m)<=58.01,"camera keeps huge Kelly visible")
	check(RunRules.radius(300)>RunRules.radius(30)*2,"10x mass more than doubles world radius")
	check(RunRules.radius(300)*RunRules.zoom_for(300)>RunRules.radius(30),"growth remains visible on screen")
	check(not RunRules.impact(30,300,99999).success,"speed cannot bypass minimum mass")
	check(not RunRules.impact(30,30,50).success,"low speed cannot damage peer")
	check(RunRules.impact(30,30,1100).success,"full dash can damage peer")
	check(RunRules.impact(30,30,1100).damage>RunRules.impact(30,30,600).damage,"speed increases damage")
	fresh()
	var e=enemy(10,2)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT);a.resolve_contacts()
	check(e.dead and a.hp==6,"clean lethal ram has no return contact damage")
	check(a.mass==30,"absorption waits until attack outcome")
	a.settle_attack()
	check(is_equal_approx(a.mass,30.8) and a.absorbed==1,"clean kill absorbed with exact mass reward")
	check(a.items.size()==1 and a.items[0].type=="xp","kill drops XP, no coin")
	fresh();e=enemy(10,2)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT);a.hurt("test projectile");a.settle_attack()
	check(a.mass==30 and a.absorbed==0 and a.kills==1,"damage during same attack cancels absorption, not kill or XP")
	fresh();e=enemy(60,20)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT);a.resolve_contacts();a.settle_attack()
	check(not e.dead and e.hp<20 and e.stun>0 and a.hp==6,"valid nonlethal hit stuns before contact")
	fresh();e=enemy(300,20)
	a.start_attack();a.dash_left=.3;a.attempt_hit(e,1100,Vector2.RIGHT);a.resolve_contacts();a.settle_attack()
	check(e.hp==20 and a.hp==5,"undersized dash takes contact damage, has no blanket immunity")
	fresh();e=enemy(30,8)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT)
	var after=e.hp
	a.attempt_hit(e,1100,Vector2.RIGHT)
	check(e.hp==after,"one attack cannot repeat direct damage")
	fresh();e=enemy(45,18,5)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT)
	check(e.hp==18,"armored boss blocks ram")
	e.state="rest";a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT);a.resolve_contacts()
	check(e.hp<18 and a.hp==6,"vulnerable boss hit recoils safely")
	fresh();a.charge=.8;a.charging=true;a.release_dash()
	check(a.mass==30,"dash never consumes growth")
	a.hp=3;a.drop_item(a.player,"heart",1);a.step_pickups(.016)
	check(a.hp==4 and a.mass==30 and a.xp==0,"heart only heals")
	a.drop_item(a.player,"xp",5);a.step_pickups(.016)
	check(a.hp==4 and a.mass==30 and a.xp==5,"XP only increases experience")
	fresh();a.kills=11;e=enemy(10,1)
	a.start_attack();a.attempt_hit(e,1100,Vector2.RIGHT);a.settle_attack()
	check(a.items.any(func(item): return item.type=="heart"),"12th defeat guarantees visible healing pickup")
	fresh();a.gain_xp(200)
	check(a.level>2 and a.pending_levels>1,"large XP awards queue all choices")
	a.maybe_upgrade()
	check(not a.active and game.screen=="play" and a.level_up_left>0,"level-up begins on Kelly before upgrade menu")
	var old_position=a.player;var old_time=a.elapsed;var old_hp=a.hp;var old_stamina=a.stamina
	var danger=enemy(30,10);danger.pos=a.player
	a.shoot(a.player,Vector2.RIGHT*100,8,3)
	var bullet_position=a.bullets[0].p
	a._physics_process(.25)
	check(game.screen=="play" and a.level_up_left>0,"upgrade choice waits through short celebration")
	check(a.player==old_position and a.elapsed==old_time and a.hp==old_hp and a.stamina==old_stamina and a.bullets[0].p==bullet_position,"celebration freezes combat, projectiles and stamina")
	var remaining=a.level_up_left
	game.show_pause();a._physics_process(1.0)
	check(is_equal_approx(a.level_up_left,remaining) and game.screen=="pause","pause holds level-up animation without opening choices")
	game.resume();check(not a.active,"resuming celebration does not restart combat early")
	a._physics_process(remaining+.001)
	check(not a.active and game.screen=="upgrades" and a.level_up_left==0,"choice opens after 0.55s of unpaused celebration")
	var panel=game.ui.get_child(0);a._physics_process(1.0)
	check(game.ui.get_child(0)==panel,"choice panel opens only once")
	var choices=a.choices()
	check(choices.size()==3 and choices[0]!=choices[1] and choices[1]!=choices[2] and choices[0]!=choices[2],"three distinct upgrade choices")
	for id in RunRules.UP_EN.size():
		a.pending_levels+=1;a.grant_upgrade(id)
		check(a.rank(id)==1,"upgrade "+str(id)+" is applied")
	a.pending_levels+=1;a.grant_upgrade(0)
	check(a.rank(0)==2,"repeat upgrade stacks")
	fresh()
	check(a.mass==30 and a.level==1 and a.upgrades.is_empty() and a.kills==0,"new run resets power and growth")
	for i in 500: a.drop_item(Vector2(i,0),"xp",1)
	a.drop_item(Vector2.ZERO,"heart",1)
	check(a.items.size()<=220,"pickup population bounded")
	var xp_total=0.0
	for item in a.items:
		if item.type=="xp": xp_total+=item.value
	check(xp_total==500,"pickup compaction preserves experience")
	for i in 300: a.spawn_enemy(0,8,Vector2(i,0))
	check(a.enemies.size()==RunRules.MAX_ENEMIES,"enemy simulation cap")
	fresh();a.player=Vector2(250000,300000);a.camera=a.player
	a._physics_process(.016)
	check(a.player.length()<100000 and a.origin_sectors.length()>0,"infinite travel rebases world origin")
	fresh();a.mass=1000;a.elapsed=65;a.kills=45;a.level=8
	a.finish("test")
	var runs=game.profile.data.runs;a.finish("test again")
	check(game.profile.data.runs==runs and game.profile.data.best_mass>=1000,"run recorded exactly once")
	var restored=JellyProfile.new("user://survivors_invariants.json")
	check(restored.data.last_run.mass==1000 and restored.data.last_run.kills==45,"run record persists")
	game.show_menu()
	check(not game.ui.get_children().any(func(c): return c is Button and ("Карта" in c.text or "Map" in c.text)),"campaign map removed from playable menu")
	for language in ["ru","en"]:
		game.profile.data.lang=language;game.show_menu();game.show_help("menu");game.show_settings("menu");game.show_records();game.show_credits()
		check(game.screen=="credits","all UI screens build in "+language)
	var report={"checks":count,"failures":failures,"scope":"Survivors deterministic mechanics, save and UI tests"}
	var file=FileAccess.open("res://docs/survivors_tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("TEST_REPORT ",JSON.stringify(report))
	game.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)

func sprint_checks():
	check(InputMap.has_action("sprint"),"sprint action exists")
	check(InputMap.action_get_events("sprint").any(func(event): return event is InputEventKey and event.physical_keycode==KEY_SHIFT),"Shift is the default hold binding")
	fresh()
	Input.action_press("right")
	for i in 10: a._physics_process(.02)
	var walk_speed=a.velocity.length()
	Input.action_press("sprint")
	for i in 25: a._physics_process(.02)
	check(a.sprinting and a.velocity.length()>walk_speed*1.6,"held Shift accelerates normal movement")
	check(is_equal_approx(a.stamina,.7),"half-second hold spends only half a second of stamina")
	Input.action_release("sprint")
	a._physics_process(.01)
	check(not a.sprinting and a.velocity.length()<=walk_speed+.01,"release stops sprint immediately without bonus coasting")
	check(is_equal_approx(a.stamina,.7),"release preserves remaining stamina")
	a._physics_process(.4)
	check(is_equal_approx(a.stamina,.7),"recovery waits for its short delay")
	a._physics_process(.3)
	check(a.stamina>.7,"unused stamina recovers after delay")
	a.stamina=.1;a.stamina_delay=0;a.update_sprint(.05,true,true)
	check(a.sprinting and is_equal_approx(a.stamina,.05),"short hold can use a small remaining reserve without a minimum activation")
	Input.action_release("right")
	fresh();Input.action_press("sprint")
	a._physics_process(.5)
	check(not a.sprinting and is_equal_approx(a.stamina,RunRules.SPRINT_SECONDS),"holding Shift without moving spends nothing")
	Input.action_press("right")
	for i in 75: a._physics_process(.02)
	check(not a.sprinting and not a.sprint_rearmed,"exhausted hold cannot auto-repeat short bursts")
	a.update_sprint(3,true,true)
	check(is_equal_approx(a.stamina,a.stamina_capacity()),"stamina recovers to capacity even after exhaustion")
	a.update_sprint(.02,true,true)
	check(a.sprinting,"continued hold resumes when fully recovered without another keypress")
	Input.action_release("sprint");a._physics_process(.02)
	Input.action_press("sprint");a._physics_process(.02)
	check(a.sprinting,"release and renewed hold rearm sprint")
	var stored=a.stamina
	a.active=false;a._physics_process(.5)
	check(is_equal_approx(stored,a.stamina),"pause freezes stamina")
	a.active=true;a.begin_charge()
	stored=a.stamina;a._physics_process(.1)
	check(a.charging and not a.sprinting and a.stamina>=stored,"charging cannot sprint or spend sprint stamina")
	Input.action_release("sprint");Input.action_release("right")
	fresh();a.charging=true;a.charge=.8;a.release_dash()
	var dash_speed=a.velocity.length()
	var dash_duration=a.dash_left
	for i in 10: a._physics_process(.01)
	var dash_distance=a.player.length()
	fresh();a.pending_levels=3
	a.grant_upgrade(12);a.grant_upgrade(13);a.grant_upgrade(14)
	check(is_equal_approx(a.stamina_capacity(),1.6),"Sugar reserve adds 0.4 seconds")
	check(is_equal_approx(a.stamina,1.6),"capacity upgrade fills its added capacity")
	a.stamina=0;a.stamina_delay=0;a.update_sprint(1,false,false)
	check(is_equal_approx(a.stamina,.75),"Second wind adds 25 percent recovery")
	check(is_equal_approx(a.sprint_multiplier(),1.87),"Tailwind adds 10 percent sprint speed")
	a.stamina=a.stamina_capacity()
	Input.action_press("right");Input.action_press("sprint")
	a.update_sprint(.1,true,true)
	check(a.sprinting,"sprint before dash")
	a.begin_charge();a.charge=.8;a.release_dash()
	stored=a.stamina
	check(not a.sprinting and is_equal_approx(a.velocity.length(),dash_speed),"sprint state and all sprint upgrades cannot change dash launch speed")
	check(is_equal_approx(a.dash_left,dash_duration),"sprint upgrades cannot change dash duration")
	for i in 10:
		if i==3: Input.action_release("sprint")
		if i==6: Input.action_press("sprint")
		a._physics_process(.01)
	check(is_equal_approx(a.player.length(),dash_distance),"toggling Shift during dash preserves distance")
	check(is_equal_approx(a.velocity.length(),dash_speed),"dash velocity remains independent of Shift")
	check(is_equal_approx(a.stamina,stored) and not a.sprinting,"dash never consumes sprint stamina")
	Input.action_release("sprint");Input.action_release("right")
	var seen={}
	for i in 100:
		for id in a.choices(): seen[id]=true
	check(seen.has(12) and seen.has(13) and seen.has(14),"all three sprint upgrades appear in level-up pool")
	fresh()
	check(is_equal_approx(a.stamina,1.2) and a.rank(12)==0 and not a.sprinting,"new run resets stamina and sprint upgrades")

func impact_balance_checks():
	fresh();a.drop_item(a.player,"heart",1);a.step_pickups(.016)
	check(a.hp==a.max_hp and a.items.size()==1,"full-health hearts remain available on the floor")
	a.hp-=1;a.step_pickups(.016)
	check(a.hp==a.max_hp and a.items.is_empty(),"saved heart heals later and is then consumed")
	fresh();a.charging=true;a.charge=.8;a.release_dash()
	a.impact_feedback(a.player,Vector2.RIGHT,2,"hit")
	var position=a.player;var duration=a.dash_left;var stamina=a.stamina;var elapsed=a.elapsed
	a.drop_item(Vector2(300,0),"xp",1)
	a.shoot(Vector2(400,0),Vector2(-100,0),4,3)
	var projectile=a.bullets[0].p
	a._physics_process(.016)
	check(a.player==position and a.bullets[0].p==projectile,"impact pause freezes both player and projectiles")
	check(a.dash_left==duration and a.stamina==stamina and a.elapsed==elapsed,"impact pause preserves attack and resource timers")
	check(a.impact_pause>0 and a.impact_pause<.07,"strong impact uses a bounded short pause")
	for i in 80: a.impact_feedback(a.player,Vector2.RIGHT,2,"hit")
	check(a.impacts.size()<=24 and a.impact_pause<.07,"crowd effects are bounded and pauses never accumulate")
	for i in 5: a._physics_process(.016)
	check(a.player!=position and a.elapsed>elapsed,"simulation resumes after impact pause")
	check(RunRules.prey_xp(30,10)==RunRules.prey_xp(3000000,1000000),"XP follows relative threat rather than absolute mass")
	check(RunRules.absorbed_mass(30,300,0)<=2.4+.00001,"oversized prey cannot create an outsized mass jump")
	check(RunRules.absorbed_mass(30000,30000,0)/30000<RunRules.absorbed_mass(30,30,0)/30,"growth eases gradually at large scales")
	check(RunRules.absorbed_mass(1e12,1e12,0)>0,"growth stays unbounded rather than hitting a mass cap")
	fresh();a.elapsed=10;a.spawn_group()
	check(a.enemies.all(func(e): return e.kind==0),"opening waves introduce only the simplest enemy")
	a.enemies.clear();a.elapsed=20;a.spawn_group()
	check(a.enemies.size()==1 and a.enemies[0].kind==0,"wave rest segment spawns a single small prey")
	a.enemies.clear();a.elapsed=125;a.spawn_group();a.spawn_group()
	check(a.enemies.filter(func(e): return e.kind>=5).size()==1,"automatic waves cannot stack active bosses")
	var original_mass=a.enemies[0].mass;a.mass=10000
	check(a.enemies[0].mass==original_mass,"existing enemies do not resize when Kelly grows")
	fresh()

func readability_checks():
	fresh();a.mass=60
	var e=enemy(50,20,2);e.face=Vector2.LEFT;e.pos=Vector2(40,0)
	check(a.hit_info(e,1100).success,"lighter waffle no longer has permanent hidden armor")
	e.state="guard";e.timer=.95
	check(not a.hit_info(e,1100).success,"waffle blocks its visible forward sector during guard")
	a.player=Vector2(80,0)
	check(a.hit_info(e,1100).success,"waffle rear stays vulnerable during guard")
	e.step(.1,a)
	check(e.face==Vector2.LEFT,"waffle guard cannot snap toward player behind it")
	e.step(.86,a)
	check(e.state=="rest" and a.hit_info(e,1100).success,"guard expires into a vulnerable recovery")
	e.state="approach";e.timer=.01;e.step(.02,a)
	check(e.state=="guard_windup" and not e.blocks_from(a.player),"shield windup visibly precedes active protection")
	e.step(.46,a);check(e.state=="guard","waffle enters guard after windup")
	fresh();a.velocity=Vector2(-100,0);a.update_facing()
	check(a.facing==-1,"Kelly faces left when moving left")
	a.velocity=Vector2(5,200);a.update_facing()
	check(a.facing==-1,"vertical movement jitter preserves facing")
	a.velocity=Vector2.ZERO;a.update_facing()
	check(a.facing==-1,"idle preserves previous facing")
	a.charging=true;a.aim=Vector2.RIGHT;a.update_facing()
	check(a.facing==1,"charging faces aim rather than movement")
	var pose=game.art.emotions.pose(a)
	check(pose.facing==-1,"left-facing source sprite is mirrored to face right")
	for kind in [0,1,5,6]:
		fresh();e=enemy(30,20,kind);e.state="telegraph";e.timer=.001;e.face=Vector2.RIGHT
		var start=e.pos;var promised=e.attack_speed()*e.attack_duration()*RunRules.motion_scale(e.mass)
		e.step(.001,a)
		var duration=e.attack_duration()
		for i in 60: e.step(duration/60,a)
		check(absf(e.pos.x-start.x-promised)<.01,"warning distance matches ram travel for kind "+str(kind))
	for kind in [3,7]:
		fresh();e=enemy(30,20,kind);e.state="telegraph";e.timer=.001;e.face=Vector2.RIGHT
		e.step(.001,a)
		check(a.bullets.size()==e.volley_angles().size(),"volley warning ray count matches projectiles")
		for i in a.bullets.size():
			check(a.bullets[i].v.normalized().is_equal_approx(e.face.rotated(e.volley_angles()[i])) and is_equal_approx(a.bullets[i].v.length(),e.projectile_speed()),"volley direction and speed match warning")
	for key in game.art.BODY_BOUNDS:
		var body:Rect2=game.art.BODY_BOUNDS[key]
		var rect:Rect2=game.art.enemy_rect(key,18)
		var scale=rect.size.x/game.art.textures[key].get_width()
		check(is_equal_approx(body.size.x*body.size.y*scale*scale,pow(18*2.65,2)),"equal-mass body sizing: "+key)
	fresh()

func level_transition_checks():
	fresh();a.gain_xp(60);a.start_attack();a.maybe_upgrade()
	check(a.level_up_left==0 and a.active,"level-up waits for active attack to settle")
	a.settle_attack();a.maybe_upgrade()
	a._physics_process(a.LEVEL_UP_SECONDS+.001)
	check(a.pending_levels==2 and game.screen=="upgrades","multiple earned levels are retained through celebration")
	a.grant_upgrade(0);game.show_hud();a.maybe_upgrade()
	check(a.pending_levels==1 and a.level_up_left>0 and not a.active,"next queued level gets a short celebration too")
	a._physics_process(a.LEVEL_UP_SECONDS+.001);a.grant_upgrade(1);game.show_hud();a.maybe_upgrade()
	check(a.pending_levels==0 and a.level_up_left==0 and a.active,"last choice returns to normal play")
	fresh();a.gain_xp(20);a.maybe_upgrade();a.finish("test");a._physics_process(1)
	check(a.level_up_left==0 and game.screen=="result","run ending cancels pending celebration")
	fresh();check(a.level_up_left==0 and not a.level_up_paused,"new run has no leftover celebration")

func orbit_checks():
	fresh();a.orbit_rank=1;a.mass=100;a.start_attack();a.dash_left=.36;a.velocity=Vector2(1100,0)
	var e=enemy(10,99);e.pos=a.orbit_point(0,a.player,a.orbit_angle)
	a.orbit_step(a.player,a.player,.001)
	check(e.dead and a.mass==100,"orbit slices tiny prey but delays absorption")
	a.settle_attack();check(a.mass>100 and a.absorbed==1,"clean orbital kill absorbs at dash end")
	fresh();a.orbit_rank=1;a.mass=100;a.start_attack();a.dash_left=.36;a.velocity=Vector2(1100,0)
	e=enemy(10,2);e.pos=a.orbit_point(0,a.player,a.orbit_angle)
	a.orbit_step(a.player,a.player,.001);a.hurt("orbit test");a.settle_attack()
	check(a.mass==100 and a.kills==1 and a.items.size()==1,"hurt dash keeps orbital XP but cancels absorption")
	fresh();a.orbit_rank=1;a.start_attack();a.velocity=Vector2(1100,0)
	e=enemy(30,20);e.pos=a.orbit_point(0,a.player,a.orbit_angle)
	a.orbit_step(a.player,a.player,0);var hp_after=e.hp
	a.orbit_step(a.player,a.player,0)
	check(hp_after<20 and e.hp==hp_after,"orbit hits larger target only once per dash")
	a.attempt_hit(e,1100,Vector2.RIGHT)
	check(e.hp<hp_after,"direct ram remains independent of orbital hit")
	fresh();a.orbit_rank=1;a.start_attack();a.velocity=Vector2(99999,0)
	e=enemy(101,20);e.pos=a.orbit_point(0,a.player,a.orbit_angle);a.orbit_step(a.player,a.player,0)
	check(e.hp==20,"orbital speed cannot bypass minimum mass")
	fresh();a.mass=100;a.orbit_rank=1;a.start_attack();a.velocity=Vector2(1100,0)
	e=enemy(10,2,2);e.state="guard";e.pos=a.orbit_point(0,a.player,a.orbit_angle)+Vector2(3,0);e.face=Vector2.LEFT
	a.orbit_step(a.player,a.player,0);check(not e.dead,"directional waffle shield blocks tiny prey execution")
	a.start_attack();e.face=Vector2.RIGHT;a.orbit_step(a.player,a.player,0)
	check(e.dead,"orbital petal can strike behind waffle shield")
	fresh();a.orbit_rank=1;a.mass=100;a.start_attack();a.velocity=Vector2(1100,0)
	e=enemy(10,18,5);e.state="approach";e.pos=a.orbit_point(0,a.player,a.orbit_angle)
	a.orbit_step(a.player,a.player,0);check(e.hp==18,"orbit respects boss armor")
	fresh();a.start_attack();e=enemy(10,1,5);a.kill_enemy(e);a.maybe_boss_reward()
	check(a.orbit_rank==0 and a.active,"boss reward waits for attack outcome")
	a.settle_attack();a.maybe_boss_reward()
	check(game.screen=="boss_reward" and not a.active,"boss reward card pauses combat")
	a.accept_boss_reward();check(a.orbit_rank==1 and a.active,"first boss unlocks orbit")
	var radius=a.orbit_radius()
	for stage in [2,3]:
		a.start_attack();e=enemy(10,1,5);a.kill_enemy(e);a.settle_attack();a.accept_boss_reward()
	check(a.orbit_rank==3 and a.orbit_count()==5 and a.orbit_radius()>radius,"later bosses widen orbit then add petals")
	a.start_attack();e=enemy(10,1,5);a.kill_enemy(e);a.settle_attack()
	check(a.pending_boss_rewards==0,"max orbit rank does not queue empty rewards")
	fresh();check(a.orbit_rank==0 and a.pending_boss_rewards==0,"new run resets boss ability")

func world_progression_checks():
	fresh();a.elapsed=89.99;a.spawn_boss_if_due()
	check(a.enemies.is_empty() and a.next_boss==90,"first boss is not spawned before 1:30")
	a.elapsed=90;a.spawn_boss_if_due()
	check(a.enemies.size()==1 and a.enemies[0].kind==5,"first boss spawns at 1:30")
	a.spawn_boss_if_due();check(a.enemies.size()==1,"boss scheduler cannot duplicate active boss")
	check(a.next_boss==210,"later boss interval stays 120 seconds")
	fresh();a.elapsed=89.99;a.no_spawns=false;a.spawn_timer=3;a._physics_process(.02)
	check(a.enemies.any(func(e): return e.kind==5),"boss timing is independent of regular spawn groups")
	fresh();a.elapsed=900
	check(a.terrain_target()==0,"time alone never changes the environment")
	a.start_attack();var e=enemy(10,1,5);a.kill_enemy(e)
	check(a.terrain_target()==1,"first boss defeat changes environment before claiming reward")
	a.settle_attack();a.accept_boss_reward()
	check(a.terrain_target()==1,"first reward retains first victory palette")
	a.orbit_rank=2;check(a.terrain_target()==2,"second orbit stage enriches environment")
	a.orbit_rank=3;a.boss_kills=20;check(a.terrain_target()==3,"final environment remains stable after later bosses")
	a.active=false;a._physics_process(.75)
	check(a.terrain_stage>0 and a.terrain_stage<1,"environment blends gradually during reward card")
	fresh();check(a.terrain_target()==0 and a.terrain_stage==0,"new run restores original background")

func sprite_direction_checks():
	fresh()
	var renderer=KellyEmotions.new()
	for direction in [-1.0,1.0]:
		a.velocity=Vector2(direction*200,0)*a.unit();a.update_facing()
		check(renderer.pose(a).facing==-direction,"walking reflects left-facing source toward motion "+str(direction))
		a.sprinting=true
		check(renderer.pose(a).facing==-direction,"sprint reflects left-facing source toward motion "+str(direction))
		a.sprinting=false;a.dash_left=.3
		check(renderer.pose(a).facing==-direction,"dash reflects left-facing source toward motion "+str(direction))
		a.dash_left=0;a.charging=true;a.aim=Vector2(direction,0);a.velocity=Vector2(-direction*100,0);a.update_facing()
		check(renderer.pose(a).facing==-direction,"charge faces aim independently of retreat direction "+str(direction))
		a.charging=false
	a.velocity=Vector2.ZERO;a.update_facing()
	check(renderer.pose(a).facing==-a.facing,"stationary sprite retains correct source orientation")

func death_animation_checks():
	fresh();a.hp=1;a.elapsed=42;a.mass=100;a.velocity=Vector2(300,0)
	a.start_attack();var prey=enemy(10,1);a.kill_enemy(prey)
	var runs=game.profile.data.runs
	var notifications=[0]
	a.finished.connect(func(): notifications[0]+=1)
	a.hurt("last heart")
	check(a.ended and a.death_animating and not a.active and a.hp==0,"last heart starts death animation and stops combat")
	check(game.screen=="play" and a.death_elapsed==0,"result screen waits for visible death animation")
	check(a.velocity==Vector2.ZERO and a.dash_left==0,"death cancels movement and dash")
	check(a.mass==100 and a.absorbed==0,"fatal attack cannot grant absorption")
	check(game.profile.data.runs==runs+1,"fatal run is recorded immediately")
	var e=enemy(30,20);e.pos=Vector2(150,0)
	a.shoot(Vector2(300,100),Vector2.LEFT*100,5,3)
	a.drop_item(a.player,"heart",1)
	var player=a.player;var position=e.pos;var bullet=a.bullets[0].p
	a._physics_process(a.DEATH_SECONDS*.5)
	check(a.player==player and e.pos==position and a.bullets[0].p==bullet and a.elapsed==42,"death freezes player enemies projectiles and run timer")
	check(a.hp==0 and a.items.any(func(item): return item.type=="heart"),"death cannot collect heart and revive")
	check(a.death_progress()>.4 and a.death_progress()<.6 and game.screen=="play","melt progresses before result")
	var pose=game.art.emotions.death_pose(a)
	check(pose.rect.size.x>pose.rect.size.y*2 and pose.alpha>0,"middle melt widens body and lowers height")
	a.finish("again");a.hurt("again")
	check(game.profile.data.runs==runs+1,"death cannot record twice")
	a._physics_process(a.DEATH_SECONDS)
	check(not a.death_animating and game.screen=="result" and a.death_progress()==1,"result opens after final puddle hold")
	a._physics_process(1);check(game.profile.data.runs==runs+1 and notifications[0]==1,"ended animation emits result exactly once")
	fresh();a.finish("manual end")
	check(not a.death_animating and game.screen=="result","manual end shows result without death animation")
	fresh();check(not a.death_animating and a.death_elapsed==0,"new run resets death animation")
	a.hp=2;a.hurt("ordinary hit")
	check(not a.ended and not a.death_animating and a.hp==1,"nonfatal damage keeps ordinary hurt behavior")

	fresh();a.hp=1;a.shield=true;a.hurt("blocked fatal hit")
	check(not a.ended and a.hp==1,"shield prevents fatal animation when last heart is protected")
	fresh();a.hp=1;a.drop_item(a.player,"heart",1)
	var blocker=enemy(300,20);blocker.pos=a.player
	a._physics_process(.016)
	check(a.death_animating and a.hp==0 and a.items.size()==1,"lethal body contact stops the tick before heart pickup")

func game_speed_checks():
	fresh()
	var key=InputEventKey.new();key.pressed=true
	for entry in [[KEY_1,1],[KEY_2,2],[KEY_3,3],[KEY_KP_2,2]]:
		key.physical_keycode=entry[0]
		check(game.handle_speed_key(key) and game.game_speed==entry[1] and Engine.time_scale==entry[1],"number key selects game speed "+str(entry[1]))
		check(Engine.physics_ticks_per_second==60*entry[1],"accelerated game keeps fixed simulation step "+str(entry[1]))
	key.physical_keycode=KEY_3;key.echo=true
	check(not game.handle_speed_key(key) and game.game_speed==2,"key repeat does not change speed")
	key.echo=false;key.pressed=false
	check(not game.handle_speed_key(key),"speed changes only on press")
	key.pressed=true;key.ctrl_pressed=true
	check(not game.handle_speed_key(key),"modified shortcuts do not change speed")
	key.ctrl_pressed=false;game.show_pause()
	check(Engine.time_scale==1 and not a.active,"pause restores interface speed")
	check(game.handle_speed_key(key) and game.game_speed==3 and Engine.time_scale==1,"speed can be selected while paused without starting combat")
	game.resume();check(Engine.time_scale==3 and a.active,"resume reapplies selected speed")
	a.active=false;a.pending_levels=1;game.show_upgrades()
	check(Engine.time_scale==1,"upgrade selection uses normal interface speed")
	a.grant_upgrade(0);game.show_hud()
	check(Engine.time_scale==3,"upgrade choice retains run speed")
	a.hp=0;a.finish("speed death");game._process(0)
	check(Engine.time_scale==1 and Engine.physics_ticks_per_second==60,"death animation returns to normal speed")
	fresh();check(game.game_speed==1 and Engine.time_scale==1,"new run defaults to normal speed")
	game.game_speed=3;game.sync_game_speed();game.show_menu()
	check(Engine.time_scale==1 and not game.handle_speed_key(key),"menu resets engine speed and ignores speed keys")
	fresh()
