extends Control
var game: Node
var panel_style: StyleBoxFlat

func _ready() -> void:
	panel_style=_panel(Color(0.035,0.10,0.15,0.82))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game):
		return
	var font := ThemeDB.fallback_font
	draw_style_box(panel_style,Rect2(14,16,512,66))
	# Coin, raw fish, cooked fish and level: only numeric counters.
	draw_circle(Vector2(38,42),11,Color("ffc857"))
	draw_circle(Vector2(38,42),7,Color("e9a52d"),false,2)
	draw_string(font,Vector2(56,50),str(game.money),HORIZONTAL_ALIGNMENT_LEFT,-1,20)
	_fish(Vector2(180,42),Color("a5e3ee"))
	draw_string(font,Vector2(195,50),"%d/%d" % [game.cargo+game.hero_dish_count,game.capacity()],HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	_fish(Vector2(300,42),Color("e5a164"))
	draw_string(font,Vector2(315,50),str(game.cooked_stock),HORIZONTAL_ALIGNMENT_LEFT,-1,20)
	draw_circle(Vector2(422,42),13,Color("539cc7"))
	draw_string(font,Vector2(415,49),str(game.player_level),HORIZONTAL_ALIGNMENT_LEFT,-1,18)
	draw_rect(Rect2(454,34,56,8),Color("334c5f"))
	draw_rect(Rect2(454,34,56*clampf(float(game.xp)/game.xp_required(),0,1),8),Color("91e2d0"))
	if game.touch_id != -1 or game.mouse_drag:
		draw_circle(game.touch_start,42,Color(1,1,1,0.10))
		draw_arc(game.touch_start,42,0,TAU,48,Color(1,1,1,0.35),2,true)
		draw_circle(game.touch_start+game.stick*32,17,Color(1,1,1,0.55))

func _fish(pos: Vector2, color: Color) -> void:
	draw_circle(pos,8,color)
	draw_colored_polygon(PackedVector2Array([pos+Vector2(-6,0),pos+Vector2(-15,-7),pos+Vector2(-15,7)]),color)
	draw_circle(pos+Vector2(3,-2),1.5,Color("1c3946"))

func _panel(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(18)
	return style
