extends Node3D
## Pixel particles: embers, sparks and smoke as small SQUARE pixels, drawn unshaded with nearest filtering in
## palette colours only. They never fade their alpha: each one steps through a short ramp of palette colours (bright,
## then darker, then dark; two to four colours) and simply vanishes after the last, the way pixel art does.
##
## One of these lives in the dungeon's SpellEffects node; spell_effects.gd calls emit() with a parameter
## dictionary built from data/spell_effects.tres, so no look is hard-coded here:
##   ramp      PackedColorArray, brightest first
##   speed     Vector2(min, max) world units a second
##   direction Vector3 (default up); spread 0..1 how far they scatter from it
##   gravity   units/s^2 pulling down (negative lifts: smoke)
##   drag      0..1 a second of slowing
##   life      Vector2(min, max) seconds
##   size      pixels of art across (1 art pixel is `pixel_size` world units)
##   jitter    Vector3 box the start points are scattered in
## A hard cap keeps a busy cast from slowing the game: the oldest particle is dropped first.

const MAX_PARTICLES := 220

var pixel_size := 0.014
var _texture: ImageTexture
var _parts: Array = []  # {node, vel, age, life, ramp, gravity, drag}


func _ready() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_texture = ImageTexture.create_from_image(image)


func emit(at: Vector3, count: int, o: Dictionary) -> void:
	var ramp: PackedColorArray = o.get("ramp", PackedColorArray([Color.WHITE]))
	var speed: Vector2 = o.get("speed", Vector2(0.5, 1.5))
	var direction: Vector3 = o.get("direction", Vector3.UP).normalized()
	var spread: float = o.get("spread", 1.0)
	var life: Vector2 = o.get("life", Vector2(0.4, 0.8))
	var size: float = o.get("size", 2.0)
	var jitter: Vector3 = o.get("jitter", Vector3.ZERO)
	for i in count:
		if _parts.size() >= MAX_PARTICLES:
			var oldest = _parts.pop_front()
			if is_instance_valid(oldest.node):
				oldest.node.queue_free()
		var sprite := Sprite3D.new()
		sprite.texture = _texture
		sprite.pixel_size = pixel_size * size
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.modulate = ramp[0]
		sprite.position = at + Vector3(randf_range(-jitter.x, jitter.x), randf_range(-jitter.y, jitter.y), randf_range(-jitter.z, jitter.z))
		add_child(sprite)
		var scatter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * spread
		var vel := (direction + scatter).normalized() * randf_range(speed.x, speed.y)
		_parts.append({"node": sprite, "vel": vel, "age": 0.0, "life": randf_range(life.x, life.y), "ramp": ramp,
				"gravity": o.get("gravity", 0.0), "drag": o.get("drag", 0.0)})


func _process(delta: float) -> void:
	var keep := []
	for p in _parts:
		var node: Sprite3D = p.node
		if not is_instance_valid(node):
			continue
		p.age += delta
		if p.age >= p.life:
			node.queue_free()
			continue
		p.vel.y -= p.gravity * delta
		p.vel *= maxf(0.0, 1.0 - p.drag * delta)
		node.position += p.vel * delta
		var ramp: PackedColorArray = p.ramp
		node.modulate = ramp[mini(ramp.size() - 1, int(p.age / p.life * ramp.size()))]  # A step, never a fade.
		keep.append(p)
	_parts = keep


func count() -> int:
	return _parts.size()
