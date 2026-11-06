class_name RunArena
extends Node2D

const SHOW_TUTORIAL_HINTS=false
const LEVEL_UP_SECONDS=.55
const DEATH_SECONDS=1.35

signal finished
signal choose_upgrade
signal boss_reward
var orbit_rank=0
var pending_boss_rewards=0
var orbit_angle=0.0
var orbit_hits:Dictionary={}
var profile: JellyProfile
var sound: JellySound
var art
var player=Vector2.ZERO
var velocity=Vector2.ZERO
var aim=Vector2.RIGHT
var facing=1.0
var mass=RunRules.START_MASS
var hp=6
var max_hp=6
var xp=0.0
var level=1
var pending_levels=0
var level_up_left=0.0
var level_up_paused=false
var kills=0
var absorbed=0
var wave=1
var elapsed=0.0
var clock=0.0
var active=true
var ended=false
var death_animating=false
var death_elapsed=0.0
var charging=false
var sprinting=false
var stamina=RunRules.SPRINT_SECONDS
var stamina_delay=0.0
var sprint_rearmed=true
var charge=0.0
var dash_left=0.0
var dash_cooldown=0.0
var dash_id=0
var attack_open=false
var attack_hurts=0
var attack_mass=0.0
var attack_pending: Array=[]
var hurt_count=0
var invincible=0.0
var hit_flash=0.0
var absorb_visual=0.0
var push_cd=0.0
var push_visual=0.0
var shield=false
var shield_timer=0.0
var incoming=0
var upgrades: Dictionary={}
var enemies: Array[RunEnemy]=[]
var items: Array=[]
var particles: Array=[]
var labels: Array=[]
var bullets: Array=[]
var puddles: Array=[]
var uid=0
var zoom=1.0
var camera=Vector2.ZERO
var run_seed=0
var rng=RandomNumberGenerator.new()
var spawn_timer=1.0
var next_boss=90.0
var terrain_stage=0.0
var boss_index=0
var banner=""
var banner_time=0.0
var last_reason=""
var reason_time=0.0
var shake=0.0
var gamepad=false
var joy_device=0
var bot=false
var seed_override=0
var no_spawns=false
var origin_sectors=Vector2.ZERO
var start_mass=RunRules.START_MASS
var last_growth=1
var end_reason=""
var ecology_mass=RunRules.START_MASS
var impact_pause=0.0
var impact_cooldown=0.0
var impact_kick=Vector2.ZERO
var impacts:Array=[]
var boss_kills=0

func impact_feedback(point:Vector2,direction:Vector2,strength:float,kind:String):
	strength=clampf(strength,.25,2.5)
	if impacts.size()<24:
		impacts.append({"p":point,"direction":direction,"strength":strength,"kind":kind,"life":.24,"duration":.24,"radius":body_radius()})
	if impact_cooldown>0 and kind!="hurt": return
	impact_cooldown=.11
	var heavy=strength>=1.35 and kind=="hit"
	if kind=="hit":
		impact_pause=maxf(impact_pause,.055 if heavy else .025)
		impact_kick=-direction*(2.8 if heavy else 1.2)
		shake=maxf(shake,2.8 if heavy else 1.2)
	elif kind=="hurt":
		impact_pause=maxf(impact_pause,.045)
		shake=maxf(shake,3.5)
	sound.impact(kind,strength)

func update_feedback(dt:float):
	impact_cooldown=maxf(0,impact_cooldown-dt)
	impact_kick=impact_kick.move_toward(Vector2.ZERO,26*dt)
	for effect in impacts: effect.life-=dt
	impacts=impacts.filter(func(effect): return effect.life>0)

func trx(ru: String,en: String) -> String:
	return ru if profile.data.lang=="ru" else en

