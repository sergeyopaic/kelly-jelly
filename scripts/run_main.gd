extends Node2D

var profile: JellyProfile
var sound: JellySound
var art: RunArt
var arena: RunArena
var ui: Control
var screen="menu"
var clock=0.0
var hud_label:Label
var mass_label:Label
var status_label:Label
var banner_label:Label
var boss_label:Label
var time_label:Label
var xp_bar:JellyMeter
var health_bar:JellyMeter
var xp_label:Label
var settings_return="menu"
var binding_wait=""
var binding_label:Label
var gamepad=false
var joy_device=0
var quitting=false
var capture_mode=""
var capture_clock=0.0
var smoke=false
var smoke_clock=0.0
var capture_tag=""
var capture_width=0
var game_speed=1

func speed_key(key:int) -> int:
	match key:
		KEY_1,KEY_KP_1: return 1
		KEY_2,KEY_KP_2: return 2
		KEY_3,KEY_KP_3: return 3
	return 0

func sync_game_speed():
	var multiplier=game_speed if screen=="play" and is_instance_valid(arena) and arena.active and not arena.ended else 1
	Engine.time_scale=float(multiplier)
	# Keep the simulated physics step at 1/60 second even at triple speed.
	Engine.physics_ticks_per_second=60*multiplier

func handle_speed_key(event:InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo: return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed: return false
	if screen not in ["play","pause"] or not is_instance_valid(arena) or arena.ended: return false
	var key=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	var value=speed_key(key)
	if value==0: return false
	game_speed=value
	sync_game_speed()
	return true

func tr2(ru: String,en: String) -> String:
	return ru if profile.data.lang=="ru" else en

func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().auto_accept_quit=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_mode=arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-width="): capture_width=int(arg.trim_prefix("--capture-width="))
		if arg=="--smoke": smoke=true
	profile=JellyProfile.new("user://survivors_test.json" if smoke or capture_mode!="" else "")
	if not profile.data.visual_english:
		profile.data.lang="en"
		profile.data.visual_english=true
		profile.save()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-lang=") and capture_mode!="": profile.data.lang=arg.trim_prefix("--capture-lang=")
	setup_inputs()
	art=RunArt.new()
	sound=JellySound.new();add_child(sound);sound.setup(profile)
	ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	var ui_theme=Theme.new()
	ui_theme.default_font=art.skin.body
	ui_theme.default_font_size=17
	ui.theme=ui_theme
	apply_display()
	show_menu()
	if smoke: start_run(271828);arena.bot=true
	if capture_mode in ["speed2","speed3","death_start","death_middle","death_puddle","terrain_before","terrain_after","terrain_full","orbit","orbit_reward","pause_orbit","arena","growth","boss","upgrades","pause","pause_upgrades","pause_full","caramel","mint","charge","charge_large","hud_partial","hud_empty","hud_full","sprint","sprint_upgrades","impact","armor_hit","waffle","warnings","facing_left","facing_right","walk_left","walk_right","level_up","level_up_end"]:
		start_run(1847)
		if capture_mode in ["speed2","speed3"]:
			arena.set_physics_process(false);arena.enemies.clear();arena.no_spawns=true
			game_speed=2 if capture_mode=="speed2" else 3
			arena.elapsed=95;sync_game_speed()
		if capture_mode.begins_with("death_"):
			arena.set_physics_process(false);arena.enemies.clear();arena.no_spawns=true
			arena.mass=300;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.hp=1;arena.hurt("Capture")
			arena.death_elapsed=arena.DEATH_SECONDS*(.05 if capture_mode=="death_start" else (.48 if capture_mode=="death_middle" else .92))
		if capture_mode.begins_with("terrain_"):
			arena.set_physics_process(false);arena.enemies.clear();arena.no_spawns=true
			arena.elapsed=120;arena.mass=100;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.terrain_stage=0 if capture_mode=="terrain_before" else (1 if capture_mode=="terrain_after" else 3)
			arena.drop_item(Vector2(100,40),"xp",8);arena.drop_item(Vector2(-100,40),"heart",1)
			for data in [[1,Vector2(-230,80),Vector2.RIGHT],[3,Vector2(180,100),Vector2(-.4,-1).normalized()]]:
				arena.spawn_enemy(data[0],30,data[1])
				var e=arena.enemies.back();e.state="telegraph";e.face=data[2];e.timer=e.warning_duration()*.35
		if capture_mode in ["orbit","orbit_reward","pause_orbit"]:
			arena.set_physics_process(false);arena.enemies.clear();arena.no_spawns=true
			arena.mass=300;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.orbit_rank=3;arena.aim=Vector2.RIGHT
			arena.charging=true;arena.charge=.8;arena.release_dash();arena.orbit_angle=.45
			if capture_mode=="orbit_reward":
				arena.dash_left=0;arena.settle_attack();arena.orbit_rank=0;arena.pending_boss_rewards=1;arena.active=false;show_boss_reward()
			if capture_mode=="pause_orbit":
				for id in RunRules.UP_EN.size(): arena.upgrades[id]=1
		if capture_mode in ["level_up","level_up_end"]:
			arena.mass=300;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.gain_xp(RunRules.xp_needed(arena.level));arena.maybe_upgrade()
			if capture_mode=="level_up":
				arena.set_physics_process(false);arena.level_up_left=arena.LEVEL_UP_SECONDS*.5
		if capture_mode in ["waffle","warnings","facing_left","facing_right","walk_left","walk_right"]:
			arena.set_physics_process(false);arena.enemies.clear()
			if capture_mode=="waffle":
				arena.mass=60;arena.zoom=RunRules.zoom_for(arena.mass)
				for i in 2:
					arena.spawn_enemy(2,50,Vector2(-120 if i==0 else 120,0))
					arena.enemies[i].state="rest" if i==0 else "guard"
					arena.enemies[i].face=Vector2.LEFT;arena.enemies[i].timer=.65
			if capture_mode=="warnings":
				for data in [[1,Vector2(-230,80),Vector2.RIGHT],[3,Vector2(180,160),Vector2(-.4,-1).normalized()],[6,Vector2(-230,-130),Vector2.RIGHT]]:
					arena.spawn_enemy(data[0],30,data[1])
					var e=arena.enemies.back()
					e.state="telegraph";e.face=data[2];e.timer=e.warning_duration()*.35
			if capture_mode.begins_with("facing_") or capture_mode.begins_with("walk_"):
				arena.mass=300;arena.zoom=RunRules.zoom_for(arena.mass)
				arena.velocity=Vector2(-200 if capture_mode.ends_with("left") else 200,0)*arena.unit()
				arena.sprinting=capture_mode.begins_with("facing_");arena.stamina=.7;arena.clock=.3;arena.update_facing()
		if capture_mode in ["impact","armor_hit"]:
			arena.set_physics_process(false);arena.enemies.clear()
			arena.mass=100;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.spawn_enemy(5,150,Vector2(80,0))
			var target=arena.enemies[0]
			target.state="rest" if capture_mode=="impact" else "chase"
			arena.aim=Vector2.RIGHT;arena.start_attack()
			arena.attempt_hit(target,1100,Vector2.RIGHT)
			arena.update_feedback(.07)
			target.flash=minf(target.flash,.09)
		if capture_mode=="sprint":
			arena.set_physics_process(false);arena.enemies.clear()
			arena.mass=300;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.sprinting=true;arena.stamina=.65;arena.clock=.32;arena.velocity=Vector2(340,0)*arena.unit()
		if capture_mode=="sprint_upgrades":
			arena.pending_levels=1;arena.active=false;show_upgrades()
		if capture_mode.begins_with("hud_"):
			arena.set_physics_process(false);arena.enemies.clear()
			arena.hp=3 if capture_mode=="hud_partial" else (0 if capture_mode=="hud_empty" else arena.max_hp)
			arena.xp=11 if capture_mode=="hud_partial" else (0 if capture_mode=="hud_empty" else RunRules.xp_needed(arena.level))
			arena.spawn_enemy(5,150,Vector2(170,70))
			arena.enemies[0].state="rest";arena.enemies[0].hp=maxi(1,int(arena.enemies[0].max_hp*.5))
		if capture_mode in ["charge","charge_large"]:
			arena.set_physics_process(false)
			arena.enemies.clear();arena.charging=true;arena.charge=.8
			if capture_mode=="charge_large": arena.mass=1800;arena.zoom=RunRules.zoom_for(arena.mass)
		if capture_mode in ["caramel","mint"]:
			arena.elapsed=180 if capture_mode=="caramel" else 360
			arena.terrain_stage=2 if capture_mode=="caramel" else 1
			arena.no_spawns=true
		if capture_mode=="growth":
			arena.mass=1800;arena.zoom=RunRules.zoom_for(arena.mass)
			arena.enemies.clear()
			for i in 24: arena.spawn_enemy(i%5,[8.0,30.0,200.0,900.0,2800.0][i%5],Vector2.from_angle(i*2.4)*(200+i*25))
		if capture_mode=="boss": arena.spawn_enemy(5,150,Vector2(200,-60));arena.mass=100
		if capture_mode=="upgrades": arena.pending_levels=1;arena.active=false;show_upgrades()
		if capture_mode.begins_with("pause"):
			if capture_mode=="pause_upgrades": arena.upgrades={0:3,2:1,7:2,12:4,14:12}
			if capture_mode=="pause_full":
				for id in RunRules.UP_EN.size(): arena.upgrades[id]=id+1
			show_pause()
			if capture_mode=="pause_full": ui.get_node("Upgrade14").grab_focus()
			if capture_mode=="pause_orbit": ui.get_node("Upgrade100").grab_focus()
	if capture_mode=="settings": show_settings("menu")
	if capture_mode=="help": show_help("menu")
	if capture_mode=="credits": show_credits()
	if capture_mode!="":
		set_process_input(false)
		get_viewport().gui_disable_input=true

func start_run(seed_value: int=0):
	stop_arena();clear_ui()
	game_speed=1
	screen="play"
	arena=RunArena.new();add_child(arena);move_child(arena,0)
	arena.setup(profile,sound,art,seed_value)
	arena.gamepad=gamepad;arena.joy_device=joy_device
	arena.finished.connect(show_result)
	arena.choose_upgrade.connect(show_upgrades)
	arena.boss_reward.connect(show_boss_reward)
	show_hud()

func show_menu():
	stop_arena();clear_ui();screen="menu";sound.song("menu")
	button(tr2("НОВЫЙ ЗАБЕГ","NEW RUN"),Rect2(50,278,325,48),func(): start_run(),true)
	button(tr2("Как выжить","How to survive"),Rect2(50,338,157,40),func(): show_help("menu"))
	button(tr2("Настройки","Settings"),Rect2(218,338,157,40),func(): show_settings("menu"))
	button(tr2("Рекорды","Run records"),Rect2(50,388,157,40),show_records)
	button(tr2("Авторы","Credits"),Rect2(218,388,157,40),show_credits)
	button(tr2("Выход","Quit"),Rect2(50,439,325,36),quit_game)
	label_at(tr2("Расти. Разгоняйся. Поглощай.","Grow. Accelerate. Devour."),Rect2(50,485,570,25),16,Color("bddccc"))
	label_at("v2.6.1 / THE SWEET WILDS",Rect2(720,508,220,20),11,Color("ddc3ce"))
	focus_first()

func progress(rect: Rect2,color: Color) -> JellyMeter:
	var bar=JellyMeter.new();bar.position=rect.position;bar.size=rect.size;bar.color=color
	bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(bar)
	return bar

func hud_panel(rect:Rect2,kind:String):
	var panel=SweetHUD.new();panel.kind=kind
	panel.position=rect.position;panel.size=rect.size
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(panel)

func display_font(label:Label):
	label.add_theme_font_override("font",art.skin.heading if profile.data.lang=="en" else art.skin.body)

func show_hud():
	clear_ui();screen="play"
	sync_game_speed()
	hud_panel(Rect2(22,18,220,70),"health")
	art.skin.icon_rect(14,Rect2(31,26,36,36),ui)
	hud_label=label_at("",Rect2(88,24,140,22),18,Color("fff0d1"))
	health_bar=progress(Rect2(88,51,136,10),Color("ed8dac"))
	art.skin.icon_rect(12,Rect2(43,79,14,16),ui)
	mass_label=label_at("",Rect2(64,75,175,23),14,Color("f0c6d4"))
	hud_panel(Rect2(325,14,310,80),"growth")
	status_label=label_at("",Rect2(436,15,88,30),22,Color("3f2b40"),true);display_font(status_label)
	xp_bar=progress(Rect2(348,53,264,9),Color("afe2c8"))
	xp_label=label_at("",Rect2(350,73,260,19),12,Color("dfebdc"),true)
	hud_panel(Rect2(746,18,138,70),"clock")
	time_label=label_at("",Rect2(752,23,126,37),27,Color("fff0d1"),true);display_font(time_label)
	boss_label=label_at("",Rect2(717,76,205,20),12,Color("e5c5cf"),true)
	var pause=button("",Rect2(896,23,42,40),show_pause)
	pause.icon=load("res://assets/ui/pause.svg");pause.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	pause.tooltip_text=tr2("Пауза","Pause")
	banner_label=label_at("",Rect2(240,111,480,26),19,Color("fff0d1"),true);display_font(banner_label)

func show_pause():
	if not is_instance_valid(arena) or arena.ended: return
	arena.level_up_paused=true
	arena.active=false;arena.charging=false;arena.sprinting=false;arena.charge=0
	clear_ui();screen="pause"
	sync_game_speed()
	box(Rect2(160,30,640,480),Color(.13,.09,.18,.97))
	label_at(tr2("ПЕРЕДОХНЁМ?","TAKE A BREATHER?"),Rect2(220,49,520,40),27,JellyArt.CREAM,true)
	button(tr2("Продолжить забег","Resume run"),Rect2(290,105,380,43),resume,true)
	button(tr2("Настройки","Settings"),Rect2(290,161,185,38),func(): show_settings("pause"))
	button(tr2("Правила боя","Combat rules"),Rect2(485,161,185,38),func(): show_help("pause"))
	label_at(tr2("УСИЛЕНИЯ ЗАБЕГА","RUN UPGRADES"),Rect2(210,209,540,22),12,Color("a7ddc9"),true)
	show_pause_upgrades()
	button(tr2("Завершить забег","End this run"),Rect2(290,452,380,36),confirm_end)
	focus_first()

func show_pause_upgrades():
	var owned:Array[int]=[]
	for id in RunRules.UP_EN.size():
		if arena.rank(id)>0: owned.append(id)
	if arena.orbit_rank>0: owned.append(100)
	if owned.is_empty():
		label_at(tr2("Пока нет усилений","No upgrades yet"),Rect2(210,270,540,30),20,Color("d2bccc"),true)
		label_at(tr2("Собирай опыт и выбирай усиления при повышении уровня.","Collect XP and choose upgrades when you level up."),Rect2(200,310,560,30),14,Color("a58d9f"),true)
		return
	var title=label_at(tr2("Выбери иконку, чтобы узнать подробности","Select an upgrade to see its details"),Rect2(200,377,560,24),16,JellyArt.CREAM,true)
	var description=label_at("",Rect2(200,403,560,36),14,Color("d2bccc"),true)
	description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for index in owned.size():
		var id=owned[index]
		var row=index/8
		var columns=mini(8,owned.size()-row*8)
		var origin=Vector2(480-(columns*72-8)*.5+(index%8)*72,238+row*66)
		var tile=Button.new()
		tile.name="Upgrade%d"%id
		tile.position=origin;tile.size=Vector2(64,58)
		for state in ["normal","hover","pressed","focus"]:
			var style=art.skin.hud_style()
			style.bg_color=Color("332538") if state=="normal" else Color("654158")
			style.border_color=Color("745368") if state=="normal" else Color("edc27f")
			tile.add_theme_stylebox_override(state,style)
		ui.add_child(tile)
		if id==100:
			var emblem=Node2D.new();tile.add_child(emblem)
			emblem.draw.connect(func(): art.draw_orbit_badge(emblem,Vector2(29,26),18,arena.orbit_count()))
		else: art.skin.icon_rect(id if id<12 else id+4,Rect2(7,4,44,44),tile)
		var badge=Panel.new()
		badge.position=Vector2(32,35);badge.size=Vector2(32,22)
		badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var badge_style=art.skin.hud_style();badge_style.bg_color=Color("231b2b")
		badge.add_theme_stylebox_override("panel",badge_style);tile.add_child(badge)
		var number=Label.new();number.text=str(arena.orbit_rank if id==100 else arena.rank(id))
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;number.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size",14);number.add_theme_color_override("font_color",Color("f6d391"))
		number.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;number.mouse_filter=Control.MOUSE_FILTER_IGNORE
		badge.add_child(number)
		var name_text=tr2("Карамельная орбита","Candy Orbit") if id==100 else (RunRules.UP_RU if profile.data.lang=="ru" else RunRules.UP_EN)[id]
		var heading=name_text+tr2(" · Уровень %d"," · Level %d")%(arena.orbit_rank if id==100 else arena.rank(id))
		var body=orbit_description(arena.orbit_rank) if id==100 else tr2("За уровень: ","Per level: ")+(RunRules.DESC_RU if profile.data.lang=="ru" else RunRules.DESC_EN)[id]
		tile.tooltip_text=heading+"\n"+body
		var reveal=func(): title.text=heading;description.text=body
		tile.mouse_entered.connect(reveal);tile.focus_entered.connect(reveal);tile.pressed.connect(reveal)

func resume():
	show_hud();arena.level_up_paused=false;arena.active=arena.level_up_left<=0
	sync_game_speed()

func orbit_description(stage:int) -> String:
	return tr2("%d лепестка на орбите во время дэша%s. Мелочь разрубается; поглощение — только за дэш без потери HP.","%d petals orbit during your dash%s. Slice tiny prey; absorb only if no HP is lost during that dash.")%[5 if stage>=3 else 3,tr2(" по широкой дуге"," in a wider circle") if stage>=2 else ""]

func show_boss_reward():
	clear_ui();screen="boss_reward"
	sync_game_speed()
	box(Rect2(180,95,600,350),Color(.13,.09,.18,.98))
	label_at(tr2("НАГРАДА ЗА БОССА","BOSS REWARD"),Rect2(205,117,550,32),22,Color("f6d391"),true)
	var stage=mini(3,arena.orbit_rank+1)
	var emblem=Node2D.new();ui.add_child(emblem)
	var count=5 if stage>=3 else 3
	emblem.draw.connect(func(): art.draw_orbit_badge(emblem,Vector2(480,208),35,count))
	label_at(tr2("Карамельная орбита · %d","Candy Orbit · %d")%stage,Rect2(205,255,550,35),26,JellyArt.CREAM,true)
	var desc=label_at("",Rect2(230,300,500,65),16,Color("d2bccc"),true)
	desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	desc.size=Vector2(500,65)
	desc.text=orbit_description(stage)
	button(tr2("Получить","Claim"),Rect2(330,384,300,40),func(): arena.accept_boss_reward();show_hud(),true)
	focus_first()
	if smoke: arena.accept_boss_reward();show_hud()

func confirm_end():
	clear_ui();screen="confirm"
	box(Rect2(235,155,490,235))
	label_at(tr2("Завершить этот забег?","End this run?"),Rect2(255,178,450,40),26,JellyArt.CREAM,true)
	label_at(tr2("Рекорд сохранится. Масса и улучшения сбросятся.","Your record stays. Mass and upgrades reset."),Rect2(250,239,460,30),16,JellyArt.CREAM,true)
	button(tr2("Остаться","Stay"),Rect2(275,316,190,42),show_pause,true)
	button(tr2("Завершить","End run"),Rect2(490,316,190,42),func(): arena.finish(tr2("Забег завершён","Run ended")))
	focus_first()

func show_upgrades():
	clear_ui();screen="upgrades"
	sync_game_speed()
	box(Rect2(36,100,888,335),Color(.13,.09,.17,.98))
	label_at(tr2("НОВЫЙ УРОВЕНЬ %d — ВЫБЕРИ ВКУС","LEVEL %d — PICK A FLAVOUR")%arena.level,Rect2(50,124,860,40),26,JellyArt.CREAM,true)
	label_at(tr2("Опыт → выбор улучшения. Действует до конца забега.","Experience → your choice of upgrade. Lasts for this run."),Rect2(50,173,860,30),16,Color("a5dce9"),true)
	var choices=[12,13,14] if capture_mode=="sprint_upgrades" else arena.choices()
	for i in 3:
		var id:int=choices[i]
		var x=60+i*286
		box(Rect2(x,218,268,187),Color("493044"))
		art.skin.icon_rect(id if id<12 else id+4,Rect2(x+108,226,52,48),ui)
		label_at("+"+str(arena.rank(id)+1),Rect2(x+210,233,42,26),19,Color("f6d391"),true)
		label_at((RunRules.UP_RU if profile.data.lang=="ru" else RunRules.UP_EN)[id],Rect2(x+8,272,252,28),18,JellyArt.CREAM,true)
		var desc=label_at((RunRules.DESC_RU if profile.data.lang=="ru" else RunRules.DESC_EN)[id],Rect2(x+14,309,240,44),14,Color("d2bdcd"),true);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		button(tr2("Выбрать","Choose"),Rect2(x+20,360,228,34),func(): arena.grant_upgrade(id);show_hud(),i==0)
	focus_first()
	if smoke:
		arena.grant_upgrade(choices[0]);show_hud()

func show_result():
	Engine.time_scale=1.0
	Engine.physics_ticks_per_second=60
	clear_ui();screen="result"
	box(Rect2(215,85,530,380),Color(.13,.09,.18,.97))
	label_at(arena.end_reason,Rect2(230,107,500,42),26,JellyArt.CREAM,true)
	var body=tr2("Время: %s     Волна: %d\nМасса: %s  (×%.1f от старта)\nПобеды: %d     Поглощено: %d\nУровень: %d     Seed: %d","Time: %s     Wave: %d\nMass: %s  (×%.1f from start)\nDefeated: %d     Absorbed: %d\nLevel: %d     Seed: %d")%[RunRules.time_text(arena.elapsed),arena.wave,RunRules.amount(arena.mass),arena.mass/30,arena.kills,arena.absorbed,arena.level,arena.run_seed]
	label_at(body,Rect2(250,175,460,140),20,Color("d8bfd0"),true)
	label_at(tr2("Следующий забег — новый рост и новые решения.","Next run. New growth. New choices."),Rect2(235,325,490,25),16,Color("a7ddc9"),true)
	button(tr2("Ещё забег!","Another run!"),Rect2(265,385,210,44),func(): start_run(),true)
	button(tr2("В меню","Main menu"),Rect2(490,385,210,44),show_menu)
	focus_first()
	if smoke: save_smoke();quit_game()

func show_records():
	clear_ui();screen="records"
	label_at(tr2("ИСТОРИЯ РОСТА","GROWTH RECORDS"),Rect2(100,75,760,50),36,JellyArt.CREAM,true)
	label_at(tr2("Лучшее время: %s\nМаксимальная масса: %s\nБольше всего побед: %d\nЗавершённых забегов: %d","Longest run: %s\nGreatest mass: %s\nMost defeats: %d\nCompleted runs: %d")%[RunRules.time_text(profile.data.best_time),RunRules.amount(profile.data.best_mass),profile.data.best_kills,profile.data.runs],Rect2(200,180,560,190),25,Color("d6c0d1"),true)
	button(tr2("Назад","Back"),Rect2(350,430,260,44),show_menu,true);focus_first()

func show_help(back: String):
	clear_ui();screen="help";settings_return=back
	box(Rect2(60,30,840,480))
	label_at(tr2("МАССА × СКОРОСТЬ = СИЛА УДАРА","MASS × SPEED = IMPACT"),Rect2(80,50,800,40),27,JellyArt.CREAM,true)
	var body=tr2("WASD — движение. Мышь — прицел. ЛКМ: удерживай → отпусти.\nПКМ / Пробел — короткий толчок. Esc — пауза.\nShift / LB — ускорение с выносливостью, только при обычном беге.\n\nУдачный таран ранит и отбрасывает врага: ответного урона нет.\nНе хватило массы или скорости? Опасное касание снимает ♥.\nУбийство без урона в этой атаке → поглощение и рост.\nЗолотой щит вафли: обойди сзади или дождись, пока он исчезнет.\n\nГолубые кристаллы = опыт → уровень → одно из 3 улучшений.\nСердца: каждые 12 побед и с боссов. При полном HP сохраняются.\nБосс с фиолетовой бронёй неуязвим. Надпись «БЕЙ!» — окно удара.\nКольца: зелёный — добьёшь; жёлтый — ранишь; красный — опасно.","WASD moves. Mouse aims. Hold LMB → release to dash.\nRMB / Space: short push. Esc: pause.\nHold Shift / LB: sprint with stamina. Dash speed is unchanged.\n\nA strong ram hurts and knocks back: no return contact damage.\nToo little mass or speed? Dangerous contact costs a heart.\nKill without taking damage during that attack → absorb and grow.\nGold waffle shield: attack from behind or wait for it to lower.\n\nBlue crystals = XP → level → choose one of 3 upgrades.\nHearts: every 12 kills and bosses. Kept when HP is full.\nPurple boss armor blocks hits. RAM! marks its vulnerable window.\nRings: green = lethal; yellow = damage; red = danger.")
	label_at(body,Rect2(95,105,770,340),16,Color("dec7d7"))
	button(tr2("Понятно","Got it"),Rect2(330,464,300,38),func():
		if back=="pause": show_pause()
		else: show_menu(),true)
	focus_first()

func _process(dt: float):
	sync_game_speed()
	clock+=dt;queue_redraw()
	if is_instance_valid(arena):
		arena.position=(Vector2(sin(clock*95),cos(clock*81))*arena.shake+arena.impact_kick)*profile.data.shake
	if screen=="play" and is_instance_valid(hud_label):
		hud_label.text="%d / %d"%[arena.hp,arena.max_hp]
		health_bar.max_value=arena.max_hp;health_bar.value=arena.hp
		mass_label.text=tr2("МАССА  %s","MASS  %s")%RunRules.amount(arena.mass)
		time_label.text=RunRules.time_text(arena.elapsed)+( " ×%d"%game_speed if game_speed>1 else "")
		time_label.add_theme_font_size_override("font_size",22 if game_speed>1 else 27)
		status_label.text=tr2("УР. %d","LV. %d")%arena.level
		xp_label.text="%s / %s XP"%[RunRules.amount(arena.xp),RunRules.amount(RunRules.xp_needed(arena.level))]
		xp_bar.max_value=RunRules.xp_needed(arena.level);xp_bar.value=arena.xp
		boss_label.text=tr2("ВОЛНА %d  ·  %d ПОБЕД","WAVE %d  ·  %d KILLS")%[arena.wave,arena.kills]
		banner_label.text=arena.banner if arena.banner_time>0 else ""

	if capture_mode!="":
		capture_clock+=dt
		if capture_clock>2:
			capture(capture_mode);capture_mode="";quit_game()
	if smoke:
		smoke_clock+=dt
		if smoke_clock>300: arena.finish("TEST 300s")

func save_smoke():
	var path="res://docs/survivors_bot.json" if OS.has_feature("editor") else "user://survivors_bot.json"
	var file=FileAccess.open(path,FileAccess.WRITE)
	var report={"time":arena.elapsed,"mass":arena.mass,"kills":arena.kills,"level":arena.level,"hp":arena.hp,"seed":arena.run_seed,"enemies":arena.enemies.size(),"items":arena.items.size()}
	file.store_string(JSON.stringify(report,"\t"));print("RUN_REPORT ",JSON.stringify(report))

func capture(which: String):
	var directory="res://docs/screenshots_v2" if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()+"/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var suffix="_%d"%capture_width if capture_width>0 else ""
	get_viewport().get_texture().get_image().save_png(directory+"/"+which+suffix+".png")
	print("SCREENSHOT ",which)

func _draw():
	if not art or not profile: return
	if screen=="menu": art.draw_menu(self,clock,profile.data.skin)
	elif not is_instance_valid(arena): art.backdrop(self,clock)

func setup_inputs():
	var keys = {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"up":[KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"push":[KEY_SPACE],"pause":[KEY_ESCAPE],"sprint":[KEY_SHIFT],"dash":[]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action,0.2)
		InputMap.action_erase_events(action)
		for code in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action,event)
		if profile.data.bindings.has(action) and speed_key(int(profile.data.bindings[action]))==0:
			InputMap.action_erase_events(action)
			var event = InputEventKey.new()
			event.physical_keycode = int(profile.data.bindings[action])
			InputMap.action_add_event(action,event)
	for info in [["dash",MOUSE_BUTTON_LEFT],["push",MOUSE_BUTTON_RIGHT]]:
		var event = InputEventMouseButton.new()
		event.button_index = info[1]
		InputMap.action_add_event(info[0],event)
	for info in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["up",JOY_AXIS_LEFT_Y,-1.0],["down",JOY_AXIS_LEFT_Y,1.0],["dash",JOY_AXIS_TRIGGER_RIGHT,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = info[1]
		event.axis_value = info[2]
		InputMap.action_add_event(info[0],event)
	for info in [["push",JOY_BUTTON_A],["pause",JOY_BUTTON_START],["sprint",JOY_BUTTON_LEFT_SHOULDER]]:
		var event = InputEventJoypadButton.new()
		event.button_index = info[1]
		InputMap.action_add_event(info[0],event)


func apply_display():
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_title("Kelly Jelly • The Sweet Wilds")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if profile.data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if profile.data.vsync else DisplayServer.VSYNC_DISABLED)
	if not profile.data.fullscreen:
		DisplayServer.window_set_size([Vector2i(1440,810),Vector2i(1280,720),Vector2i(1920,1080)][clampi(profile.data.resolution,0,2)])
	if capture_mode!="" and capture_width in [1280,1440,1920]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(capture_width,capture_width*9/16))


