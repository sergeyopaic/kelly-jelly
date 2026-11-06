class_name RunArt
extends JellyArt

var skin=VisualSkin.new()
var ground:Texture2D
var emotions:KellyEmotions

# Visible body bounds exclude feet, wrappers, handles and crowns. Equal mass
# yields equal body-box area; appendages no longer make a heavy body look tiny.
const BODY_BOUNDS={
	"gummy":Rect2(1,10,31,27),"fork":Rect2(1,1,22,29),
	"waffle":Rect2(1,2,33,35),"pepper":Rect2(1,8,31,27),
	"toffee":Rect2(10,1,27,27),"pudding":Rect2(5,23,58,49),
	"rolling":Rect2(21,5,61,36),"whisk":Rect2(8,40,35,33)}

func enemy_rect(key:String,radius:float) -> Rect2:
	var body:Rect2=BODY_BOUNDS[key]
	var scale=radius*2.65/sqrt(body.size.x*body.size.y)
	var origin=Vector2(-body.get_center().x,-body.end.y)*scale+Vector2(0,radius*.4)
	return Rect2(origin,textures[key].get_size()*scale)

func draw_candy_petal(c:CanvasItem,point:Vector2,size:float,angle:float):
	var points=PackedVector2Array()
	for v in [Vector2(-1,0),Vector2(-.25,-.6),Vector2(.65,-.38),Vector2(1.3,0),Vector2(.2,.65)]:
		points.append(point+v.rotated(angle)*size)
	c.draw_colored_polygon(points,Color("e58638"))
	var inner=PackedVector2Array()
	for v in points: inner.append(point+(v-point)*.72)
	c.draw_colored_polygon(inner,Color("ffd58a"))
	c.draw_line(points[0],points[1],Color("fff1ce"),maxf(1,size*.15),true)

func draw_orbit_badge(c:CanvasItem,center:Vector2,radius:float,count:int=3):
	c.draw_arc(center,radius,0,TAU,48,Color("9b684f"),1.5,true)
	c.draw_circle(center,radius*.34,Color("ee9cbb"))
	for i in count:
		var angle=-PI/2+i*TAU/count
		draw_candy_petal(c,center+Vector2.from_angle(angle)*radius,radius*.28,angle+PI/2)

func enemy_sprite(c:CanvasItem,key:String,point:Vector2,radius:float,deformation:Vector2,angle:float,tint:Color):
	c.draw_set_transform(point,angle,deformation)
	c.draw_texture_rect(textures[key],enemy_rect(key,radius),false,tint)
	c.draw_set_transform(Vector2.ZERO)

func warning_lane(c:CanvasItem,start:Vector2,direction:Vector2,length:float,radius:float,progress:float,volley:bool):
	c.draw_set_transform(start,direction.angle())
	var lane=StyleBoxFlat.new()
	lane.bg_color=Color(1,.42,.35,.08 if volley else .13)
	lane.border_color=Color(1,.68,.47,.28+progress*.24)
	lane.set_border_width_all(1);lane.set_corner_radius_all(int(radius))
	c.draw_style_box(lane,Rect2(-radius,-radius,length+radius*2,radius*2))
	var fill=StyleBoxFlat.new()
	fill.bg_color=Color(1,.63,.42,.10+progress*.08)
	fill.set_corner_radius_all(int(radius))
	c.draw_style_box(fill,Rect2(-radius,-radius,(length+radius*2)*progress,radius*2))
	if not volley:
		var tip=Vector2(length,0);var arrow=minf(radius*.5,10)
		c.draw_polyline(PackedVector2Array([tip+Vector2(-arrow,-arrow),tip,tip+Vector2(-arrow,arrow)]),Color(1,.83,.65,.55+progress*.3),2,true)
	c.draw_set_transform(Vector2.ZERO)