func setup(p: JellyProfile,s: JellySound,renderer,seed_value: int=0):
	profile=p
	sound=s
	art=renderer
	run_seed=seed_value if seed_value!=0 else int(Time.get_unix_time_from_system())%2147483647
	rng.seed=run_seed
	sound.song("arena")
	if SHOW_TUTORIAL_HINTS: notice(trx("Новый забег. Ищи добычу меньше себя!","New run. Hunt smaller prey!"),Color("a2e3c8"))
	for i in 6: spawn_enemy(0,7.0,Vector2.from_angle(i*TAU/6)*rng.randf_range(150,260))

func rank(id: int) -> int:
	return int(upgrades.get(id,0))

func body_radius() -> float:
	return RunRules.radius(mass)

func unit() -> float:
	return RunRules.motion_scale(mass)

func stamina_capacity() -> float:
	return RunRules.SPRINT_SECONDS+.4*rank(12)

func sprint_multiplier() -> float:
	return RunRules.SPRINT_MULTIPLIER*(1+.1*rank(14))

func update_sprint(dt:float,moving:bool,held:bool):
	sprinting=false
	if not active or ended: return
	if not held or stamina>=stamina_capacity()-.00001: sprint_rearmed=true
	# Dash owns velocity and duration. Sprint cannot drain, recover or modify it.
	if dash_left>0: return
	if held and moving and not charging and sprint_rearmed and stamina>0:
		sprinting=true
		stamina=maxf(0,stamina-dt)
		stamina_delay=RunRules.SPRINT_RECOVERY_DELAY
		if stamina<.00001: stamina=0;sprint_rearmed=false
	else:
		var recovery_time=maxf(0,dt-stamina_delay)
		stamina_delay=maxf(0,stamina_delay-dt)
		stamina=minf(stamina_capacity(),stamina+recovery_time*RunRules.SPRINT_RECOVERY*(1+.25*rank(13)))

func to_screen(point: Vector2) -> Vector2:
	return (point-camera)*zoom+Vector2(480,300)

func to_world(point: Vector2) -> Vector2:
	return (point-Vector2(480,300))/zoom+camera

func notice(message: String,color: Color=Color("fff0c7")):
	banner=message
	banner_time=3.0

func float_text(point: Vector2,message: String,color: Color):
	if labels.size()<36: labels.append({"p":point,"text":message,"c":color,"life":1.1})

func burst(point: Vector2,color: Color,count: int):
	for i in mini(count,180-particles.size()):
		particles.append({"p":point,"v":Vector2.from_angle(randf()*TAU)*randf_range(30,120)/zoom,"c":color,"life":randf_range(.25,.55)})

func spawn_enemy(kind: int,weight: float,point: Vector2=Vector2(INF,INF)):
	if enemies.size()>=RunRules.MAX_ENEMIES: return
	uid+=1
	if not point.is_finite():
		point=player+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(530,680)/zoom
	enemies.append(RunEnemy.new(kind,uid,point,weight))

func spawn_group():
	# Each newly spawned cohort has a fixed mass. Growth never rescales an enemy
	# already present; old prey really becomes tiny. New cohorts include predators.
	var breathing=fmod(elapsed,25.0)>=18.0
	var ecology=minf(maxf(7,7*pow(1.18,elapsed/45.0)),ecology_mass*.28)
	ecology=maxf(ecology,ecology_mass*.10)
	var count=1 if breathing else mini(8,2+int(elapsed/90))
	for i in count:
		var roll=rng.randf()
		var weight=ecology*rng.randf_range(.7,1.2)
		if not breathing:
			if roll>.93: weight=ecology_mass*rng.randf_range(1.3,2.2)
			elif roll>.72: weight=ecology_mass*rng.randf_range(.55,1.0)
			elif roll>.48: weight*=2
		var max_kind=0 if elapsed<30 else (1 if elapsed<65 else (2 if elapsed<95 else (3 if elapsed<130 else 4)))
		spawn_enemy(0 if breathing else rng.randi_range(0,max_kind),weight)
	spawn_boss_if_due()

func spawn_boss_if_due():
	if elapsed>=next_boss and not enemies.any(func(e): return not e.dead and e.kind>=5):
		if enemies.size()<RunRules.MAX_ENEMIES:
			spawn_enemy(5+boss_index%3,maxf(ecology_mass*1.8,mass*minf(2,1.15+boss_index*.2)))
			boss_index+=1
			next_boss=elapsed+120
			notice(trx("ХИЩНИК РЯДОМ","APEX PREDATOR"))
			sound.song("boss")