func clear_ui():
	for node in ui.get_children():
		ui.remove_child(node)
		node.queue_free()
	hud_label = null
	mass_label = null
	status_label = null
	banner_label = null
	boss_label = null
	time_label = null


func label_at(value: String,rect: Rect2,size: int = 18,color: Color = JellyArt.CREAM,center: bool = false) -> Label:
	var label = Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_font_override("font",art.skin.heading if size>=24 and profile.data.lang=="en" else art.skin.body)
	label.add_theme_color_override("font_color",color)
	label.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size",0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(label)
	return label


func box(rect: Rect2,color: Color = Color("302239")):
	var panel = Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = art.skin.panel_style()
	panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)


func button(value: String,rect: Rect2,callback: Callable,primary: bool = false,disabled: bool = false) -> Button:
	var b = Button.new()
	b.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.add_theme_font_size_override("font_size",20 if rect.size.y>=38 else 16)
	b.add_theme_color_override("font_color",Color("46263e") if primary else JellyArt.CREAM)
	b.add_theme_color_override("font_hover_color",Color("46263e") if primary else Color("fff0d1"))
	b.add_theme_color_override("font_focus_color",Color("46263e") if primary else Color("fff0d1"))
	b.add_theme_color_override("font_pressed_color",Color("46263e") if primary else Color("fff0d1"))
	b.add_theme_font_override("font",art.skin.heading if profile.data.lang=="en" else art.skin.body)
	b.add_theme_color_override("font_disabled_color",Color("79647f"))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style = art.skin.button_style(state,primary)
		b.add_theme_stylebox_override(state,style)
	art.skin.add_button_fill(b,primary)
	b.pressed.connect(func():
		sound.play("click")
		callback.call())
	b.mouse_entered.connect(func(): sound.play("hover"))
	ui.add_child(b)
	return b