func draw_warning(a,e):
	if e.fires_volley(): return
	var progress=clampf(1-e.timer/e.warning_duration(),0,1)
	var point=a.to_screen(e.pos)
	var scale=RunRules.motion_scale(e.mass)*a.zoom
	warning_lane(a,point,e.face,e.attack_speed()*e.attack_duration()*scale,e.radius*a.zoom,progress,false)

func _init():
	super()
	font=skin.body
	ground=load("res://assets/emotions/ground.png")
	emotions=KellyEmotions.new()

func draw_menu(c:CanvasItem,time:float,skin:int):
	c.draw_texture_rect(self.skin.menu,Rect2(0,0,960,540),false)
	for i in 28:
		var alpha=.86*(1.0-float(i)/28.0)
		c.draw_rect(Rect2(i*22,0,23,540),Color(.10,.055,.13,alpha))
	c.draw_rect(Rect2(0,492,960,48),Color(.08,.04,.11,.48))
	for i in 18:
		var point=Vector2(fmod(i*131.7+30,960),fmod(i*71.9+sin(time+i)*5,500))
		star(c,point,1.5+sin(time*1.2+i),Color(1,.85,.62,.55))
	text(c,Vector2(50,62),"A LITTLE JELLY. A BIG APPETITE.",13,Color("f3c699"))
	c.draw_string(self.skin.heading,Vector2(50,141),"KELLY",HORIZONTAL_ALIGNMENT_LEFT,-1,78,Color("421a35"))
	c.draw_string(self.skin.heading,Vector2(47,135),"KELLY",HORIZONTAL_ALIGNMENT_LEFT,-1,78,Color("fff0c7"))
	c.draw_string(self.skin.heading,Vector2(51,215),"JELLY",HORIZONTAL_ALIGNMENT_LEFT,-1,88,Color("812b59"))
	c.draw_string(self.skin.heading,Vector2(47,209),"JELLY",HORIZONTAL_ALIGNMENT_LEFT,-1,88,Color("f79dbc"))
	text(c,Vector2(51,244),"G R O W   ·   R A M   ·   D E V O U R",15,Color("b8e3cd"))
	shadow(c,Vector2(719,410),Vector2(112,20))
	var clip="absorb" if fmod(time,5)<.9 else "idle"
	var progress=fmod(time,.9)/.9 if clip=="absorb" else fmod(time*.6,1.0)
	var texture=emotions.frame_for(clip,progress)
	var dimensions=texture.get_size()*200/34.0
	var pose={"texture":texture,"rect":Rect2(Vector2(-dimensions.x*.5,30-dimensions.y),dimensions),"tilt":sin(time*2)*.025}
	emotions.draw(c,Vector2(715,402),pose,[Color.WHITE,Color("b8ffd1"),Color("bfb8ff"),Color("ffe2a0")][skin])

func backdrop(c:CanvasItem,time:float):
	c.draw_texture_rect(skin.menu,Rect2(0,0,960,540),false,Color(.45,.39,.50))
	c.draw_rect(Rect2(0,0,960,540),Color(.10,.06,.14,.45))

