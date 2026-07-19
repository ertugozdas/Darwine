extends SceneTree

## Bakes the fixed semantic icons into the four shared card-frame textures.
## Runtime card scripts should only place text and numeric values over these
## images. The untouched inputs live under source/plain so this script is
## deterministic and safe to run more than once.

const CARD_SIZE := Vector2(200.0, 280.0)

const ICON_SVGS := {
	"lightning": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<path d='M9.3 0.8 2.8 8.9h4.3l-2 6.4 8.2-9H9.2z' fill='#ffd43b' stroke='#3b2204' stroke-width='1.35' stroke-linejoin='round'/>
		<path d='M8.9 2.5 5.2 7.9' fill='none' stroke='#fff2a1' stroke-width='0.85' stroke-linecap='round'/>
	</svg>""",
	"sword": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<path d='M13.7 1.4 12.1 6.2 6.9 11.4 4.6 9.1 9.8 3.9z' fill='#dcecff' stroke='#151a20' stroke-width='1.15' stroke-linejoin='round'/>
		<path d='m5.9 8.1 2 2-2.2 2.2-2-2z' fill='#d99b35' stroke='#211506' stroke-width='1'/>
		<path d='m3.8 10.8 1.5 1.5-2 2-1.5-1.5z' fill='#6e3b20' stroke='#211506' stroke-width='1'/>
		<path d='m10.1 4.2 2.4-1.5-1.5 2.4-4.8 4.8' fill='none' stroke='#ffffff' stroke-opacity='.75' stroke-width='.7' stroke-linecap='round'/>
	</svg>""",
	"shield": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<path d='M8 1.2 13.4 3.7l-.8 6.6L8 14.8l-4.6-4.5-.8-6.6z' fill='#174663' stroke='#54c7ff' stroke-width='1.25' stroke-linejoin='round'/>
		<path d='M8 3v9.5M4.4 5.4h7.2' fill='none' stroke='#bfeeff' stroke-opacity='.85' stroke-width='.8' stroke-linecap='round'/>
	</svg>""",
	"heart": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<path d='M8 14.3 2.1 8.5C-.7 5.2 1.6 1.7 4.7 2 6.2 2.1 7.3 3 8 4.1 8.7 3 9.8 2.1 11.3 2c3.1-.3 5.4 3.2 2.6 6.5z' fill='#c63b43' stroke='#3d080d' stroke-width='1.25' stroke-linejoin='round'/>
		<path d='M3.4 4.2c1-.9 2.4-.5 3.2.5' fill='none' stroke='#ff9a9f' stroke-width='1' stroke-linecap='round'/>
	</svg>""",
	"magic": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<path d='M8 1.1 10 6l4.9 2-4.9 2-2 4.9L6 10 1.1 8 6 6z' fill='#8a4bd0' stroke='#d7a7ff' stroke-width='1.05' stroke-linejoin='round'/>
		<circle cx='8' cy='8' r='2.1' fill='#f2ddff'/>
	</svg>""",
	"burst": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<g stroke='#ffbd3e' stroke-width='1.45' stroke-linecap='round'>
			<path d='M8 1v2M8 13v2M1 8h2M13 8h2M3.1 3.1l1.4 1.4M11.5 11.5l1.4 1.4M12.9 3.1l-1.4 1.4M4.5 11.5l-1.4 1.4'/>
		</g>
		<circle cx='8' cy='8' r='3.3' fill='#6b310b' stroke='#261405' stroke-width='1'/>
		<circle cx='8' cy='8' r='1.9' fill='#ffd66c'/>
	</svg>""",
	"target": """<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'>
		<circle cx='8' cy='8' r='5.6' fill='#50120f' stroke='#ff5a3c' stroke-width='1.1'/>
		<circle cx='8' cy='8' r='2.2' fill='#ff6e4f'/>
		<path d='M8 0v4M8 12v4M0 8h4M12 8h4' fill='none' stroke='#ffb08f' stroke-width='1.1'/>
	</svg>""",
}

