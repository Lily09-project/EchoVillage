class_name VillageArt
extends RefCounted

const INK := Color("2f2830")
const PAPER := Color("fff4dc")
const PAPER_SHADOW := Color("e4cda5")
const FOREST := Color("2e6b58")
const MEADOW := Color("78ad73")
const MOSS := Color("3f8467")
const SUN := Color("f5bd55")
const TERRACOTTA := Color("c86e57")
const WATER := Color("55a7b8")
const NIGHT := Color("1c2b50")
const LAVENDER := Color("7b6aa7")

const CHARACTERS := {
	"alice":{"body":Color("f3c45b"),"hair":Color("5b3d35"),"outfit":Color("b5646e"),"accent":Color("fff0b8"),"role_prop":"baker"},
	"bob":{"body":Color("b97850"),"hair":Color("2d3543"),"outfit":Color("557f99"),"accent":Color("c7e5eb"),"role_prop":"farmer"},
	"charlie":{"body":Color("df9e6c"),"hair":Color("493438"),"outfit":Color("8a77b3"),"accent":Color("e8defc"),"role_prop":"scribe"},
	"diana":{"body":Color("9d6e55"),"hair":Color("242c39"),"outfit":Color("4a9a81"),"accent":Color("c1f4d3"),"role_prop":"healer"},
	"eric":{"body":Color("d98c53"),"hair":Color("603b2f"),"outfit":Color("9a6948"),"accent":Color("ffe1a5"),"role_prop":"ranger"}
}

static func character_style(id: String) -> Dictionary:
	return CHARACTERS.get(id,CHARACTERS["alice"]).duplicate(true)

static func time_palette(light: float, is_night: bool) -> Dictionary:
	var sky := NIGHT.lerp(Color("91c8d4"),light)
	var ground := Color("265f5b").lerp(MEADOW,light)
	return {"sky":sky,"ground":ground,"water":WATER.lerp(Color("a5d7d9"),light * 0.3),"window_light":SUN if is_night else Color("fff5c8"),"overlay_alpha":(1.0 - light) * 0.36}

static func building_style(id: String) -> Dictionary:
	var styles := {
		"tavern":{"roof":TERRACOTTA,"trim":Color("8c4c46"),"sign":"THE HEARTH"},
		"shop":{"roof":SUN,"trim":Color("bd873f"),"sign":"PROVISIONS"},
		"farm":{"roof":Color("a66d4c"),"trim":Color("74493d"),"sign":"HARVEST"},
		"healer":{"roof":LAVENDER,"trim":Color("624f87"),"sign":"HERBAL HOUSE"}
	}
	return styles.get(id,styles["tavern"]).duplicate(true)

static func draw_sky(surface: CanvasItem, viewport: Rect2, light: float, time: float, is_night: bool) -> void:
	var palette := time_palette(light,is_night)
	surface.draw_rect(viewport,palette["sky"])
	if is_night:
		for star in [Vector2(106,116),Vector2(188,146),Vector2(332,104),Vector2(510,142),Vector2(732,111),Vector2(982,148),Vector2(1148,112)]:
			surface.draw_circle(star,1.2 + sin(time * 1.6 + star.x) * 0.35,Color("fff4c8"))
	for cloud in [Vector2(158,158),Vector2(760,128)]:
		var drift := fmod(time * 5.0 + cloud.x,390.0)
		var mist := Color(1,1,1,0.05 + light * 0.13)
		surface.draw_circle(cloud + Vector2(drift,0),22,mist)
		surface.draw_circle(cloud + Vector2(drift + 29,-7),28,mist)
		surface.draw_circle(cloud + Vector2(drift + 62,2),20,mist)