func drop_item(point: Vector2,type: String,value: float):
	if items.size()>=220:
		for item in items:
			if item.type==type:
				item.value+=value
				return
		items[1].value+=items[0].value
		items[0]={"p":point,"type":type,"value":value,"age":0.0}
		return
	items.append({"p":point,"type":type,"value":value,"age":0.0})

func add_puddle(point: Vector2,radius: float):
	if puddles.size()<50: puddles.append({"p":point,"r":radius,"life":4.0})

func shoot(point: Vector2,speed: Vector2,radius: float,kind: int):
	if bullets.size()<80: bullets.append({"p":point,"v":speed,"r":radius,"life":5.0,"kind":kind})

func start_attack():
	if attack_open: settle_attack()
	dash_id+=1
	attack_open=true
	attack_hurts=hurt_count
	attack_mass=mass
	attack_pending.clear()
	orbit_hits.clear()
	orbit_angle=aim.angle()

func orbit_count() -> int:
	return 5 if orbit_rank>=3 else 3

func terrain_target() -> float:
	return float(maxi(mini(boss_kills,1),orbit_rank))

func orbit_radius() -> float:
	return body_radius()*(2.0 if orbit_rank>=2 else 1.65)

func orbit_point(index:int,center:Vector2,angle:float) -> Vector2:
	return center+Vector2.from_angle(angle+index*TAU/orbit_count())*orbit_radius()

func orbit_step(before:Vector2,after:Vector2,dt:float):
	if orbit_rank<=0 or not attack_open: return
	var next_angle=orbit_angle+TAU*dt/.36
	for i in orbit_count():
		var from=orbit_point(i,before,orbit_angle)
		var to=orbit_point(i,after,next_angle)
		for e in enemies:
			if e.dead or e.state=="spawn" or orbit_hits.has(e.uid): continue
			var near=Geometry2D.get_closest_point_to_segment(e.pos,from,to)
			if near.distance_to(e.pos)>e.radius+body_radius()*.24: continue
			orbit_hits[e.uid]=true
			if e.blocks_from(near):
				impact_feedback(near,(e.pos-near).normalized(),.4,"armor")
				continue
			var result=RunRules.impact(attack_mass,e.mass,velocity.length()/unit(),(1+.2*rank(0))*.45)
			var tiny=e.kind<5 and e.mass<=attack_mass*.2
			if not tiny and not result.success: continue
			e.hp-=e.hp if tiny else result.damage
			e.flash=.12;e.hit_direction=(e.pos-near).normalized()
			impact_feedback(near,e.hit_direction,.5,"hit")
			burst(near,Color("ffbc73"),4)
			if e.hp<=0: kill_enemy(e)
	orbit_angle=next_angle

func maybe_boss_reward():
	if pending_boss_rewards>0 and active and not ended and not attack_open:
		active=false;sprinting=false;charging=false;charge=0
		boss_reward.emit()

func accept_boss_reward():
	if pending_boss_rewards<=0 or ended: return
		# One card per unlocked stage; later bosses retain their normal loot.
	pending_boss_rewards-=1
	orbit_rank=mini(3,orbit_rank+1)
	active=true

func settle_attack():
	if not attack_open: return
	var clean=hurt_count==attack_hurts and hp>0
	var gained=0.0
	for prey in attack_pending:
		if clean:
			gained+=RunRules.absorbed_mass(attack_mass,prey.mass,rank(3))
			absorbed+=1
			burst(prey.pos,Color("f78fb4"),6)
	if gained>0:
		mass+=gained
		absorb_visual=.3
		float_text(player,trx("+%s массы","+%s mass")%RunRules.amount(gained),Color("ff9cc5"))
		sound.play("jelly_pop")
	elif not attack_pending.is_empty() and not clean:
		float_text(player,trx("Получен урон: только опыт","Hurt during attack: XP only"),Color("ffbf92"))
	attack_pending.clear()
	attack_open=false

