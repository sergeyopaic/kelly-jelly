class_name JellyArt
extends RefCounted

var textures = {}
var font: Font = ThemeDB.fallback_font
const INK = Color("302139")
const CREAM = Color("fff0c7")
const PINK = Color("f57eaa")
const MUTED = Color("aa8fa9")

func _init():
	for key in ["kelly","gummy","fork","waffle","pepper","toffee","pudding","rolling","whisk"]:
		var path = "res://assets/art/"+key+".png"
		if ResourceLoader.exists(path): textures[key] = load(path)

func panel(c: CanvasItem,rect: Rect2,color: Color,radius: int = 12,border: Color = Color.TRANSPARENT):
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border.a > 0:
		box.set_border_width_all(2)
		box.border_color = border
	c.draw_style_box(box,rect)

func text(c: CanvasItem,p: Vector2,value: String,size: int,color: Color = CREAM):
	c.draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(c: CanvasItem,p: Vector2,value: String,size: int,color: Color = CREAM):
	var width = font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(c,p-Vector2(width/2,0),value,size,color)

func shadow(c: CanvasItem,p: Vector2,size: Vector2):
	c.draw_set_transform(p,0,Vector2(1,0.35))
	c.draw_circle(Vector2.ZERO,size.x,Color(0.12,0.06,0.17,0.25))
	c.draw_set_transform(Vector2.ZERO)

func sprite(c: CanvasItem,key: String,p: Vector2,size: Vector2,rotation: float = 0.0,tint: Color = Color.WHITE):
	if not textures.has(key): return
	var native: Vector2 = textures[key].get_size()
	size = native*minf(size.x/native.x,size.y/native.y)
	c.draw_set_transform(p,rotation)
	c.draw_texture_rect(textures[key],Rect2(-size*Vector2(0.5,0.85),size),false,tint)
	c.draw_set_transform(Vector2.ZERO)

func sweet(c: CanvasItem,p: Vector2,kind: int = 0,scale: float = 1.0):
	c.draw_set_transform(p,0,Vector2.ONE*scale)
	var colors = [Color("f9b1cc"),Color("93ddc2"),Color("f5cf80")]
	var color: Color = colors[kind%3]
	if kind%3 == 0:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-12,-6),Vector2(-5,0),Vector2(-12,6)]),color.darkened(0.2))
		c.draw_colored_polygon(PackedVector2Array([Vector2(12,-6),Vector2(5,0),Vector2(12,6)]),color.darkened(0.2))
		c.draw_circle(Vector2.ZERO,7,INK)
		c.draw_circle(Vector2.ZERO,5,color)
	elif kind%3 == 1:
		panel(c,Rect2(-7,-7,14,14),INK,4)
		panel(c,Rect2(-5,-6,10,10),color,3)
	else:
		c.draw_circle(Vector2.ZERO,8,INK)
		c.draw_circle(Vector2.ZERO,6,color)
		c.draw_arc(Vector2.ZERO,3,0,PI*1.8,14,Color("c68c5f"),2)
	c.draw_circle(Vector2(-2,-3),2,CREAM)
	c.draw_set_transform(Vector2.ZERO)

func star(c: CanvasItem,p: Vector2,r: float,color: Color):
	var pts = PackedVector2Array()
	for i in 10:
		pts.append(p+Vector2.from_angle(-PI/2+i*PI/5)*(r if i%2==0 else r*.45))
	c.draw_colored_polygon(pts,color)

func kelly(c: CanvasItem,p: Vector2,size: float,time: float,state: String = "idle",direction: Vector2 = Vector2.RIGHT,skin: int = 0):
	var wobble = sin(time*6)*0.04
	var stretch = Vector2(1+wobble,1-wobble)
	var rotation = sin(time*3)*0.025
	if state == "charge": stretch = Vector2(1.20,0.73); rotation = sin(time*55)*0.035
	if state == "dash": stretch = Vector2(1.28,0.72); rotation = direction.angle()+PI/2
	if state == "hurt": stretch = Vector2(1.2,0.8)
	if state == "absorb": stretch = Vector2(1.1,1.1)
	if state == "victory":
		p.y -= absf(sin(time*5))*size*0.15
		rotation = sin(time*5)*0.13
	if state == "dead": stretch = Vector2(1.35,0.35)
	shadow(c,p+Vector2(0,3),Vector2(size*.4,size*.1))
	var tint = [Color.WHITE,Color("b8ffd1"),Color("bfb8ff"),Color("ffe2a0")][skin]
	sprite(c,"kelly",p,Vector2(size,size)*stretch,rotation,tint)
	if skin == 3:
		for i in 5:
			star(c,p+Vector2(sin(i*4.3)*size*.32,-size*.5+cos(i*2.8)*size*.2),2.5,CREAM)