static func draw_celestial(surface: CanvasItem, minute: int, light: float) -> void:
	var arc := clampf((float(minute) - 270.0) / 990.0,0.0,1.0)
	var position_value := Vector2(105 + arc * 1060,140 - sin(arc * PI) * 87)
	if light > 0.42:
		surface.draw_circle(position_value,27,Color(SUN,0.18))
		surface.draw_circle(position_value,18,SUN)
		surface.draw_circle(position_value + Vector2(-5,-4),4,Color("fff4c8"))
	else:
		surface.draw_circle(position_value,16,Color("dbeafb"))
		surface.draw_circle(position_value + Vector2(6,-3),15,NIGHT)

static func draw_meadow(surface: CanvasItem, world: Rect2, light: float, time: float) -> void:
	var palette := time_palette(light,false)
	surface.draw_rect(world,palette["ground"])
	for x in range(int(world.position.x + 14),int(world.end.x),28):
		for y in range(int(world.position.y + 12),int(world.end.y),25):
			var wave := sin(time * 1.5 + float(x * 3 + y)) * 0.6
			surface.draw_line(Vector2(x,y),Vector2(x + 2 + wave,y - 3),Color("c7e49b",0.22),1.0)
	for patch in [Vector2(166,190),Vector2(246,505),Vector2(730,208),Vector2(1050,354),Vector2(1130,536)]:
		draw_flower_patch(surface,patch,time)

static func draw_forest_edge(surface: CanvasItem, world: Rect2, light: float, time: float) -> void:
	var ground := Color("183f3a").lerp(Color("477d58"),light * 0.72)
	var deep_shadow := Color("102c30",0.92)
	surface.draw_rect(world,ground)
	# 紙雕般的遠景樹冠，讓森林與村莊在第一眼就有不同輪廓。
	for x in range(54,1240,54):
		var canopy_y := 126.0 + sin(float(x) * 0.043) * 19.0
		surface.draw_circle(Vector2(x,canopy_y),42.0 + float(x % 4) * 3.0,deep_shadow)
		surface.draw_circle(Vector2(x + 18,canopy_y + 18),35.0,Color("245443"))
	# 蜿蜒的淺色林徑把視線帶往草藥營地。
	var path_edge := PackedVector2Array([Vector2(525,594),Vector2(710,594),Vector2(734,515),Vector2(666,450),Vector2(704,378),Vector2(624,318),Vector2(668,242),Vector2(604,94),Vector2(500,94),Vector2(557,245),Vector2(498,323),Vector2(568,389),Vector2(500,465)])
	var path := PackedVector2Array([Vector2(546,594),Vector2(686,594),Vector2(706,518),Vector2(637,449),Vector2(675,383),Vector2(596,321),Vector2(640,241),Vector2(579,94),Vector2(523,94),Vector2(585,245),Vector2(527,321),Vector2(599,389),Vector2(531,465)])
	surface.draw_colored_polygon(path_edge,Color("765f45"))
	surface.draw_colored_polygon(path,Color("b99c68").lerp(Color("d9c18d"),light * 0.35))
	for tree_data in [[Vector2(112,196),54.0],[Vector2(205,268),43.0],[Vector2(1058,208),58.0],[Vector2(1160,310),44.0],[Vector2(104,490),48.0],[Vector2(1090,512),55.0],[Vector2(325,160),37.0],[Vector2(890,166),39.0],[Vector2(336,500),41.0],[Vector2(904,492),43.0]]:
		draw_tree(surface,tree_data[0],tree_data[1],light * 0.82,time)
	# 黛安娜的採集營地與可讀的草藥聚落。
	var camp := Vector2(820,342)
	surface.draw_circle(camp,54,Color("163d38",0.62))
	surface.draw_colored_polygon(PackedVector2Array([camp + Vector2(-30,22),camp + Vector2(0,-28),camp + Vector2(31,22)]),Color("c47a50"))
	surface.draw_colored_polygon(PackedVector2Array([camp + Vector2(-19,20),camp + Vector2(0,-17),camp + Vector2(19,20)]),Color("f1d4a1"))
	surface.draw_circle(camp + Vector2(0,31),11 + sin(time * 4.0),Color(SUN,0.28))
	surface.draw_circle(camp + Vector2(0,31),5,Color("e9824f"))
	for herb in [Vector2(743,438),Vector2(774,466),Vector2(835,456),Vector2(867,430),Vector2(292,358)]:
		surface.draw_line(herb,herb + Vector2(0,-12),Color("a8d78a"),2.0)
		surface.draw_circle(herb + Vector2(-4,-10),4,Color("75bd7f"))
		surface.draw_circle(herb + Vector2(4,-13),4,Color("98d99a"))
	# 地點標牌兼具世界觀與導航用途。
	surface.draw_rect(Rect2(70,112,202,38),Color("172f32",0.88))
	surface.draw_rect(Rect2(70,112,202,38),Color("e8d09b",0.72),false,1.5)
	surface.draw_string(ThemeDB.fallback_font,Vector2(84,137),"低語森林邊緣 · 草藥營地",HORIZONTAL_ALIGNMENT_LEFT,-1,14,PAPER)