func focus_first():
	for child in ui.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			break


func stop_arena():
	Engine.time_scale=1.0
	Engine.physics_ticks_per_second=60
	if is_instance_valid(arena):
		remove_child(arena)
		arena.queue_free()
		arena = null


func show_settings(back: String):
	settings_return = back
	screen = "settings"
	clear_ui()
	box(Rect2(60,25,840,490),Color(.15,.10,.19,.98))
	label_at(tr2("НАСТРОЙКИ РЕЦЕПТА","RECIPE SETTINGS"),Rect2(90,40,760,40),28)
	button("RU / EN",Rect2(720,43,145,34),func(): profile.data.lang="en" if profile.data.lang=="ru" else "ru";profile.save();show_settings(back))
	var names = [tr2("Общая громкость","Master volume"),tr2("Музыка","Music"),tr2("Эффекты","Sound effects"),tr2("Тряска камеры","Camera shake")]
	var keys = ["master","music","sfx","shake"]
	for i in 4:
		label_at(names[i],Rect2(90,100+i*49,200,25),16)
		var slider = HSlider.new()
		slider.position = Vector2(300,104+i*49)
		slider.size = Vector2(215,22)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = profile.data[keys[i]]
		art.skin.style_slider(slider)
		slider.value_changed.connect(func(value): profile.data[keys[i]]=value;sound.update_volume();profile.save())
		ui.add_child(slider)
	var toggles = [["flashes",tr2("Вспышки","Flashes")],["assist",tr2("Защита от каждого 2-го удара","Block every second hit")],["aim_help",tr2("Помощь в прицеливании","Aim assistance")],["fullscreen",tr2("Полный экран","Fullscreen")],["vsync","VSync"]]
	for i in toggles.size():
		var key: String = toggles[i][0]
		button(toggles[i][1]+": "+("✓" if profile.data[key] else "—"),Rect2(555,100+i*42,310,34),func(): profile.data[key]=not profile.data[key];profile.save();apply_display();show_settings(back))
	button(tr2("Окно: ","Window: ")+["1440 × 810","1280 × 720","1920 × 1080"][profile.data.resolution],Rect2(90,307,425,36),func(): profile.data.resolution=(profile.data.resolution+1)%3;profile.save();apply_display();show_settings(back))
	label_at(tr2("ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ","KEY BINDINGS"),Rect2(90,359,500,25),13,Color("a7ddc9"))
	var actions = ["left","right","up","down","push","dash","sprint","pause"]
	var labels = ["←","→","↑","↓",tr2("Толчок","Push"),tr2("Рывок","Dash"),tr2("Бег","Sprint"),"Ⅱ"]
	for i in actions.size():
		var act: String = actions[i]
		button(labels[i],Rect2(90+i*97,391,89,33),func(): binding_wait=act;binding_label.text=tr2("Нажми новую клавишу. Esc — отмена.","Press a new key. Esc cancels."))
	binding_label = label_at(tr2("Мышь и геймпад остаются доступны при переназначении.","Mouse and controller remain available when rebinding."),Rect2(90,432,600,25),13,Color("bda6bb"))
	button(tr2("Сброс клавиш","Reset keys"),Rect2(90,470,220,32),func(): profile.data.bindings={};profile.save();setup_inputs();show_settings(back))
	button(tr2("Готово","Done"),Rect2(655,464,210,38),func():
		binding_wait=""
		if back=="pause": show_pause()
		else: show_menu(),true)
	focus_first()


