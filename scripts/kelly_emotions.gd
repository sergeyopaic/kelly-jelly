class_name KellyEmotions
extends RefCounted

var clips:Dictionary={}
var state="idle"
var state_started=0.0
var last_hurts=0
var last_absorbed=0
var hurt_until=0.0
var happy_until=0.0
var last_clock=-1.0

func _init():
	for entry in [["idle",9],["charge",7],["dash",7],["hurt",7],["absorb",9],["sprint",7]]:
		var frames:Array[Texture2D]=[]
		for i in entry[1]: frames.append(load("res://assets/emotions/%s_%d.png"%[entry[0],i]))
		clips[entry[0]]=frames

func frame_for(clip:String,progress:float) -> Texture2D:
	var frames:Array=clips[clip]
	return frames[clampi(int(progress*frames.size()),0,frames.size()-1)]

func pose(a) -> Dictionary:
	if a.clock<last_clock:
		last_hurts=0;last_absorbed=0;hurt_until=0;happy_until=0
		state="idle";state_started=0
	last_clock=a.clock
	if a.hurt_count>last_hurts: hurt_until=a.clock+.52
	if a.absorbed>last_absorbed: happy_until=a.clock+.7
	last_hurts=a.hurt_count;last_absorbed=a.absorbed
	var next="idle"
	if a.clock<hurt_until or a.hit_flash>0: next="hurt"
	elif a.charging: next="charge"
	elif a.dash_left>0: next="dash"
	elif a.sprinting: next="sprint"
	elif a.clock<happy_until or a.absorb_visual>0: next="absorb"
	if a.level_up_left>0: next="absorb"
	if a.ended and a.hp<=0: next="hurt"
	if next!=state:
		state=next;state_started=a.clock
	var progress=fmod(a.clock*.6,1.0)
	if state=="sprint": progress=fmod(a.clock*1.6,1.0)
	elif state=="charge": progress=clampf(a.charge/.8,0,.999)
	elif state=="dash": progress=clampf((a.clock-state_started)/.32,.15,.85)
	elif state=="hurt": progress=clampf((a.clock-state_started)/.52,.15,.999)
	elif state=="absorb": progress=clampf((a.clock-state_started)/.7,.12,.999)
	var celebrating=a.level_up_left>0
	var celebration=1-a.level_up_left/a.LEVEL_UP_SECONDS
	if celebrating: progress=clampf(celebration,0,.999)
	if a.ended and a.hp<=0: progress=.48
	var texture=frame_for(state,progress)
	var radius=a.body_radius()*a.zoom
	var size=radius*2.65
	var scale=size/34.0
	var dimensions=texture.get_size()*scale
	if celebrating:
		var squash=sin(clampf(celebration/.22,0,1)*PI)*.17
		var stretch=sin(clampf((celebration-.15)/.85,0,1)*PI)*.14
		dimensions*=Vector2(1+squash-stretch*.5,1-squash+stretch)
	var offset=Vector2(-dimensions.x*.5,size*.15-dimensions.y)
	if celebrating: offset.y-=sin(celebration*PI)*radius*.42
	var tilt=clampf(a.velocity.x/maxf(1,300*a.unit()),-1,1)*.045 if state=="idle" else 0.0
	# Ring and sprite share the same visible bounds, not the ground collision center.
	# Source frames face left. Gameplay facing +1 means right, so reflect them.
	return {"texture":texture,"rect":Rect2(offset,dimensions),"tilt":tilt,"facing":-a.facing,
		"center":offset+dimensions*.5,"ring_radius":maxf(dimensions.x,dimensions.y)*.55+maxf(3,radius*.12),"state":state}

func draw(c:CanvasItem,p:Vector2,pose:Dictionary,tint:Color):
	c.draw_set_transform(p,pose.tilt,Vector2(pose.get("facing",1.0),1))
	c.draw_texture_rect(pose.texture,pose.rect,false,tint)
	c.draw_set_transform(Vector2.ZERO)

func death_pose(a) -> Dictionary:
	var progress=a.death_progress()
	var melt=smoothstep(.10,.78,progress)
	var texture=frame_for("hurt",clampf(progress*1.7,.15,.999))
	var size=a.body_radius()*a.zoom*2.65
	var dimensions=texture.get_size()*size/34.0
	dimensions*=Vector2(1+melt*.65,1-melt*.94)
	var offset=Vector2(-dimensions.x*.5,size*.15-dimensions.y)
	return {"texture":texture,"rect":Rect2(offset,dimensions),"tilt":0.0,"facing":-a.facing,
		"alpha":1-smoothstep(.58,.82,progress),"melt":melt}