static func draw_flower_patch(surface: CanvasItem, center: Vector2, time: float) -> void:
	for index in 8:
		var angle := float(index) * 0.79
		var point := center + Vector2(cos(angle) * (12 + index % 3 * 5),sin(angle) * (8 + index % 2 * 5))
		surface.draw_circle(point,2.2,Color("fff0a8") if index % 2 == 0 else Color("e9a0aa"))
		surface.draw_circle(point + Vector2(0,sin(time + index) * 0.45),0.9,Color("fff8db"))

static func draw_path(surface: CanvasItem) -> void:
	var path_color := Color("d6b77a")
	var edge := Color("ae8759")
	surface.draw_rect(Rect2(70,318,1142,68),edge)
	surface.draw_rect(Rect2(76,324,1130,56),path_color)
	surface.draw_rect(Rect2(588,110,76,468),edge)
	surface.draw_rect(Rect2(594,110,64,468),path_color)
	for x in range(92,1180,42):
		surface.draw_line(Vector2(x,350),Vector2(x + 24,350),Color("fff1c5",0.35),1.0)

static func draw_stream(surface: CanvasItem, light: float, time: float) -> void:
	var water: Color = time_palette(light,false)["water"]
	var points := PackedVector2Array([Vector2(1055,95),Vector2(1115,95),Vector2(1092,188),Vector2(1140,276),Vector2(1102,366),Vector2(1164,470),Vector2(1132,594),Vector2(1068,594),Vector2(1098,478),Vector2(1043,370),Vector2(1084,278),Vector2(1036,186)])
	surface.draw_colored_polygon(points,water)
	for index in 5:
		var y := 132.0 + index * 88.0
		var shift := sin(time * 2.0 + index) * 5.0
		surface.draw_line(Vector2(1065 + shift,y),Vector2(1100 + shift,y + 12),Color("e6ffff",0.5),1.4)

static func draw_fountain(surface: CanvasItem, center: Vector2, time: float) -> void:
	surface.draw_circle(center,78,Color("386f67",0.74))
	surface.draw_circle(center,69,Color("81b29a"))
	surface.draw_circle(center,47,Color("547d87"))
	surface.draw_circle(center,39,WATER)
	surface.draw_circle(center,27,Color("b4e0dc"))
	for offset in [Vector2(-16,-12),Vector2(0,-20),Vector2(16,-12)]:
		var bob := sin(time * 3.0 + offset.x) * 2.5
		surface.draw_line(center + offset,center + offset + Vector2(0,-15 + bob),Color("e3ffff",0.82),2.0)
	surface.draw_circle(center,11,PAPER)