const TEMPLATE_SPECS := [
	{
		"name": "hero",
		"source": "res://images/cards/templates/source/plain/hero_frame.png",
		"output": "res://images/cards/templates/hero_frame.png",
		"icons": [
			{"type": "lightning", "rect": Rect2(13.0, 18.0, 13.0, 18.0)},
			{"type": "sword", "rect": Rect2(26.0, 155.0, 15.0, 15.0)},
			{"type": "shield", "rect": Rect2(83.0, 155.0, 15.0, 15.0)},
			{"type": "heart", "rect": Rect2(139.0, 155.0, 15.0, 15.0)},
		],
	},
	{
		"name": "settlement",
		"source": "res://images/cards/templates/source/plain/settlement_frame.png",
		"output": "res://images/cards/templates/settlement_frame.png",
		"icons": [
			{"type": "lightning", "rect": Rect2(13.0, 18.0, 13.0, 18.0)},
			{"type": "sword", "rect": Rect2(32.0, 162.0, 21.0, 21.0)},
			{"type": "heart", "rect": Rect2(122.0, 162.0, 21.0, 21.0)},
		],
	},
	{
		"name": "special_power",
		"source": "res://images/cards/templates/source/plain/spell_frame.png",
		"output": "res://images/cards/templates/spell_frame.png",
		"icons": [
			{"type": "lightning", "rect": Rect2(13.0, 18.0, 13.0, 18.0)},
			{"type": "magic", "rect": Rect2(23.0, 155.0, 16.0, 16.0)},
			{"type": "burst", "rect": Rect2(127.0, 155.0, 16.0, 16.0)},
		],
	},
	{
		"name": "upgrade",
		"source": "res://images/cards/templates/source/plain/upgrade_frame.png",
		"output": "res://images/cards/templates/upgrade_frame.png",
		"icons": [
			{"type": "lightning", "rect": Rect2(13.0, 19.0, 13.0, 18.0)},
			{"type": "target", "rect": Rect2(22.0, 157.0, 16.0, 16.0)},
			{"type": "sword", "rect": Rect2(100.0, 160.0, 9.0, 10.0)},
			{"type": "shield", "rect": Rect2(129.0, 160.0, 9.0, 10.0)},
			{"type": "heart", "rect": Rect2(158.0, 160.0, 9.0, 10.0)},
		],
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var baked_images: Array[Dictionary] = []
	for template_spec in TEMPLATE_SPECS:
		var source_path := str(template_spec.source)
		var frame := Image.load_from_file(ProjectSettings.globalize_path(source_path))
		if frame == null or frame.is_empty():
			_fail("Kaynak kart çerçevesi yüklenemedi: %s" % source_path)
			return
		frame.convert(Image.FORMAT_RGBA8)
		var scale := Vector2(float(frame.get_width()) / CARD_SIZE.x, float(frame.get_height()) / CARD_SIZE.y)
		if str(template_spec.name) == "hero":
			_normalize_hero_health_well(frame, scale)
		for icon_spec in template_spec.icons:
			var card_rect: Rect2 = icon_spec.rect
			var pixel_size := Vector2i(
				maxi(1, roundi(card_rect.size.x * scale.x)),
				maxi(1, roundi(card_rect.size.y * scale.y))
			)
			var icon := _render_icon(str(icon_spec.type), pixel_size)
			if icon == null:
				return
			var destination := Vector2i(
				roundi(card_rect.position.x * scale.x),
				roundi(card_rect.position.y * scale.y)
			)
			frame.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), destination)
		baked_images.append({"image": frame, "output": str(template_spec.output), "name": str(template_spec.name)})

	for baked in baked_images:
		var output_path := ProjectSettings.globalize_path(str(baked.output))
		var error: Error = (baked.image as Image).save_png(output_path)
		if error != OK:
			_fail("Kart çerçevesi kaydedilemedi: %s (%s)" % [output_path, error_string(error)])
			return
		print("CARD_TEMPLATE_ICON_BAKED: %s -> %s" % [baked.name, baked.output])

	print("CARD_TEMPLATE_ICONS_BAKED")
	quit(0)


func _render_icon(icon_type: String, target_size: Vector2i) -> Image:
	if not ICON_SVGS.has(icon_type):
		_fail("Bilinmeyen kart ikonu: %s" % icon_type)
		return null
	var icon := Image.new()
	var error := icon.load_svg_from_string(str(ICON_SVGS[icon_type]), 8.0)
	if error != OK:
		_fail("SVG kart ikonu rasterize edilemedi: %s (%s)" % [icon_type, error_string(error)])
		return null
	icon.convert(Image.FORMAT_RGBA8)
	icon.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return icon


func _normalize_hero_health_well(frame: Image, scale: Vector2) -> void:
	# The source Hero frame contains a shield relief in the third stat well.
	# Reuse the first well's neutral forged-metal surface so health can receive
	# the same fixed semantic icon treatment as attack and armor.
	var source_center := Vector2i(
		roundi(33.6 * scale.x),
		roundi(162.6 * scale.y)
	)
	var destination_center := Vector2i(
		roundi(146.4 * scale.x),
		roundi(162.6 * scale.y)
	)
	var radius := roundi(15.5 * minf(scale.x, scale.y))
	var feather := maxi(1, roundi(2.0 * minf(scale.x, scale.y)))
	var solid_radius := radius - feather
	var source_snapshot := frame.duplicate()

	for offset_y in range(-radius, radius + 1):
		for offset_x in range(-radius, radius + 1):
			var distance := Vector2(float(offset_x), float(offset_y)).length()
			if distance > float(radius):
				continue
			var source_pixel := source_center + Vector2i(offset_x, offset_y)
			var destination_pixel := destination_center + Vector2i(offset_x, offset_y)
			if not Rect2i(Vector2i.ZERO, frame.get_size()).has_point(source_pixel):
				continue
			if not Rect2i(Vector2i.ZERO, frame.get_size()).has_point(destination_pixel):
				continue
			var weight := 1.0
			if distance > float(solid_radius):
				weight = clampf((float(radius) - distance) / float(feather), 0.0, 1.0)
				weight = weight * weight * (3.0 - 2.0 * weight)
			var current: Color = source_snapshot.get_pixelv(destination_pixel)
			var replacement: Color = source_snapshot.get_pixelv(source_pixel)
			frame.set_pixelv(destination_pixel, current.lerp(replacement, weight))


func _fail(message: String) -> void:
	push_error(message)
	print("CARD_TEMPLATE_ICON_BAKE_FAILED")
	quit(1)