func draw_terrain(a):
	# A continuous matte surface. Mirrored neighbours share identical edge pixels.
	var palette=[Color("f1c3db"),Color("9be4c9"),Color("ffda9b"),Color("c8b3f1")]
	var phase=clampf(a.terrain_stage,0,3)
	var theme=int(phase)
	var tint:Color=palette[theme].lerp(palette[mini(theme+1,3)],smoothstep(0,1,fmod(phase,1.0)))
	var spacing=192.0
	while spacing*a.zoom<72: spacing*=2
	var world_offset=a.origin_sectors*4096
	var start=((a.to_world(Vector2.ZERO)+world_offset)/spacing).floor()
	for y in range(-1,int(540/(spacing*a.zoom))+2):
		for x in range(-1,int(960/(spacing*a.zoom))+2):
			var cell=start+Vector2(x,y)
			var p=a.to_screen(cell*spacing-world_offset).floor()
			var end=a.to_screen((cell+Vector2.ONE)*spacing-world_offset).ceil()
			var dimensions=end-p
			var flip=Vector2(-1 if posmod(int(cell.x),2)==1 else 1,-1 if posmod(int(cell.y),2)==1 else 1)
			a.draw_set_transform((p+end)*.5,0,flip)
			a.draw_texture_rect(ground,Rect2(-dimensions*.5,dimensions),false,tint)
			a.draw_set_transform(Vector2.ZERO)
	# Flat, low-contrast crumbs and impressed wafer patterns are part of the floor.
	# No standing props, cast shadows, collectible silhouettes or sparkle effects.
	var step=spacing*.9
	var first=((a.to_world(Vector2.ZERO)+world_offset)/step).floor()
	for y in range(-1,int(540/(step*a.zoom))+2):
		for x in range(-1,int(960/(step*a.zoom))+2):
			var cell=first+Vector2(x,y)
			var code=absi((int(cell.x)*73856093)^(int(cell.y)*19349663)^a.run_seed)
			if code%4==0: continue
			var p=a.to_screen((cell+Vector2(.2+float(code%53)/100,.2+float(code%47)/100))*step-world_offset)
			var scale=clampf(spacing*a.zoom/192,.4,1.0)
			var muted=Color(tint,.075)
			# Wide, matte icing impressions: fixed to the floor, never pickup-sized.
			if phase>0 and code%3==1:
				var ornament=Color(tint,.035*minf(phase,1))
				for ribbon in 2:
					var center=p+Vector2(ribbon*28-14,6)*scale
					a.draw_arc(center,(28+ribbon*12)*scale,.15+code%6,PI*1.4+code%6,24,ornament,2*scale,true)
			if phase>1 and code%5==2:
				var accent=Color(tint,.035*minf(phase-1,1))
				for line in 3:
					var offset=Vector2(0,line*7)*scale
					a.draw_line(p+offset-Vector2(32,8)*scale,p+offset+Vector2(32,8)*scale,accent,2*scale,true)
			if phase>2 and code%4==2:
				var flourish=Color(tint,.045*minf(phase-2,1))
				a.draw_arc(p,52*scale,.2,2.5,32,flourish,3*scale,true)
				a.draw_arc(p+Vector2(30,20)*scale,36*scale,3.4,5.7,24,flourish,2*scale,true)
			if code%3==0:
				# Broken, shallow crosshatching pressed into the dough.
				for i in 4:
					var v=Vector2(i*6-9,0)*scale
					a.draw_line(p+v+Vector2(-8,-6)*scale,p+v+Vector2(8,6)*scale,muted,1)
					a.draw_line(p+v+Vector2(-8,6)*scale,p+v+Vector2(8,-6)*scale,muted,1)
			else:
				for i in 7:
					var offset=Vector2(sin(code+i*3.7)*22,cos(code+i*2.3)*12)*scale
					var length=Vector2(3+i%3,1 if i%2==0 else -2)*scale
					a.draw_line(p+offset,p+offset+length,muted,1.5*scale)