func begin_charge():
	if active and not ended and dash_left<=0 and dash_cooldown<=0:
		if sprinting: velocity=velocity.limit_length(200*(1+.12*rank(6))*unit()*.45)
		sprinting=false
		charging=true
		charge=0
		sound.play("charge")

func release_dash():
	if not charging or not active: return
	sprinting=false
	charging=false
	start_attack()
	var strength=clampf(charge/.8,0,1)
	velocity=aim*(540+560*strength)*(1+.12*rank(1))*unit()
	dash_left=(.18+.18*strength)*(1+.15*rank(10))
	dash_cooldown=dash_left+maxf(.18,.65*pow(.88,rank(2)))
	charge=0
	sound.play("dash")

func push():
	if not active or ended or push_cd>0 or dash_left>0: return
	start_attack()
	push_cd=.55
	push_visual=.15
	var reach=body_radius()*(2.5+.5*rank(8))
	for e in enemies:
		var offset=e.pos-player
		if offset.length()<reach+e.radius and aim.dot(offset.normalized())>.5:
			attempt_hit(e,360*(1+.3*rank(8)),aim)
	resolve_contacts()
	settle_attack()
	sound.play("push")

func hit_info(e: RunEnemy,speed: float) -> Dictionary:
	return RunRules.impact(attack_mass if attack_open else mass,e.mass,speed,1+.2*rank(0),e.blocks_from(player))

func update_facing():
	var direction=aim if charging else velocity/maxf(1,unit())
	var threshold=.18 if charging else 18.0
	if absf(direction.x)>threshold: facing=signf(direction.x)

func attempt_hit(e: RunEnemy,speed: float,direction: Vector2):
	if e.dead or e.state=="spawn" or e.last_attack==dash_id or e.hit_cooldown>0: return
	e.last_attack=dash_id
	var result=hit_info(e,speed)
	var contact_point=e.pos-direction*e.radius*.65-Vector2(0,e.radius*.7)
	if not result.success:
		impact_feedback(contact_point,direction,.4,"armor" if result.reason=="armor" else "blocked")
		var message=trx("СЛИШКОМ КРУПНЫЙ","TOO HEAVY")
		if result.reason=="speed": message=trx("СЛАБЫЙ УДАР","LOW IMPACT")
		if result.reason=="armor": message=trx("БРОНЯ","ARMORED")
		if reason_time<=0:
			last_reason=message
			reason_time=1.4
		return
	e.hp-=result.damage
	e.hit_cooldown=.22
	e.flash=.12
	e.hit_direction=direction
	burst(e.pos,GameData.COLORS[e.kind],7)
	var feedback_strength=speed/1100.0*(.45+.85*sqrt(minf(2,e.mass/maxf(1,attack_mass))))
	impact_feedback(contact_point,direction,feedback_strength,"hit")
	if e.hp<=0:
		kill_enemy(e)
	else:
		# A successful ram is resolved before body contact. Recoil and a short stun
		# separate the actors; merely being in a dash never makes Kelly invulnerable.
		e.stun=.65 if e.kind<5 else .38
		e.velocity=direction*clampf(180+result.power*75,220,400)*unit()
		e.pos+=direction*body_radius()*.35
		if e.kind>=5:
			player=e.pos-direction*(body_radius()+e.radius+5*unit())
			velocity=-direction*180*unit()
			dash_left=0
		float_text(e.pos,"−"+str(result.damage),Color("fff0c7"))

func kill_enemy(e: RunEnemy):
	e.dead=true
	kills+=1
	var xp_value=RunRules.prey_xp(attack_mass,e.mass)
	if e.kind>=5: xp_value*=5
	drop_item(e.pos,"xp",maxi(4,xp_value))
	attack_pending.append({"mass":e.mass,"pos":e.pos})
	if kills%heart_interval()==0 or e.kind>=5:
		drop_item(e.pos,"heart",2 if e.kind>=5 else 1)
		if SHOW_TUTORIAL_HINTS: notice(trx("Выпало сердце — подбери для лечения","A heart dropped — pick it up to heal"),Color("ff99b1"))
	if e.kind>=5:
		boss_kills+=1;next_boss=maxf(next_boss,elapsed+45)
		if orbit_rank+pending_boss_rewards<3: pending_boss_rewards+=1
		sound.song("arena")

