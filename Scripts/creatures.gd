class_name Creatures
extends RefCounted

# The raccoon and the helpers, built from Art shapes.

const FUR := Color("928ea8")
const FUR_DARK := Color("5d5873")
const MASK := Color("3b3550")
const FACE := Color("f4f0fa")

enum Mood { IDLE, HAPPY, RAGE, WOW }
# BASE is everything except the eyes (it is baked to a texture), EYES are
# drawn live on top so they can follow the mouse and blink.
enum Part { ALL, BASE, EYES }


# Head centre is (0, 0); the head is about 150 wide.
# look: -1..1 in both axes. blink: 0..1. ear: extra ear tilt.
static func raccoon_head(look := Vector2.ZERO, blink := 0.0, mood := Mood.IDLE, ear := 0.0, fur := FUR, part := Part.ALL) -> Array:
	var groups := []
	var eyes := []
	var cheek_l := Art.V([Vector2(-50, -4), Vector2(-76, 16), Vector2(-52, 24)])
	groups.append([
		Art.E(Vector2(-42, -44), 17, 21, fur, -0.45 - ear),
		Art.E(Vector2(42, -44), 17, 21, fur, 0.45 + ear * 0.5),
		Art.E(Vector2(0, 0), 62, 50, fur),
		Art.P(cheek_l, fur), Art.P(Art.mirror(cheek_l), fur),
	])
	var face := [
		Art.E(Vector2(-42, -42), 8, 11, Art.PINK, -0.45 - ear, false),
		Art.E(Vector2(42, -42), 8, 11, Art.PINK, 0.45 + ear * 0.5, false),
		Art.E(Vector2(0, 22), 44, 25, FACE, 0.0, false),
		Art.E(Vector2(0, -32), 7, 14, MASK, 0.0, false),
		Art.E(Vector2(-23, -2), 26, 16, MASK, -0.28, false),
		Art.E(Vector2(23, -2), 26, 16, MASK, 0.28, false),
		Art.E(Vector2(0, -3), 12, 9, MASK, 0.0, false),
		Art.E(Vector2(-25, -22), 15, 5.5, FACE, -0.25, false),
		Art.E(Vector2(25, -22), 15, 5.5, FACE, 0.25, false),
	]
	groups.append(face)

	var eye_l := Vector2(-23, -2)
	var eye_r := Vector2(23, -2)
	if mood == Mood.HAPPY:
		eyes.append([
			Art.L(Art.V([eye_l + Vector2(-9, 3), eye_l + Vector2(0, -6), eye_l + Vector2(9, 3)]), 5, Art.WHITE, false),
			Art.L(Art.V([eye_r + Vector2(-9, 3), eye_r + Vector2(0, -6), eye_r + Vector2(9, 3)]), 5, Art.WHITE, false),
		])
	elif blink > 0.5:
		eyes.append([
			Art.L(Art.V([eye_l + Vector2(-9, 0), eye_l + Vector2(9, 0)]), 4, Art.WHITE, false),
			Art.L(Art.V([eye_r + Vector2(-9, 0), eye_r + Vector2(9, 0)]), 4, Art.WHITE, false),
		])
	else:
		var size := 13.0 if mood == Mood.WOW else 11.0
		eyes.append([Art.C(eye_l, size, Art.WHITE), Art.C(eye_r, size, Art.WHITE)])
		var iris := Color("ff3b3b") if mood == Mood.RAGE else Art.OL
		var shift := look.limit_length(1.0) * 4.0
		eyes.append([
			Art.C(eye_l + shift, 6.5, iris, false), Art.C(eye_r + shift, 6.5, iris, false),
			Art.C(eye_l + shift + Vector2(-2, -2.5), 2.4, Art.WHITE, false),
			Art.C(eye_r + shift + Vector2(-2, -2.5), 2.4, Art.WHITE, false),
		])
	if mood == Mood.RAGE:
		eyes.append([
			Art.L(Art.V([Vector2(-38, -22), Vector2(-12, -12)]), 6, Art.OL, false),
			Art.L(Art.V([Vector2(38, -22), Vector2(12, -12)]), 6, Art.OL, false),
		])

	var muzzle := [Art.E(Vector2(0, 22), 21, 15, FACE)]
	groups.append(muzzle)
	var mouth := [Art.E(Vector2(0, 13), 9, 6, Art.OL, 0.0, false), Art.C(Vector2(-3, 11), 2, Art.WHITE, false)]
	if mood == Mood.IDLE:
		mouth.append(Art.L(Art.V([Vector2(-9, 24), Vector2(-4, 28), Vector2(0, 25), Vector2(4, 28), Vector2(9, 24)]), 3, Art.OL, false))
	else:
		mouth.append(Art.E(Vector2(0, 28), 8, 7 if mood != Mood.WOW else 9, Color("7a2440"), 0.0, false))
		mouth.append(Art.E(Vector2(0, 32), 5, 3, Art.PINK, 0.0, false))
	groups.append(mouth)
	match part:
		Part.BASE:
			return groups
		Part.EYES:
			return eyes
	# Eyes go between the face and the muzzle.
	return groups.slice(0, 2) + eyes + groups.slice(2)