func show_credits():
	stop_arena()
	screen = "credits"
	clear_ui()
	label_at("KELLY JELLY",Rect2(100,55,760,60),44,JellyArt.CREAM,true)
	label_at("G R O W   ·   R A M   ·   D E V O U R",Rect2(100,120,760,35),20,Color("f49ebd"),true)
	var body = tr2("Игра из одного задания\n\nИдея и продюсирование — автор челленджа\nДизайн, код, интерфейс и оригинальная музыка — Codex\nПерсонажи, мир и графика интерфейса — PixelLab\nДвижок — Godot Engine (MIT); шрифты — SIL OFL\n\nНикаких желешек при разработке не пострадало.\nОни просто стали немного шире.","A game from one brief\n\nIdea and production — the challenge creator\nDesign, code, interface & original music — Codex\nCharacters, scenery & UI artwork — PixelLab\nGodot Engine (MIT); Inter, Lilita One & Nunito fonts (SIL OFL)\n\nNo jellies were harmed in the making of this game.\nThey just got a little wider.")
	label_at(body,Rect2(90,180,780,260),18,Color("ccb6c8"),true)
	button(tr2("В меню","Main menu"),Rect2(355,460,250,44),show_menu,true)
	focus_first()


func _input(event):
	if binding_wait != "" and event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE:
			binding_wait=""
			return
		if speed_key(event.physical_keycode)!=0:
			binding_label.text=tr2("1 / 2 / 3 — скорость игры","1 / 2 / 3 control game speed")
			get_viewport().set_input_as_handled()
			return
		for action in ["left","right","up","down","push","dash","sprint","pause"]:
			if action==binding_wait: continue
			for binding in InputMap.action_get_events(action):
				if binding is InputEventKey and binding.physical_keycode==event.physical_keycode:
					binding_label.text=tr2("Клавиша занята: ","Key already bound: ")+action
					get_viewport().set_input_as_handled()
					return
		profile.data.bindings[binding_wait]=event.physical_keycode
		profile.save()
		setup_inputs()
		binding_wait=""
		binding_label.text=tr2("Сохранено","Saved")
		get_viewport().set_input_as_handled()
		return
	if handle_speed_key(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value)>.3):
		gamepad=true
		joy_device=event.device
	elif event is InputEventMouseMotion or event is InputEventKey: gamepad=false
	if is_instance_valid(arena):
		arena.gamepad=gamepad
		arena.joy_device=joy_device
	if event.is_action_pressed("pause"):
		if screen=="play": show_pause()
		elif screen=="pause": resume()
		elif screen=="settings":
			if settings_return=="pause": show_pause()
			else: show_menu()
		elif screen=="help" and settings_return=="pause": show_pause()
		elif screen in ["help","credits","records"]: show_menu()
		elif screen=="confirm": show_pause()
		get_viewport().set_input_as_handled()
	if screen=="play" and is_instance_valid(arena):
		if event.is_action_pressed("dash"): arena.begin_charge()
		if event.is_action_released("dash"): arena.release_dash()
		if event.is_action_pressed("push"): arena.push()
		if event is InputEventKey and event.pressed and event.keycode==KEY_F12: capture("manual")


func _notification(what):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen=="play" and not smoke and capture_mode=="": show_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()


func quit_game():
	if quitting: return
	quitting = true
	sound.shutdown()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()

