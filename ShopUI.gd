extends CanvasLayer
var game: Node
var shell: Control
var list: VBoxContainer
var balance: Label
var rows: Array = []
var selected_tab := 0
var refresh_time := 0.0
var sound_button: Button
var volume_slider: HSlider
var volume_label: Label
const GROUPS := [["runner","seller","fisher","collector"],["tool","bag","speed","trade"],["runner_rank","seller_rank","fisher_rank","collector_rank"],["kitchen_rank","recipe_grill","recipe_smoke","recipe_soup"]]

func style(color: Color, radius: int = 16) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=color
	result.set_corner_radius_all(radius)
	result.content_margin_left=14
	result.content_margin_right=14
	result.content_margin_top=12
	result.content_margin_bottom=12
	return result

func _ready() -> void:
	layer=20
	shell=Control.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	var shade := ColorRect.new()
	shade.color=Color(0.02,0.05,0.08,0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=18
	panel.offset_top=90
	panel.offset_right=-18
	panel.offset_bottom=-40
	panel.add_theme_stylebox_override("panel",style(Color("16313c"),24))
	shell.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	panel.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var heading := Label.new()
	heading.text="КРАМНИЦЯ"
	heading.add_theme_font_size_override("font_size",27)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var close := Button.new()
	close.text="Закрити ×"
	close.custom_minimum_size=Vector2(120,48)
	close.pressed.connect(game.close_shop)
	header.add_child(close)
	balance=Label.new()
	balance.add_theme_color_override("font_color",Color("ffdc94"))
	body.add_child(balance)
	var tabs := GridContainer.new()
	tabs.columns=2
	body.add_child(tabs)
	var titles := ["Помічники","Герой","Розвиток NPC","Кухня та страви"]
	for i in range(4):
		var button := Button.new()
		button.text=titles[i]
		button.custom_minimum_size=Vector2(0,54)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_tab.bind(i))
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list=VBoxContainer.new()
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	var note := Label.new()
	note.text="Оплата лише зібраними монетами."
	note.add_theme_color_override("font_color",Color("a8c2c5"))
	body.add_child(note)
	sound_button=Button.new()
	sound_button.custom_minimum_size=Vector2(0,44)
	sound_button.pressed.connect(func(): game.toggle_audio(); refresh())
	body.add_child(sound_button)
	var volume_row := HBoxContainer.new()
	body.add_child(volume_row)
	var minus := Button.new()
	minus.text="−"
	minus.custom_minimum_size=Vector2(52,46)
	minus.pressed.connect(func(): game.set_audio_volume(game.audio_volume-0.1); refresh())
	volume_row.add_child(minus)
	volume_slider=HSlider.new()
	volume_slider.min_value=0
	volume_slider.max_value=100
	volume_slider.step=5
	volume_slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(func(value: float): game.set_audio_volume(value/100.0))
	volume_row.add_child(volume_slider)
	volume_label=Label.new()
	volume_label.custom_minimum_size=Vector2(55,0)
	volume_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	volume_row.add_child(volume_label)
	var plus := Button.new()
	plus.text="+"
	plus.custom_minimum_size=Vector2(52,46)
	plus.pressed.connect(func(): game.set_audio_volume(game.audio_volume+0.1); refresh())
	volume_row.add_child(plus)
	shell.hide()

func set_open(value: bool) -> void:
	shell.visible=value
	if value:
		show_tab(selected_tab)

func show_tab(index: int) -> void:
	selected_tab=index
	rows.clear()
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for kind in GROUPS[index]:
		var data: Dictionary=game.shop_item(kind)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel",style(Color("244650")))
		card.custom_minimum_size=Vector2(0,162)
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var image := TextureRect.new()
		image.texture=load("res://"+data.icon)
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.custom_minimum_size=Vector2(106,130)
		image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		row.add_child(image)
		var text_column := VBoxContainer.new()
		text_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(text_column)
		var title := Label.new()
		title.text=data.title
		title.add_theme_font_size_override("font_size",21)
		text_column.add_child(title)
		var detail := Label.new()
		detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_color_override("font_color",Color("c5d9d8"))
		text_column.add_child(detail)
		var buy := Button.new()
		buy.custom_minimum_size=Vector2(0,48)
		buy.add_theme_stylebox_override("normal",style(Color("3e766e"),10))
		buy.pressed.connect(purchase.bind(kind))
		text_column.add_child(buy)
		rows.append({"kind":kind,"detail":detail,"buy":buy})
	refresh()

func purchase(kind: String) -> void:
	game.shop_purchase(kind)
	refresh()

func refresh() -> void:
	volume_slider.set_value_no_signal(game.audio_volume*100)
	volume_label.text="%d%%" % roundi(game.audio_volume*100)
	sound_button.text="Звук: увімкнено" if game.sounds_enabled else "Звук: вимкнено"
	balance.text="Монети: %d     Рівень героя: %d" % [game.money,game.player_level]
	for row in rows:
		var item: Dictionary=game.shop_item(row.kind)
		row.detail.text=item.detail
		row.buy.disabled=not item.available
		if row.kind.begins_with("recipe_") and item.capped:
			row.buy.text="Готується зараз"
		elif item.capped:
			row.buy.text="Придбано" if row.kind in ["runner","seller","fisher","collector"] else "Максимальний рівень"
		elif item.required==99:
			row.buy.text="Спочатку найми працівника"
		elif game.player_level<item.required:
			row.buy.text="Потрібен рівень %d" % item.required
		elif game.kitchen_rank<item.kitchen_required:
			row.buy.text="Потрібна кухня рівня %d" % item.kitchen_required
		elif game.money<item.cost:
			row.buy.text="%d монет · недостатньо" % item.cost
		else:
			row.buy.text="Готувати цю страву" if row.kind.begins_with("recipe_") and item.cost==0 else "Купити · %d монет" % item.cost

func _process(delta: float) -> void:
	if not shell.visible:
		return
	refresh_time+=delta
	if refresh_time>=0.2:
		refresh_time=0
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if shell.visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		game.close_shop()
		get_viewport().set_input_as_handled()