func backdrop(c: CanvasItem,time: float):
	c.draw_rect(Rect2(0,0,960,540),Color("211a2b"))
	for x in range(0,1000,60):
		for y in range(0,600,60):
			c.draw_circle(Vector2(x+30,y+30),1.5,Color("403047"))
	for i in 24:
		var p = Vector2(fmod(i*157.3+18,960),fmod(i*89.1+time*(4+i%3),580)-20)
		c.draw_line(p,p+Vector2(5,2).rotated(i),Color("73516c"),2)

func draw_menu(c: CanvasItem,time: float,skin: int):
	backdrop(c,time)
	# A large illustrated dessert plate gives the menu a distinctive visual focal point.
	c.draw_set_transform(Vector2(716,340),0,Vector2(1,0.43))
	c.draw_circle(Vector2(0,20),202,Color("161321"))
	c.draw_circle(Vector2.ZERO,202,Color("806071"))
	c.draw_circle(Vector2.ZERO,192,Color("f2dac4"))
	c.draw_circle(Vector2.ZERO,174,Color("b598a5"))
	c.draw_circle(Vector2.ZERO,165,Color("eed5c8"))
	c.draw_circle(Vector2.ZERO,145,Color("e2bac1"))
	c.draw_set_transform(Vector2.ZERO)
	for i in 9:
		var angle = i*TAU/9+time*.04
		sweet(c,Vector2(716,340)+Vector2(cos(angle)*160,sin(angle)*65),i,1.2)
	kelly(c,Vector2(716,328),220,time,"victory",Vector2.RIGHT,skin)
	for i in 5: star(c,Vector2(570+i*72,130+sin(time*2+i)*18),5+i%3,Color("eecb8b"))
	text(c,Vector2(54,60),"A LITTLE JELLY. A BIG ATTITUDE.",13,Color("d6aa9c"))
	text(c,Vector2(49,140),"KELLY",76,Color("1b1423"))
	text(c,Vector2(46,134),"KELLY",76,CREAM)
	text(c,Vector2(49,215),"JELLY",84,Color("9c426e"))
	text(c,Vector2(46,209),"JELLY",84,PINK)
	text(c,Vector2(50,244),"S W E E T   R I C O C H E T",17,Color("a7ddc9"))
	panel(c,Rect2(645,425,146,29),Color("38283f"),14,Color("6b4d65"))
	centered(c,Vector2(718,445),"100% GOOD WOBBLES",11,Color("efcba1"))

