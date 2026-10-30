extends RefCounted
const BODY=preload("res://fonts/DejaVuSans.ttf")
const WORLD=preload("res://fonts/DejaVuSans-Bold.ttf")
const TITLE=preload("res://fonts/DejaVuSans-Bold.ttf")
static func make() -> Theme:
 var theme := Theme.new()
 theme.default_font=BODY
 theme.default_font_size=20
 theme.set_font("font","Label",BODY)
 theme.set_font("font","Button",BODY)
 theme.set_font("font","OptionButton",BODY)
 return theme