static func draw_tree(surface: CanvasItem, position_value: Vector2, radius: float, light: float, time: float) -> void:
	var trunk := Color("704b3b")
	surface.draw_rect(Rect2(position_value + Vector2(-5,4),Vector2(10,radius * 0.78)),trunk)
	for layer in [[Vector2(-0.4,-0.32),0.72],[Vector2(0.30,-0.14),0.68],[Vector2(-0.05,0.08),0.84]]:
		var point: Vector2 = position_value + Vector2(layer[0].x * radius,layer[0].y * radius + sin(time + position_value.x) * 0.7)
		var tint := FOREST.lerp(Color("5a956c"),light * (0.45 + layer[1] * 0.25))
		surface.draw_circle(point,radius * layer[1],tint)
		surface.draw_circle(point + Vector2(-radius * 0.16,-radius * 0.18),radius * layer[1] * 0.48,Color("b5d87f",0.24 + light * 0.2))

static func draw_building(surface: CanvasItem, position_value: Vector2, size_value: Vector2, id: String, light: float, is_night: bool) -> void:
	var style := building_style(id)
	var roof: Color = style["roof"]
	var trim: Color = style["trim"]
	var wall := PAPER_SHADOW.lerp(PAPER,light * 0.6)
	surface.draw_rect(Rect2(position_value + Vector2(3,5),size_value),Color(INK,0.22))
	surface.draw_rect(Rect2(position_value,size_value),wall)
	surface.draw_colored_polygon(PackedVector2Array([position_value + Vector2(-12,2),position_value + Vector2(size_value.x + 12,2),position_value + Vector2(size_value.x * 0.5,-35)]),roof)
	surface.draw_colored_polygon(PackedVector2Array([position_value + Vector2(-8,1),position_value + Vector2(size_value.x + 8,1),position_value + Vector2(size_value.x * 0.5,-27)]),roof.lightened(0.09))
	for x in [0.20,0.70]:
		var window_pos := position_value + Vector2(size_value.x * x - 10,26)
		surface.draw_rect(Rect2(window_pos,Vector2(19,21)),trim)
		surface.draw_rect(Rect2(window_pos + Vector2(3,3),Vector2(13,15)),time_palette(light,is_night)["window_light"])
		if is_night: surface.draw_circle(window_pos + Vector2(9,10),13,Color(SUN,0.12))
	var door := Rect2(position_value + Vector2(size_value.x * 0.5 - 10,size_value.y - 31),Vector2(20,31))
	surface.draw_rect(door,INK)
	surface.draw_circle(door.position + Vector2(15,17),1.7,SUN)
	var sign := Rect2(position_value + Vector2(10,10),Vector2(size_value.x - 20,14))
	surface.draw_rect(sign,Color("f3dcab"))
	surface.draw_string(ThemeDB.fallback_font,sign.position + Vector2(5,11),style["sign"],HORIZONTAL_ALIGNMENT_LEFT,-1,8,INK)

static func draw_cottage(surface: CanvasItem, position_value: Vector2, accent: Color, resident_name: String, light: float, is_night: bool) -> void:
	var size_value := Vector2(72,48)
	var wall := PAPER_SHADOW.lerp(PAPER,light * 0.62)
	surface.draw_rect(Rect2(position_value + Vector2(3,4),size_value),Color(INK,0.20))
	surface.draw_rect(Rect2(position_value,size_value),wall)
	surface.draw_colored_polygon(PackedVector2Array([position_value + Vector2(-8,2),position_value + Vector2(80,2),position_value + Vector2(36,-24)]),accent.darkened(0.12))
	surface.draw_colored_polygon(PackedVector2Array([position_value + Vector2(-4,1),position_value + Vector2(76,1),position_value + Vector2(36,-18)]),accent)
	var window_pos := position_value + Vector2(12,15)
	surface.draw_rect(Rect2(window_pos,Vector2(15,15)),INK)
	surface.draw_rect(Rect2(window_pos + Vector2(3,3),Vector2(9,9)),SUN if is_night else Color("b8dfe0"))
	surface.draw_rect(Rect2(position_value + Vector2(46,19),Vector2(16,29)),INK)
	surface.draw_string(ThemeDB.fallback_font,position_value + Vector2(4,63),resident_name + "的家",HORIZONTAL_ALIGNMENT_CENTER,64,10,PAPER)