func draw_run(a):
	draw_terrain(a)
	for e in a.enemies:
		if e.state=="telegraph" and not e.dead: draw_warning(a,e)
	for puddle in a.puddles:
		var p=a.to_screen(puddle.p)
		a.draw_circle(p,puddle.r*a.zoom,Color(.9,.6,.28,.20))
		a.draw_arc(p,puddle.r*a.zoom,0,TAU,24,Color(.9,.6,.28,.5),2)
	for item in a.items:
		var p=a.to_screen(item.p)
		if not Rect2(-20,-20,1000,580).has_point(p): continue
		p.y+=sin(a.clock*5+item.age)*2
		if item.type=="xp":
			var big=1.4 if item.value>=20 else 1.0
			a.draw_texture_rect(skin.icons[13],Rect2(p-Vector2.ONE*9*big,Vector2.ONE*18*big),false)
		else:
			a.draw_circle(p,14,Color(.96,.40,.55,.16))
			a.draw_texture_rect(skin.icons[14],Rect2(p-Vector2.ONE*12,Vector2.ONE*24),false)
	var sorted:Array=a.enemies.duplicate()
	sorted.sort_custom(func(x,y): return x.pos.y<y.pos.y)
	var player_drawn=false
	for e in sorted:
		var p=a.to_screen(e.pos)
		var r=e.radius*a.zoom
		if not Rect2(-r*3,-r*3,960+r*6,540+r*6).has_point(p): continue
		if not player_drawn and e.pos.y>a.player.y: draw_hero(a);player_drawn=true
		if e.state=="spawn":
			a.draw_arc(p,r+8,0,TAU,24,Color("efb89a"),2)
			star(a,p,5,CREAM)
			continue
		var info=a.hit_info(e,1100*(1+.12*a.rank(1)))
		var tint=Color("9ce5bd") if info.success else Color("ed9a8e")
		if info.success and info.damage<e.hp: tint=Color("edc27f")
		a.draw_arc(p,r+3,0,TAU,24,Color(tint,.45),1.5)
		var key=["gummy","fork","waffle","pepper","toffee","pudding","rolling","whisk"][e.kind]
		var size=Vector2.ONE
		var angle=sin(e.clock*5)*.04
		if e.stun>0: angle=sin(e.clock*18)*.06*minf(1,e.stun/.4)
		if e.flash>0:
			var recoil=e.flash/.12
			var direction=e.hit_direction.abs()
			size*=Vector2(1-.18*recoil*direction.x+.1*recoil*direction.y,1-.18*recoil*direction.y+.1*recoil*direction.x)
			angle-=e.hit_direction.x*.09*recoil
		if e.state=="telegraph": size*=Vector2(1.1,.85)
		shadow(a,p,Vector2(r,0))
		var brightness=1+.35*e.flash/.12 if a.profile.data.flashes else 1.0
		enemy_sprite(a,key,p,r,size,angle,Color(brightness,brightness,brightness))
		if e.kind==2 and e.state in ["guard_windup","guard"] and e.stun<=0:
			var opacity=1.0 if e.state=="guard" else clampf(1-e.timer/.45,.12,1)*.55
			var center=p-Vector2(0,r*.5)
			var start=e.face.angle()-PI/3
			var finish=e.face.angle()+PI/3
			a.draw_arc(center,r*1.6,start,finish,32,Color(.23,.17,.29,opacity),8,true)
			a.draw_arc(center,r*1.6,start,finish,32,Color(.98,.77,.43,opacity),4,true)
			a.draw_arc(center,r*1.45,start,finish,32,Color(1,.93,.71,opacity*.6),1.5,true)
		if e.armored():
			a.draw_arc(p-Vector2(0,r),r*1.4,-PI,0,24,Color("b6a6e1"),3)
			centered(a,p-Vector2(0,r*2.6),a.trx("БРОНЯ","ARMOR"),12,Color("cabbef"))
		elif e.kind>=5 and e.state=="rest":
			centered(a,p-Vector2(0,r*2.6),a.trx("БЕЙ!","RAM!"),15,Color("9fe4c0"))
			for i in 3: star(a,p+Vector2(cos(e.clock*4+i*2)*r,-r*2.2),4,CREAM)
		if e.hp<e.max_hp:
			var width=clampf(r*2,24,130)
			JellyMeter.paint(a,Rect2(p+Vector2(-width*.5,r+9),Vector2(width,4)),e.hp,e.max_hp,tint)
		if e.mass>a.mass*2 or e.kind>=5:
			centered(a,p+Vector2(0,r+30),RunRules.amount(e.mass)+a.trx(" м"," m"),12,tint)
	if not player_drawn: draw_hero(a)
	for b in a.bullets:
		var p=a.to_screen(b.p)
		a.draw_circle(p,maxf(4,b.r*a.zoom),Color("ffbd90"))
		a.draw_circle(p-Vector2(1,1),2,CREAM)
	for prey in a.attack_pending:
		var p=a.to_screen(prey.pos).lerp(a.to_screen(a.player),.6)
		a.draw_circle(p,5,Color("f48bb4"))
	draw_impacts(a)
	for p in a.particles:
		a.draw_rect(Rect2(a.to_screen(p.p),Vector2.ONE*3),Color(p.c,minf(1,p.life*3)))
	for l in a.labels:
		centered(a,a.to_screen(l.p)-Vector2(0,34),l.text,14,Color(l.c,minf(1,l.life*3)))