func draw_arena(a):
	var theme_id: int = GameData.LEVELS[a.level].theme
	var floor_colors = [Color("624655"),Color("685444"),Color("3e5a61")]
	var floor_color: Color = floor_colors[theme_id]
	a.draw_rect(Rect2(0,0,960,540),Color("241c2e"))
	panel(a,Rect2(40,102,880,394),Color("151320"),25)
	panel(a,Rect2(44,90,872,396),floor_color.lightened(.18),25)
	panel(a,Rect2(54,100,852,380),floor_color.darkened(.25),21)
	panel(a,Rect2(62,112,836,366),floor_color,16)
	for row in 8:
		for col in 17:
			var p = Vector2(66+col*49,116+row*45)
			var color = floor_color.lightened(0.035 if (row+col)%2 == 0 else 0.0)
			panel(a,Rect2(p,Vector2(46,42)),color,3)
	# Tiny sugar grains and inlaid decorations use deterministic positions.
	for i in 75:
		var p = Vector2(80+fmod(i*127.7,794),125+fmod(i*71.3,330))
		a.draw_line(p,p+Vector2(3,1),floor_color.lightened(.13),1)
	if theme_id == 2:
		for y in [230,390]:
			panel(a,Rect2(80,y-18,800,36),Color(0.55,0.83,0.89,.15),12)
			for x in range(100,850,60): a.draw_line(Vector2(x,y-10),Vector2(x+20,y+7),Color(.7,.9,1,.20),2)
	for p in a.puddles:
		a.draw_set_transform(p.p,0,Vector2(1,.55))
		a.draw_circle(Vector2.ZERO,29,Color(.9,.56,.27,minf(.5,p.life*.4)))
		a.draw_arc(Vector2.ZERO,22,0,TAU,24,Color("e0b276"),1)
		a.draw_set_transform(Vector2.ZERO)
	# Decorative piping around the board, outside the collision area.
	for i in 28:
		var x = 62+i*31
		a.draw_circle(Vector2(x,100),5,floor_color.lightened(.32))
	for b in a.bumpers:
		shadow(a,b+Vector2(0,9),Vector2(27,8))
		a.draw_circle(b,24,Color("392a3a"))
		a.draw_circle(b-Vector2(0,5),22,Color("edb0ba") if theme_id==0 else (Color("d9b27c") if theme_id==1 else Color("9bcecf")))
		a.draw_arc(b-Vector2(0,5),16,0,TAU,32,CREAM,3)
		a.draw_arc(b-Vector2(0,5),10,a.clock*.5,a.clock*.5+PI*1.6,24,Color("ae748b"),3)
		star(a,b-Vector2(0,5),5,CREAM)
	for item in a.items:
		var p: Vector2 = item.p+Vector2(0,sin(a.clock*5+item.age)*2)
		if item.heal:
			panel(a,Rect2(p-Vector2(9,8),Vector2(18,16)),Color("fff0c7"),5)
			a.draw_line(p-Vector2(5,0),p+Vector2(5,0),PINK,4)
			a.draw_line(p-Vector2(0,5),p+Vector2(0,5),PINK,4)
		elif item.life < 10:
			a.draw_circle(p,5,Color("f57eaa"))
			a.draw_circle(p-Vector2(1,2),2,Color("ffd3e0"))
		else: sweet(a,p,item.style)
	for e in a.enemies:
		if e.state == "telegraph":
			var end: Vector2 = e.pos+e.face*(780 if e.kind==6 else (400 if e.kind>=5 else 160))
			a.draw_line(e.pos,end,Color(.95,.48,.52,.18),e.radius*1.6)
			a.draw_dashed_line(e.pos,end,Color("ffbdac"),2,9)
			centered(a,e.pos-Vector2(0,e.radius*2+10),"!",24,CREAM)
		if e.state == "spawn":
			a.draw_arc(e.pos,e.radius+10+sin(a.clock*8)*3,0,TAU,32,Color("efbea5"),2)
			star(a,e.pos,7,CREAM)
	var sorted: Array = a.enemies.duplicate()
	sorted.sort_custom(func(x,y): return x.pos.y<y.pos.y)
	var player_drawn = false
	for e in sorted:
		if not player_drawn and e.pos.y > a.player.y:
			draw_player(a)
			player_drawn = true
		draw_enemy(a,e)
	if not player_drawn: draw_player(a)
	for b in a.bullets:
		a.draw_circle(b.p+Vector2(0,2),6,INK)
		a.draw_circle(b.p,5,Color("a8f1cf") if b.friendly else Color("ffb393"))
		a.draw_circle(b.p-Vector2(1,2),2,CREAM)
	for p in a.particles:
		var color: Color = p.c
		color.a = minf(1,p.life*3)
		a.draw_rect(Rect2(p.p,Vector2.ONE*p.r),color)
	if a.get_parent().screen == "play": draw_hints(a)

func draw_hints(a):
	if a.chain>1: centered(a,Vector2(785,66),"×"+str(mini(4,a.chain))+"  "+a.trx("ЦЕПОЧКА","CHAIN"),19,Color("e5c58a"))
	var hint = a.trx("WASD  ходьба     ЛКМ  заряд → рывок     ПКМ / Пробел  толчок", "WASD  move     LMB  charge → dash     RMB / Space  push")
	if a.gamepad: hint = a.trx("L  ходьба     R  прицел     RT  заряд → рывок     A  толчок", "L  move     R  aim     RT  charge → dash     A  push")
	if a.tutorial>=0:
		var ru = ["Подвигайся: WASD или стрелки","Подбери сладость — Келли станет больше","Зажми ЛКМ, прицелься и отпусти! Стены отражают рывок.","ПКМ / Пробел: бесплатный толчок. Оглушённых съешь!"]
		var en = ["Move around with WASD or arrows","Pick up a sweet — Kelly will grow","Hold LMB, aim, release! Walls reflect your dash.","RMB / Space: free push. Absorb stunned foes!"]
		hint = (ru if a.profile.data.lang=="ru" else en)[a.tutorial]
	text(a,Vector2(50,519),hint,14,Color("cdb7c9"))
	if a.profile.data.assist: text(a,Vector2(765,86),a.trx("ПОМОЩЬ ВКЛ.","ASSIST ON"),11,Color("a7ddc9"))

