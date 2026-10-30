extends Control
var game: Node
var bag_icon=preload("res://icons/bag.svg")
func _process(_delta: float) -> void:
 queue_redraw()
func panel(rect: Rect2,color: Color) -> void:
 var style := StyleBoxFlat.new()
 style.bg_color=color
 style.set_corner_radius_all(13)
 style.border_color=Color(0.52,0.75,0.78,0.20)
 style.set_border_width_all(1)
 draw_style_box(style,rect)
func _draw() -> void:
 if game==null or game.start_pending:
  return
 var font := preload("res://ArtTheme.gd").BODY
 var numbers := preload("res://ArtTheme.gd").TITLE
 var w := get_viewport_rect().size.x
 var card_w := (w-152)*0.5
 panel(Rect2(12,12,card_w,70),Color(0.05,0.12,0.17,0.93))
 panel(Rect2(24+card_w,12,card_w,70),Color(0.05,0.12,0.17,0.93))
 draw_circle(Vector2(33,43),10,Color("e9bb62"))
 draw_arc(Vector2(33,43),7,0,TAU,24,Color("ffe5a3"),1.5,true)
 draw_string(font,Vector2(52,33),"МОНЕТИ",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a6c4c9"))
 var money_size := 28
 while money_size>16 and numbers.get_string_size(str(game.money),HORIZONTAL_ALIGNMENT_LEFT,-1,money_size).x>card_w-50:money_size-=1
 draw_string(numbers,Vector2(52,65),str(game.money),HORIZONTAL_ALIGNMENT_LEFT,-1,money_size,Color("ffe0a0"))
 var bx := 24+card_w
 draw_texture_rect(bag_icon,Rect2(bx+12,28,26,30),false,Color("dbe5d2"))
 draw_string(font,Vector2(bx+48,33),"РЮКЗАК",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a6c4c9"))
 var load_size: int=game.DATA.weight(game.profile.bag)
 var full: bool=load_size>=game.capacity()
 draw_string(numbers,Vector2(bx+48,63),"%d / %d" % [load_size,game.capacity()],HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("f0c477") if full else Color.WHITE)
 var ratio := clampf(float(load_size)/game.capacity(),0,1)
 draw_rect(Rect2(bx+48,73,card_w-62,3),Color("304c56"))
 draw_rect(Rect2(bx+48,73,(card_w-62)*ratio,3),Color("efbd6a") if full else Color("78cdb4"))
 panel(Rect2(12,88,w-24,35),Color(0.05,0.12,0.17,0.84))
 draw_string(preload("res://ArtTheme.gd").WORLD,Vector2(23,111),"%d · %s" % [game.selected_zone+1,game.DATA.ZONES[game.selected_zone].name],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c1d7dc"))
 draw_string(font,Vector2(w-175,111),"Рівень %d" % game.player_level,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f1e1bd"))
 draw_rect(Rect2(w-80,103,60,5),Color("334c60"))
 draw_rect(Rect2(w-80,103,60*clampf(float(game.xp)/game.xp_required(),0,1),5),Color("98d7b7"))
 if int(game.profile.tutorial_step)<game.TUTORIAL_STEPS and not game.shop_open:
  panel(Rect2(26,133,w-52,88),Color(0.045,0.15,0.19,0.94))
  var hint: Array=game.tutorial_lines()
  draw_string(font,Vector2(41,152),"ПІДКАЗКА %d / %d" % [int(game.profile.tutorial_step)+1,game.TUTORIAL_STEPS],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f1d496"))
  draw_string(font,Vector2(41,180),hint[0],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
  draw_string(font,Vector2(41,204),hint[1],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b5d2d2"))
 if game.touch_id!=-1 or game.mouse_drag:
  draw_circle(game.touch_start,42,Color(1,1,1,0.1))
  draw_arc(game.touch_start,42,0,TAU,48,Color(1,1,1,0.35),2,true)
  draw_circle(game.touch_start+game.stick*32,17,Color(1,1,1,0.55))