func draw_impacts(a):
	for effect in a.impacts:
		var progress=1-effect.life/effect.duration
		var p=a.to_screen(effect.p)
		var radius=clampf(effect.radius*a.zoom*.8,12,42)*(0.3+progress)
		var color=Color("ffd5a5") if effect.kind=="hit" else (Color("b7b4e5") if effect.kind=="armor" else Color("e68fa8"))
		color.a=(1-progress)*(.8 if a.profile.data.flashes else .35)
		a.draw_set_transform(p,0,Vector2(1,.7))
		a.draw_arc(Vector2.ZERO,radius,0,TAU,40,color,1.5,true)
		a.draw_set_transform(Vector2.ZERO)
		if effect.kind=="hit":
			for i in 5:
				var direction=effect.direction.rotated((i-2)*.55)
				var start=p+direction*radius*.65
				a.draw_line(start,start+direction*(5+effect.strength*3)*(1-progress),color,2,true)

func draw_melting_hero(a):
	var p=a.to_screen(a.player)
	var r=a.body_radius()*a.zoom
	var pose=emotions.death_pose(a)
	var melt:float=pose.melt
	var color:Color=[Color("ef84ad"),Color("8dd6ae"),Color("a596e0"),Color("e9bd78")][a.profile.data.skin]
	var width=r*lerpf(.55,1.65,melt)
	var height=r*lerpf(.10,.24,melt)
	var baseline=p+Vector2(0,r*.30)
	shadow(a,baseline+Vector2(0,2),Vector2(width,height*.65))
	var points=PackedVector2Array()
	for i in 48:
		var angle=i*TAU/48
		var wobble=1+.045*sin(angle*5+a.death_progress()*4)
		points.append(baseline+Vector2(cos(angle)*width,sin(angle)*height)*wobble)
	a.draw_colored_polygon(points,color.darkened(.20))
	var inner=PackedVector2Array()
	for v in points: inner.append(baseline+(v-baseline)*Vector2(.95,.78)-Vector2(0,height*.14))
	a.draw_colored_polygon(inner,color)
	a.draw_line(baseline+Vector2(-width*.45,-height*.40),baseline+Vector2(-width*.10,-height*.58),Color(1,.87,.92,.30*melt),maxf(1,r*.06),true)
	# The recognizable hurt face sinks into a puddle; no blink or violent burst.
	if pose.alpha>0:
		var tint:Color=[Color.WHITE,Color("b8ffd1"),Color("bfb8ff"),Color("ffe2a0")][a.profile.data.skin]
		tint.a=pose.alpha
		emotions.draw(a,p,pose,tint)
	if melt>.85:
		var alpha=smoothstep(.85,1,melt)*.65
		for side in [-1,1]:
			var eye=baseline+Vector2(side*width*.22,-height*.1)
			a.draw_line(eye-Vector2(r*.09,0),eye+Vector2(r*.09,r*.025),Color(.30,.12,.24,alpha),maxf(1,r*.04),true)