func heart_interval() -> int:
	return maxi(5,RunRules.HEART_EVERY-rank(11)*2)

func hurt(source: String):
	if ended or invincible>0: return
	incoming+=1
	if shield:
		shield=false
		invincible=.5
		float_text(player,trx("Щит!","Blocked!"),Color("f6d88c"))
		return
	if profile.data.assist and incoming%2==0:
		invincible=.5
		return
	hp-=1
	hurt_count+=1
	invincible=1
	hit_flash=.22
	shake=4
	impact_feedback(player,-aim,1,"hurt")
	last_reason=source+"  −1 ♥"
	reason_time=2
	float_text(player,"−1 ♥",Color("ff708e"))
	if hp<=0: finish(trx("Келли стала лужицей","Kelly became a puddle"))

func resolve_contacts():
	for e in enemies:
		if e.dead or e.state=="spawn" or e.stun>0: continue
		if player.distance_to(e.pos)<body_radius()+e.radius:
			hurt((GameData.NAMES_RU if profile.data.lang=="ru" else GameData.NAMES_EN)[e.kind])
			if ended: return

func gain_xp(value: float):
	xp+=value*(1+.2*rank(9))
	while xp>=RunRules.xp_needed(level):
		xp-=RunRules.xp_needed(level)
		level+=1
		pending_levels+=1

func maybe_upgrade():
	if pending_levels>0 and active and not ended and not attack_open and pending_boss_rewards<=0:
		active=false
		sprinting=false
		charging=false
		charge=0
		velocity=Vector2.ZERO
		shake=0;impact_kick=Vector2.ZERO;impact_pause=0
		level_up_left=LEVEL_UP_SECONDS
		level_up_paused=false
		sound.play("heal")

func choices() -> Array:
	var pool:Array=range(RunRules.UP_EN.size())
	var result:Array=[]
	for i in 3: result.append(pool.pop_at(rng.randi_range(0,pool.size()-1)))
	return result

func grant_upgrade(id: int):
	if id<0 or id>=RunRules.UP_EN.size() or pending_levels<=0: return
	upgrades[id]=rank(id)+1
	pending_levels-=1
	if id==4: max_hp+=1;hp=mini(max_hp,hp+2)
	if id==7: shield=true;shield_timer=30
	if id==11: hp=max_hp
	if id==12: stamina=minf(stamina_capacity(),stamina+.4)
	active=true
	sound.play("heal" if id in [4,11] else "click")

func finish(reason: String):
	if ended: return
	ended=true
	level_up_left=0
	active=false
	sprinting=false
	charging=false
	settle_attack()
	dash_left=0;dash_cooldown=0;push_visual=0
	velocity=Vector2.ZERO;invincible=0;hit_flash=0
	shake=0;impact_kick=Vector2.ZERO;impact_pause=0
	end_reason=reason
	profile.record_run(elapsed,mass,kills,level,run_seed)
	sound.play("lose")
	if hp<=0:
		death_animating=true
		death_elapsed=0
		labels.clear();impacts.clear()
	else: finished.emit()

func death_progress() -> float:
	return clampf(death_elapsed/DEATH_SECONDS,0,1)