static func draw_character(surface: CanvasItem, id: String, npc: Dictionary, selected: bool, motion_enabled: bool, time: float) -> void:
	var style := character_style(id)
	var bounce := sin(time * 2.5 + float(abs(id.hash() % 11))) * (1.6 if motion_enabled else 0.0)
	var point: Vector2 = npc["position"] + Vector2(0,bounce)
	if selected:
		surface.draw_circle(point + Vector2(0,10),20 + sin(time * 3.0) * 1.2,Color(SUN,0.46))
		surface.draw_arc(point + Vector2(0,10),20,0,TAU,24,SUN,1.4)
	surface.draw_circle(point + Vector2(0,5),10,style["outfit"])
	surface.draw_rect(Rect2(point + Vector2(-8,5),Vector2(16,12)),style["outfit"])
	surface.draw_circle(point + Vector2(0,-7),8,style["body"])
	surface.draw_circle(point + Vector2(0,-11),8,style["hair"])
	surface.draw_circle(point + Vector2(-3,-7),1.0,INK)
	surface.draw_circle(point + Vector2(3,-7),1.0,INK)
	surface.draw_circle(point + Vector2(0,-3),1.1,style["accent"])
	draw_role_prop(surface,point + Vector2(10,8),str(style["role_prop"]),style["accent"])
	surface.draw_string(ThemeDB.fallback_font,point + Vector2(-24,-23),str(npc["display_name"]),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("fff8df"))

static func draw_action_badge(surface: CanvasItem, position_value: Vector2, label: String, is_selected: bool) -> void:
	var fill := Color("213246",0.9) if not is_selected else Color("6f4c35",0.94)
	surface.draw_rect(Rect2(position_value + Vector2(-29,19),Vector2(58,18)),fill)
	surface.draw_string(ThemeDB.fallback_font,position_value + Vector2(-23,32),label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,PAPER)

static func draw_event_marker(surface: CanvasItem, event_name: String, active: bool, time: float) -> void:
	if not active: return
	var center := Vector2(625,282)
	var radius := 19 + sin(time * 3.0) * 2.0
	surface.draw_circle(center,radius,Color(TERRACOTTA,0.26))
	surface.draw_arc(center,radius,0,TAU,24,TERRACOTTA,1.5)
	surface.draw_string(ThemeDB.fallback_font,center + Vector2(-32,-28),event_name,HORIZONTAL_ALIGNMENT_CENTER,64,10,PAPER)

static func draw_role_prop(surface: CanvasItem, point: Vector2, role_prop: String, accent: Color) -> void:
	if role_prop == "baker":
		surface.draw_circle(point,4,accent)
	elif role_prop == "farmer":
		surface.draw_line(point + Vector2(-3,4),point + Vector2(4,-5),Color("79543b"),2.0)
	elif role_prop == "scribe":
		surface.draw_rect(Rect2(point + Vector2(-3,-4),Vector2(6,9)),accent)
	elif role_prop == "healer":
		surface.draw_circle(point,4,accent)
		surface.draw_line(point + Vector2(-5,0),point + Vector2(5,0),PAPER,1.0)
	else:
		surface.draw_line(point + Vector2(-3,4),point + Vector2(4,-5),accent,2.0)

static func draw_player(surface: CanvasItem, position_value: Vector2, motion_enabled: bool, time: float) -> void:
	var halo := 20 + sin(time * 3.0) * (1.5 if motion_enabled else 0.0)
	surface.draw_circle(position_value + Vector2(0,8),halo,Color("8bd4e6",0.25))
	surface.draw_circle(position_value + Vector2(0,3),12,Color("4f94b5"))
	surface.draw_circle(position_value + Vector2(0,-7),8,Color("f2c391"))
	surface.draw_circle(position_value + Vector2(0,-11),8,Color("293c5c"))
	surface.draw_string(ThemeDB.fallback_font,position_value + Vector2(-11,-24),"你",HORIZONTAL_ALIGNMENT_LEFT,-1,11,PAPER)