func draw_player(a):
	var state = "idle"
	if a.charging: state = "charge"
	elif a.dash_left > 0: state = "dash"
	elif a.hit_flash > 0: state = "hurt"
	elif a.absorb_visual > 0: state = "absorb"
	if a.ended: state = "dead" if a.hp<=0 else "victory"
	var size = 40+GameData.radius(a.mass)*1.15
	if a.invincible <= 0 or int(a.clock*18)%2 == 0: kelly(a,a.player,size,a.clock,state,a.aim,a.profile.data.skin)
	if a.shield: a.draw_arc(a.player-Vector2(0,14),size*.5,0,TAU,32,Color(.9,.83,.5,.7),2)
	if a.active and not a.ended:
		var tip: Vector2 = a.player+a.aim*40
		a.draw_colored_polygon(PackedVector2Array([tip+a.aim*8,tip-a.aim*3+a.aim.orthogonal()*4,tip-a.aim*3-a.aim.orthogonal()*4]),Color("fff0c7"))
	if a.charging:
		var distance = 150+200*a.charge/0.8
		var segment: Dictionary = a.preview_segment(a.player,a.aim,distance,GameData.radius(a.mass))
		a.draw_dashed_line(a.player+a.aim*25,segment.point,Color(1,.94,.78,.7),2,8)
		if segment.normal != Vector2.ZERO:
			var reflected: Vector2 = a.aim.bounce(segment.normal)
			var second: Dictionary = a.preview_segment(segment.point+reflected*.1,reflected,maxf(50,distance-segment.distance),GameData.radius(a.mass))
			a.draw_dashed_line(segment.point,second.point,Color(1,.94,.78,.4),2,8)
			a.draw_circle(segment.point,4,CREAM)
		a.draw_arc(a.player,30,-PI/2,-PI/2+TAU*a.charge/.8,40,CREAM,3)
	if a.push_visual > 0:
		a.draw_arc(a.player,48,a.aim.angle()-.85,a.aim.angle()+.85,20,Color(1,.9,.8,a.push_visual*5),6)

func draw_enemy(a,e: JellyEnemy):
	if e.state == "spawn": return
	var key = ["gummy","fork","waffle","pepper","toffee","pudding","rolling","whisk"][e.kind]
	var size = Vector2.ONE*(88 if e.kind>=5 else 45)
	if e.kind == 6: size = Vector2(112,75)
	var wobble = sin(e.clock*7)*0.04
	size *= Vector2(1+wobble,1-wobble)
	var rotation = sin(e.clock*4)*0.04
	var p = e.pos
	if e.state == "telegraph":
		size *= Vector2(1.12,.85)
		rotation = sin(e.clock*40)*.04
	if e.state == "attack":
		rotation = sin(e.clock*20)*.13
		p.y -= 4
	if e.launched > 0: rotation = e.clock*15
	if e.state == "rest" and e.kind>=5:
		for i in 3: star(a,p+Vector2(cos(e.clock*3+i*TAU/3)*30,-75+sin(e.clock*3+i*TAU/3)*6),4,CREAM)
	if e.state == "stunned":
		size *= Vector2(1.1,.5)
		star(a,p-Vector2(0,32),5,CREAM)
	if e.state == "defeated":
		rotation = (1.7-e.timer)*4
		size *= maxf(.15,e.timer/1.7)
	shadow(a,p+Vector2(0,5),Vector2(e.radius,8))
	sprite(a,key,p,size,rotation,Color(2,2,2) if e.flash>0 and a.profile.data.flashes else Color.WHITE)
	if e.kind == 2 and e.state not in ["stunned","defeated"]:
		a.draw_arc(p,23,e.face.angle()-.87,e.face.angle()+.87,16,Color("ffdf98"),4)
	if e.hp < e.max_hp and e.hp > 0:
		panel(a,Rect2(p-Vector2(18,size.y+3),Vector2(36,4)),INK,2)
		panel(a,Rect2(p-Vector2(18,size.y+3),Vector2(36*float(e.hp)/e.max_hp,4)),PINK,2)