func _physics_process(dt: float):
	clock+=dt
	queue_redraw()
	if ended:
		if death_animating:
			death_elapsed=minf(DEATH_SECONDS,death_elapsed+dt)
			if death_elapsed>=DEATH_SECONDS:
				death_animating=false
				finished.emit()
		return
	terrain_stage=move_toward(terrain_stage,terrain_target(),dt/1.5)
	if level_up_left>0:
		if not level_up_paused:
			update_feedback(dt)
			level_up_left=maxf(0,level_up_left-dt)
			if level_up_left<=0: choose_upgrade.emit()
		return
	if not active: return
	update_feedback(dt)
	if impact_pause>0:
		impact_pause=maxf(0,impact_pause-dt)
		return
	elapsed+=dt
	ecology_mass=lerpf(ecology_mass,mass,1-exp(-dt/24.0))
	banner_time=maxf(0,banner_time-dt)
	reason_time=maxf(0,reason_time-dt)
	invincible=maxf(0,invincible-dt)
	hit_flash=maxf(0,hit_flash-dt)
	absorb_visual=maxf(0,absorb_visual-dt)
	push_cd=maxf(0,push_cd-dt)
	push_visual=maxf(0,push_visual-dt)
	dash_cooldown=maxf(0,dash_cooldown-dt)
	shake=maxf(0,shake-20*dt)
	if rank(7)>0:
		shield_timer-=dt
		if shield_timer<=0: shield=true;shield_timer=maxf(8,30-rank(7)*2)
	var new_wave=1+int(elapsed/25)
	if new_wave>wave:
		wave=new_wave
		notice(trx("ВОЛНА %d","WAVE %d")%wave)
	if not no_spawns:
		spawn_boss_if_due()
		spawn_timer-=dt
		if spawn_timer<=0:
			spawn_group()
			spawn_timer=3.2 if fmod(elapsed,25.0)>=18 else maxf(1.1,2.7-elapsed*.003)
	var move=Input.get_vector("left","right","up","down")
	if bot: move=bot_input()
	else:
		if gamepad:
			var stick=Vector2(Input.get_joy_axis(joy_device,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy_device,JOY_AXIS_RIGHT_Y))
			if stick.length()>.2: aim=stick.normalized()
			elif move.length()>.2 and not charging: aim=move.normalized()
		else:
			var delta=to_world(get_global_mouse_position())-player
			if delta.length()>2: aim=delta.normalized()
	if charging:
		charge=minf(.8,charge+dt)
		if profile.data.aim_help:
			var best=aim_target()
			if best and not best.armored(): aim=aim.lerp((best.pos-player).normalized(),.05).normalized()
	var sprint_was_active=sprinting
	update_sprint(dt,move.length_squared()>.01,Input.is_action_pressed("sprint") and not bot)
	if dash_left>0:
		for step in 6:
			var before=player
			player+=velocity*dt/6
			orbit_step(before,player,dt/6)
			for e in enemies:
				if e.dead: continue
				var near=Geometry2D.get_closest_point_to_segment(e.pos,before,player)
				if near.distance_to(e.pos)<body_radius()+e.radius: attempt_hit(e,velocity.length()/unit(),velocity.normalized())
			resolve_contacts()
			if ended: break
		dash_left=maxf(0,dash_left-dt)
		if dash_left<=0: settle_attack()
	else:
		var speed=200.0*(1+.12*rank(6))*unit()
		if sprinting: speed*=sprint_multiplier()
		if charging: speed*=.45
		for p in puddles:
			if player.distance_to(p.p)<p.r+body_radius(): speed*=.75;break
		if sprint_was_active and not sprinting: velocity=velocity.limit_length(speed)
		velocity=velocity.move_toward(move*speed,2200*unit()*dt)
		player+=velocity*dt
		var touching=false
		for e in enemies:
			if not e.dead and e.state!="spawn" and e.stun<=0 and player.distance_to(e.pos)<body_radius()+e.radius:
				if not touching: start_attack();touching=true
				attempt_hit(e,velocity.length()/unit(),velocity.normalized())
		resolve_contacts()
		if touching: settle_attack()
	if ended: return
	update_facing()
	for e in enemies:
		if not e.dead: e.step(dt,self)
	resolve_contacts()
	if ended: return
	enemies=enemies.filter(func(e): return not e.dead)
	# Keep the simulation bounded while leaving the world unbounded. Distant bosses
	# retain their state; ordinary enemies beyond the active region are despawned.
	for e in enemies:
		if e.kind>=5 and e.pos.distance_to(player)*zoom>1300:
			e.pos=player+(e.pos-player).normalized()*700/zoom
			e.state="spawn";e.timer=1.2
	enemies=enemies.filter(func(e): return e.kind>=5 or e.pos.distance_to(player)*zoom<1500)
	step_pickups(dt)
	step_projectiles(dt)
	if ended: return
	for p in puddles: p.life-=dt
	puddles=puddles.filter(func(p): return p.life>0)
	for p in particles: p.p+=p.v*dt;p.life-=dt
	particles=particles.filter(func(p): return p.life>0)
	for l in labels: l.p.y-=18*dt/zoom;l.life-=dt
	labels=labels.filter(func(l): return l.life>0)
	zoom=lerpf(zoom,RunRules.zoom_for(mass),minf(1,dt*3))
	camera=camera.lerp(player,minf(1,dt*9))
	# Floating origin prevents precision loss during long-distance travel.
	if player.length()>100000:
		var shift=player.snapped(Vector2(4096,4096))
		origin_sectors+=shift/4096
		player-=shift;camera-=shift
		for e in enemies: e.pos-=shift
		for list in [items,particles,labels,bullets,puddles,attack_pending,impacts]:
			for entry in list:
				if entry.has("p"): entry.p-=shift
				elif entry.has("pos"): entry.pos-=shift
	maybe_boss_reward()
	maybe_upgrade()