func draw_hero(a):
	if a.ended and a.hp<=0:
		draw_melting_hero(a)
		return
	var p=a.to_screen(a.player)
	var r=a.body_radius()*a.zoom
	var pose=emotions.pose(a)
	var center=p+pose.center
	var ring_radius:float=pose.ring_radius
	shadow(a,p,Vector2(r*1.05,r*.2))
	if a.level_up_left>0:
		var progress=1-a.level_up_left/a.LEVEL_UP_SECONDS
		var fade=sin(progress*PI)
		var strength=1.0 if a.profile.data.flashes else .45
		var burst_radius=r*(1.1+progress*1.8)
		a.draw_arc(center,burst_radius,0,TAU,64,Color(.75,.96,.84,fade*.7*strength),2,true)
		for i in 8:
			var direction=Vector2.from_angle(i*TAU/8-.15)
			star(a,center+direction*burst_radius,3+2*fade,Color(1,.88,.57,fade*strength))
		centered(a,center-Vector2(0,r*2.0+8+progress*8),a.trx("НОВЫЙ УРОВЕНЬ!","LEVEL UP!"),16,Color(.95,1,.83,clampf(fade*2,0,1)))
	if a.charging:
		var progress=clampf(a.charge/.8,0,1)
		a.draw_arc(center,ring_radius,0,TAU,96,Color(.19,.12,.23,.65),3,true)
		a.draw_arc(center,ring_radius,-PI/2,-PI/2+TAU*progress,96,Color("f2bad1"),2,true)
	elif a.dash_cooldown>0 and a.dash_left<=0:
		var recovery=1-clampf(a.dash_cooldown/maxf(.18,.65*pow(.88,a.rank(2))),0,1)
		a.draw_arc(center,ring_radius,-PI/2,-PI/2+TAU*recovery,64,Color(.95,.77,.86,.32),1.5,true)
	if a.shield: a.draw_arc(center,ring_radius+5,0,TAU,64,Color("f8d996"),2)
	var tint:Color=[Color.WHITE,Color("b8ffd1"),Color("bfb8ff"),Color("ffe2a0")][a.profile.data.skin]
	# Keep the expression readable during hit feedback instead of hiding the whole face.
	if a.invincible>0 and a.level_up_left<=0: tint.a=.6 if int(a.clock*12)%2==0 else 1.0
	emotions.draw(a,p,pose,tint)
	if a.orbit_rank>0 and a.dash_left>0:
		for i in a.orbit_count():
			var angle=a.orbit_angle+i*TAU/a.orbit_count()
			var point=a.to_screen(a.orbit_point(i,a.player,a.orbit_angle))+pose.center
			var size=a.body_radius()*a.zoom*.38
			for j in 4:
				var trail=a.to_screen(a.player+Vector2.from_angle(angle-j*.10)*a.orbit_radius())+pose.center
				a.draw_circle(trail,size*(1-j*.18),Color(1,.65,.3,.20-j*.04))
			draw_candy_petal(a,point,size,angle+PI/2)
	if a.dash_left<=0 and not a.charging and (a.sprinting or a.stamina<a.stamina_capacity()-.01):
		var width=clampf(r*2,34,64)
		var location=p+Vector2(-width*.5,r*.45+7)
		var color=Color("a4e5c5") if a.sprint_rearmed else Color("ab91a6")
		JellyMeter.paint(a,Rect2(location,Vector2(width,3)),a.stamina,a.stamina_capacity(),color)
		var bolt=location+Vector2(-7,1)
		a.draw_colored_polygon(PackedVector2Array([bolt+Vector2(1,-5),bolt+Vector2(-3,1),bolt,bolt+Vector2(-1,5),bolt+Vector2(3,-1),bolt+Vector2(0,-1)]),color)
	if a.active and a.charging:
		# Direction is shown only while preparing an attack, with no screen-spanning guide.
		var tip=center+a.aim*(ring_radius+17)
		var side=a.aim.orthogonal()
		var points=PackedVector2Array([tip-a.aim*5-side*4,tip,tip-a.aim*5+side*4])
		a.draw_polyline(points,Color("f8dbe7"),2.5,true)
	if a.push_visual>0:
		a.draw_arc(center,ring_radius+10,a.aim.angle()-.8,a.aim.angle()+.8,32,Color(1,.94,.78,a.push_visual*5),4)