static func raccoon_paw() -> Array:
	return [
		[Art.E(Vector2.ZERO, 18, 12, FUR_DARK)],
		[Art.L(Art.V([Vector2(-6, 2), Vector2(-6, 10)]), 2.5, MASK, false),
			Art.L(Art.V([Vector2(2, 3), Vector2(2, 11)]), 2.5, MASK, false),
			Art.E(Vector2(-6, -5), 6, 3, Color(1, 1, 1, 0.25), 0.0, false)],
	]


# A striped bushy tail that curls up. swish: -1..1.
# It grows upwards from (0, 0) and curls at the tip.
static func tail(swish: float, length := 120.0, width := 30.0) -> Array:
	var curve := PackedVector2Array()
	for i in 15:
		var t := i / 14.0
		curve.append(Vector2(length * 0.38 * sin(t * 1.9) + swish * 22.0 * t * t, -length * t))
	var bands := []
	for j in [4, 7, 10]:
		bands.append(Art.L(curve.slice(j, j + 2), width, MASK, false, false))
	return [[Art.L(curve, width, FUR)], bands, [Art.C(curve[14], width * 0.5, MASK, false)]]


static func _scaled(groups: Array, offset: Vector2, scale: float) -> Array:
	var out := []
	for group in groups:
		var moved := []
		for s in group:
			moved.append(Art._offset(s, offset, scale))
		out.append(moved)
	return out


static func helper(c: CanvasItem, id: String, pos: Vector2, scale: float, rot := 0.0, alpha := 1.0) -> void:
	if Bake.draw(c, "helper_" + id, pos, Vector2(scale, scale), rot, Color(1, 1, 1, alpha)):
		return
	var groups := Art.cached("helper_" + id, func() -> Array: return helper_shapes(id))
	Art.draw_groups(c, groups, pos, scale, rot, Color(0, 0, 0, 0), alpha)


static func helper_silhouette(c: CanvasItem, id: String, pos: Vector2, scale: float) -> void:
	if Bake.draw(c, "helpersil_" + id, pos, Vector2(scale, scale), 0.0, Color("4a4060")):
		return
	var groups := Art.cached("helper_" + id, func() -> Array: return helper_shapes(id))
	Art.draw_groups(c, groups, pos, scale, 0.0, Color("4a4060"))