func step_pickups(dt: float):
	var reach=body_radius()+(35+rank(5)*25)/zoom
	for item in items:
		item.age+=dt
		if item.type=="heart" and hp>=max_hp: continue
		if item.p.distance_to(player)<reach+50/zoom: item.p=item.p.move_toward(player,360*dt/zoom)
		if item.p.distance_to(player)<body_radius()+10/zoom:
			if item.type=="xp": gain_xp(item.value);sound.play("pickup")
			else:
				var healed=mini(int(item.value),max_hp-hp)
				hp=mini(max_hp,hp+int(item.value))
				float_text(player,trx("+%d ♥ лечение","+%d hearts healed")%healed,Color("ff91ad"))
				sound.play("heal")
			item.age=-1
	items=items.filter(func(item): return item.age>=0)
	# Preserve XP value when compacting distant drops instead of leaking item count.
	if items.size()>180:
		var sum=0.0
		for item in items:
			if item.type=="xp" and item.p.distance_to(player)*zoom>900:
				sum+=item.value;item.age=-1
		items=items.filter(func(item): return item.age>=0)
		if sum>0: drop_item(player+Vector2.from_angle(rng.randf()*TAU)*450/zoom,"xp",sum)

func step_projectiles(dt: float):
	for b in bullets:
		var before:Vector2=b.p
		b.p+=b.v*dt;b.life-=dt
		if Geometry2D.get_closest_point_to_segment(player,before,b.p).distance_to(player)<body_radius()+b.r:
			hurt(trx("Снаряд","Projectile"));b.life=-1
			if ended: break
	bullets=bullets.filter(func(b): return b.life>0)

func aim_target():
	var target=null
	var distance=700.0/zoom
	for e in enemies:
		if e.dead or e.state=="spawn": continue
		var offset=e.pos-player
		if offset.length()<distance and aim.dot(offset.normalized())>.88:
			distance=offset.length();target=e
	return target

func bot_input() -> Vector2:
	var target=null
	var closest=INF
	for e in enemies:
		if e.state=="spawn" or e.armored() or mass/e.mass<.55: continue
		var dist=player.distance_to(e.pos)
		if dist<closest: closest=dist;target=e
	if target:
		aim=(target.pos-player).normalized()
		if not charging and dash_cooldown<=0: begin_charge()
		if charging and charge>=.65: release_dash()
		if closest<2.5*body_radius()+target.radius: push()
		return aim if closest>body_radius()+target.radius+45*unit() else -aim
	if not items.is_empty(): return (items[0].p-player).normalized()
	return Vector2.from_angle(clock*.1)

func _draw():
	if art: art.draw_run(self)
