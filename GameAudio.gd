extends Node
var effects: Array=[]
var clips: Dictionary={}
var ambient: Array=[]
var stove: AudioStreamPlayer
var music: AudioStreamPlayer
var enabled := true
var volume_level := 1.0
var mix_levels := {"effects":1.0,"music":0.32,"ambient":0.70}
var cursor := 0
var step_lock := 0.0
var event_cooldowns := {}
func _ready() -> void:
 for name in ["coin","sale","hire","level","shop","ice","ice_2","ice_3","step","step_2","step_3","transfer","water","wind","cook","music"]:
  clips[name]=load("res://audio/"+name+".wav")
 for i in range(10):
  var player := AudioStreamPlayer.new()
  add_child(player)
  player.set_meta("group","effects")
  effects.append(player)
 for name in ["water","wind"]:
  ambient.append(loop_player(name,-27.0 if name=="water" else -33.0,"ambient"))
 stove=loop_player("cook",-80.0,"ambient")
 music=loop_player("music",-17.0,"music")
func loop_player(name: String,base: float,group: String="ambient") -> AudioStreamPlayer:
 var player := AudioStreamPlayer.new()
 add_child(player)
 var stream: AudioStreamWAV=clips[name].duplicate()
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin=0
 stream.loop_end=int(stream.get_length()*stream.mix_rate)
 player.stream=stream
 player.set_meta("group",group)
 player.set_meta("base_volume",base)
 player.volume_db=base+volume_offset(group)
 player.play()
 return player
func play_event(name: String,base: float=-15.0) -> void:
 if not enabled or volume_level<=0 or float(mix_levels.effects)<=0 or not clips.has(name):return
 if float(event_cooldowns.get(name,0))>0:return
 event_cooldowns[name]=0.14 if name in ["coin","sale","transfer"] else 0.09
 if name=="step":
  if step_lock>0:return
  step_lock=0.13
 var clip_name := name
 if name in ["step","ice"]:
  var variant := randi_range(0,2)
  if variant>0:clip_name=name+"_"+str(variant+1)
 var player: AudioStreamPlayer=effects[cursor]
 cursor=(cursor+1)%effects.size()
 player.stream=clips[clip_name]
 player.set_meta("base_volume",base)
 player.volume_db=base+volume_offset("effects")
 player.pitch_scale=1.0 if name in ["coin","sale","hire","level","shop"] else randf_range(0.97,1.03)
 player.play()
func update_stove(cooking: bool,distance: float) -> void:
 var base := -24.0-clampf(distance,0,20)*1.5 if cooking else -80.0
 stove.set_meta("base_volume",base)
 stove.volume_db=base+volume_offset("ambient")
func set_enabled(value: bool) -> void:
 enabled=value
 refresh_levels()
func set_volume(value: float) -> void:
 volume_level=clampf(value,0,1)
 refresh_levels()
func set_mix(group: String,value: float) -> void:
 if not mix_levels.has(group):return
 mix_levels[group]=clampf(value,0,1)
 refresh_levels()
func volume_offset(group: String="effects") -> float:
 return linear_to_db(maxf(0.00001,volume_level*float(mix_levels.get(group,1.0))))
func refresh_levels() -> void:
 var players: Array=effects+ambient
 if is_instance_valid(stove):players.append(stove)
 if is_instance_valid(music):players.append(music)
 for player in players:
  var group: String=player.get_meta("group","effects")
  player.volume_db=float(player.get_meta("base_volume",-30.0))+volume_offset(group)
  var muted := not enabled or volume_level<=0 or float(mix_levels[group])<=0
  if group=="effects":
   if muted:player.stop()
  else:player.stream_paused=muted
func _process(delta: float) -> void:
 step_lock=maxf(0,step_lock-delta)
 for name in event_cooldowns:event_cooldowns[name]=maxf(0,float(event_cooldowns[name])-delta)