static func helper_shapes(id: String) -> Array:
	match id:
		"kit":
			var out := _scaled(tail(0.2, 60, 16), Vector2(8, 22), 1.0)
			out.append([Art.E(Vector2(0, 24), 20, 15, FUR)])
			out.append_array(_scaled(raccoon_head(Vector2(0.3, 0.2), 0.0, Mood.HAPPY), Vector2(0, -6), 0.46))
			return out
		"possum":
			var body := Color("bdb8cc")
			var head := Color("f1ecf7")
			return [
				[Art.L(Art.V([Vector2(-22, 24), Vector2(-38, 22), Vector2(-40, 8), Vector2(-32, 4)]), 5, Art.PINK)],
				[Art.E(Vector2(-4, 18), 26, 17, body)],
				[Art.C(Vector2(-6, -26), 8, MASK), Art.C(Vector2(14, -28), 7, MASK), Art.E(Vector2(4, -10), 20, 17, head), Art.E(Vector2(24, -3), 14, 8, head, 0.2)],
				[Art.C(Vector2(-6, -26), 4, Art.PINK, false), Art.C(Vector2(14, -28), 3.5, Art.PINK, false),
					Art.C(Vector2(8, -13), 3.8, Art.OL, false), Art.C(Vector2(9, -14), 1.3, Art.WHITE, false), Art.C(Vector2(36, 0), 4.5, Art.PINK, false),
					Art.C(Vector2(-2, -4), 3, Color(1, 0.6, 0.7, 0.6), false)],
			]
		"pigeon":
			var feather := Color("9aa7c7")
			return [
				[Art.L(Art.V([Vector2(-4, 28), Vector2(-6, 36)]), 3, Art.ORANGE), Art.L(Art.V([Vector2(8, 28), Vector2(8, 36)]), 3, Art.ORANGE)],
				[Art.P(Art.V([Vector2(-24, 6), Vector2(-42, 16), Vector2(-24, 20)]), Color("7a86a8")),
					Art.E(Vector2(0, 12), 26, 18, feather), Art.C(Vector2(16, -14), 13, feather)],
				[Art.E(Vector2(10, 0), 12, 6, Color("5fd3a8"), -0.5, false), Art.E(Vector2(-6, 12), 16, 9, Color("7a86a8"), -0.2)],
				[Art.P(Art.V([Vector2(27, -16), Vector2(37, -11), Vector2(27, -8)]), Art.ORANGE)],
				[Art.C(Vector2(19, -16), 4, Art.ORANGE, false), Art.C(Vector2(19, -16), 2, Art.OL, false)],
			]
		"cart":
			var grid := []
			for x in [-18, -4, 10]:
				grid.append(Art.L(Art.V([Vector2(x, -18), Vector2(x - 2, 12)]), 2, Art.GRAY, false))
			grid.append(Art.L(Art.V([Vector2(-30, -4), Vector2(26, -4)]), 2, Art.GRAY, false))
			var out := []
			out.append_array(_scaled(raccoon_head(Vector2(-0.5, 0.0), 0.0, Mood.HAPPY), Vector2(12, -30), 0.3))
			out.append([Art.C(Vector2(-12, -24), 12, Color("3a3550"))])
			out.append([Art.L(Art.V([Vector2(30, -20), Vector2(40, -34)]), 4, Art.GRAY_DARK)])
			out.append([Art.P(Art.V([Vector2(-34, -20), Vector2(32, -20), Vector2(22, 14), Vector2(-26, 14)]), Art.GRAY_LIGHT)])
			out.append(grid)
			out.append([Art.C(Vector2(-18, 25), 7, Art.GRAY_DARK), Art.C(Vector2(14, 25), 7, Art.GRAY_DARK)])
			return out
		"truck":
			return [
				[Art.R(Rect2(-40, -24, 52, 40), 6, Color("43a047"))],
				[Art.R(Rect2(10, -12, 30, 28), 6, Color("8bd96b"))],
				[Art.R(Rect2(19, -6, 14, 10), 3, Color("bfefff"), false), Art.R(Rect2(-40, 2, 52, 5), 0, Art.YELLOW, false),
					Art.P(Art.star(Vector2(-14, -10), 8, 3.5, 3), Color("c8ffb0"), false)],
				[Art.C(Vector2(-24, 20), 9, Art.GRAY_DARK), Art.C(Vector2(24, 20), 9, Art.GRAY_DARK)],
				[Art.C(Vector2(-24, 20), 3.5, Art.GRAY_LIGHT, false), Art.C(Vector2(24, 20), 3.5, Art.GRAY_LIGHT, false)],
			]
		"robot":
			return [
				[Art.L(Art.V([Vector2(-24, 2), Vector2(-36, 16)]), 5, Art.GRAY), Art.L(Art.V([Vector2(24, 2), Vector2(36, 16)]), 5, Art.GRAY)],
				[Art.R(Rect2(-24, -6, 48, 34), 8, Color("6fb7ff"))],
				[Art.L(Art.V([Vector2(0, -38), Vector2(0, -48)]), 3, Art.GRAY), Art.C(Vector2(0, -49), 4, Art.RED)],
				[Art.R(Rect2(-20, -38, 40, 28), 9, Art.GRAY_LIGHT)],
				[Art.C(Vector2(-9, -25), 5, Color("5ff0ff"), false), Art.C(Vector2(9, -25), 5, Color("5ff0ff"), false),
					Art.L(Art.V([Vector2(-6, -16), Vector2(6, -16)]), 2.5, Art.GRAY_DARK, false),
					Art.P(Art.star(Vector2(0, 11), 9, 4, 3), Art.GREEN, false)],
			]
		"ufo":
			return [
				[Art.P(Art.V([Vector2(-12, 8), Vector2(12, 8), Vector2(28, 40), Vector2(-28, 40)]), Color(1, 0.95, 0.5, 0.35), false)],
				[Art.E(Vector2(0, -8), 18, 17, Color("bff6ff"))],
				[Art.C(Vector2(0, -8), 8, Art.GREEN, false), Art.C(Vector2(-3, -10), 2.2, Art.OL, false), Art.C(Vector2(3, -10), 2.2, Art.OL, false)],
				[Art.E(Vector2(0, 5), 40, 12, Art.GRAY_LIGHT)],
				[Art.C(Vector2(-24, 6), 3.5, Art.YELLOW, false), Art.C(Vector2(-8, 9), 3.5, Art.PINK, false),
					Art.C(Vector2(8, 9), 3.5, Art.GREEN, false), Art.C(Vector2(24, 6), 3.5, Art.BLUE, false)],
			]
		"wizard":
			var out := _scaled(raccoon_head(Vector2(0, 0.3), 0.0, Mood.HAPPY), Vector2(0, 12), 0.5)
			out.append([Art.P(Art.V([Vector2(-30, -2), Vector2(30, -2), Vector2(6, -46)]), Color("7b4fe0")),
				Art.E(Vector2(0, -2), 34, 6, Color("7b4fe0"))])
			out.append([Art.P(Art.star(Vector2(4, -22), 7, 3), Art.GOLD, false), Art.C(Vector2(-10, -10), 2.5, Art.GOLD, false),
				Art.C(Vector2(14, -8), 2, Art.GOLD, false)])
			return out
		"dragon":
			var scale := Color("49c46b")
			return [
				[Art.P(Art.V([Vector2(-14, -16), Vector2(-26, -40), Vector2(-4, -22)]), Art.CREAM),
					Art.P(Art.V([Vector2(2, -20), Vector2(0, -44), Vector2(14, -22)]), Art.CREAM)],
				[Art.E(Vector2(-4, 18), 22, 18, scale), Art.E(Vector2(-2, -6), 24, 20, scale), Art.E(Vector2(20, 2), 18, 12, scale, 0.15)],
				[Art.E(Vector2(-4, 22), 12, 10, Color("c8f08a"), 0.0, false), Art.C(Vector2(30, -2), 2.5, Art.OL, false),
					Art.L(Art.V([Vector2(8, 10), Vector2(30, 10)]), 2.5, Art.OL, false)],
				[Art.C(Vector2(-4, -12), 7, Art.WHITE)],
				[Art.C(Vector2(-2, -12), 3.8, Art.OL, false)],
				[Art.P(Art.blob(Vector2(44, 0), 7, 2, 5), Color(1, 0.6, 0.2, 0.9), false)],
			]
	return [[Art.C(Vector2.ZERO, 20, Art.GRAY)]]
