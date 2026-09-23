class_name HanziPointCloudRecognizer
extends RefCounted

# $P Point-Cloud Recognizer (Vatavu, Anthony, Wobbrock 2012)
# Robust stroke-order, stroke-number, and stroke-direction invariant gesture recognizer.

const SAMPLING_POINTS: int = 32

const ELEMENT_HANZI: Dictionary = {
	"fire": "火",
	"water": "水",
	"air": "风",
	"earth": "土"
}

class PointCloudTemplate extends RefCounted:
	var name: String = ""
	var hanzi: String = ""
	var stroke_count: int = -1 # -1 for full / any, or 1, 2, 3, 4
	var points: Array[Vector2] = []
	var unit_centroid: Vector2 = Vector2(0.5, 0.5)
	var is_full: bool = false

	func _init(p_name: String, p_hanzi: String, p_points: Array[Vector2], p_stroke_count: int = -1, p_centroid: Vector2 = Vector2(0.5, 0.5), p_is_full: bool = false) -> void:
		name = p_name
		hanzi = p_hanzi
		points = p_points
		stroke_count = p_stroke_count
		unit_centroid = p_centroid
		is_full = p_is_full

static var _templates: Array[PointCloudTemplate] = []
static var _initialized: bool = false

static func _compute_raw_centroid(strokes: Array) -> Vector2:
	var sum = Vector2.ZERO
	var count = 0
	for stroke in strokes:
		if stroke is Array:
			for pt in stroke:
				if pt is Vector2:
					sum += pt
					count += 1
	if count > 0:
		return sum / float(count)
	return Vector2(0.5, 0.5)

static func _make_template(p_name: String, p_hanzi: String, strokes: Array, p_stroke_count: int = -1, p_is_full: bool = false) -> PointCloudTemplate:
	var norm_pts = normalize_strokes(strokes)
	var centroid = _compute_raw_centroid(strokes)
	return PointCloudTemplate.new(p_name, p_hanzi, norm_pts, p_stroke_count, centroid, p_is_full)

static func _ensure_templates() -> void:
	if _initialized:
		return
	_initialized = true

	# =========================================================
	# 1. 火 (Fire)
	# Strokes:
	#   1: Left dot (丶) dipping down-right
	#   2: Right slant/dot (丿) dipping down-left
	#   3: Center curved sweep down to bottom-left
	#   4: Right falling sweep (乀) down to bottom-right
	# =========================================================
	var fire_s1 = [Vector2(0.25, 0.35), Vector2(0.32, 0.48)]
	var fire_s2 = [Vector2(0.75, 0.35), Vector2(0.68, 0.48)]
	var fire_s3 = [Vector2(0.50, 0.15), Vector2(0.50, 0.42), Vector2(0.35, 0.70), Vector2(0.18, 0.90)]
	var fire_s4 = [Vector2(0.48, 0.45), Vector2(0.65, 0.68), Vector2(0.85, 0.90)]

	# 1 stroke: left dot OR center sweep
	_templates.append(_make_template("fire", "火", [fire_s1], 1, false))
	_templates.append(_make_template("fire", "火", [fire_s3], 1, false))
	# 2 strokes: two dots OR center + right sweep
	_templates.append(_make_template("fire", "火", [fire_s1, fire_s2], 2, false))
	_templates.append(_make_template("fire", "火", [fire_s3, fire_s4], 2, false))
	# 3 strokes: two dots + center sweep
	_templates.append(_make_template("fire", "火", [fire_s1, fire_s2, fire_s3], 3, false))
	_templates.append(_make_template("fire", "火", [fire_s3, fire_s4, fire_s1], 3, false))
	# 4 strokes (Full)
	_templates.append(_make_template("fire", "火", [fire_s1, fire_s2, fire_s3, fire_s4], 4, true))

	# =========================================================
	# 2. 水 (Water)
	# Strokes:
	#   1: Center vertical hook (亅)
	#   2: Left horizontal-turn hook (㇇)
	#   3: Right slants / sweep (乀)
	# =========================================================
	var water_s1 = [Vector2(0.50, 0.10), Vector2(0.50, 0.85), Vector2(0.42, 0.78)]
	var water_s2 = [Vector2(0.20, 0.38), Vector2(0.38, 0.38), Vector2(0.22, 0.65)]
	var water_s3 = [Vector2(0.65, 0.28), Vector2(0.82, 0.78)]

	# 1 stroke: center vertical hook
	_templates.append(_make_template("water", "水", [water_s1], 1, false))
	# 2 strokes: vertical hook + left turn
	_templates.append(_make_template("water", "水", [water_s1, water_s2], 2, false))
	_templates.append(_make_template("water", "水", [water_s1, water_s3], 2, false))
	# 3 strokes (Full)
	_templates.append(_make_template("water", "水", [water_s1, water_s2, water_s3], 3, true))

	# =========================================================
	# 3. 风 (Air / Wind)
	# Strokes:
	#   1: Left vertical / downward curve (丿/丨)
	#   2: Top horizontal + right vertical frame + hook (𠃍/𠃌)
	#   3: Inner slant (丿)
	#   4: Inner cross/dot (丶)
	# =========================================================
	var air_s1 = [Vector2(0.20, 0.15), Vector2(0.20, 0.85)]
	var air_s2 = [Vector2(0.20, 0.15), Vector2(0.80, 0.15), Vector2(0.80, 0.80), Vector2(0.70, 0.75)]
	var air_s3 = [Vector2(0.35, 0.40), Vector2(0.65, 0.70)]
	var air_s4 = [Vector2(0.55, 0.42), Vector2(0.42, 0.65)]

	# 1 stroke: left vertical
	_templates.append(_make_template("air", "风", [air_s1], 1, false))
	# 2 strokes: left vertical + top/right frame
	_templates.append(_make_template("air", "风", [air_s1, air_s2], 2, false))
	# 3 strokes: frame + inner slant
	_templates.append(_make_template("air", "风", [air_s1, air_s2, air_s3], 3, false))
	# 4 strokes (Full)
	_templates.append(_make_template("air", "风", [air_s1, air_s2, air_s3, air_s4], 4, true))

	# =========================================================
	# 4. 土 (Earth)
	# Strokes:
	#   1: Top horizontal (一)
	#   2: Center vertical (丨)
	#   3: Bottom wide horizontal (一)
	# =========================================================
	var earth_s1 = [Vector2(0.30, 0.40), Vector2(0.70, 0.40)]
	var earth_s2 = [Vector2(0.50, 0.15), Vector2(0.50, 0.85)]
	var earth_s3 = [Vector2(0.15, 0.85), Vector2(0.85, 0.85)]

	# 1 stroke: top horizontal OR center vertical
	_templates.append(_make_template("earth", "土", [earth_s1], 1, false))
	_templates.append(_make_template("earth", "土", [earth_s2], 1, false))
	# 2 strokes: top horizontal + center vertical
	_templates.append(_make_template("earth", "土", [earth_s1, earth_s2], 2, false))
	_templates.append(_make_template("earth", "土", [earth_s2, earth_s3], 2, false))
	# 3 strokes (Full)
	_templates.append(_make_template("earth", "土", [earth_s1, earth_s2, earth_s3], 3, true))

# Converts strokes into [0, 1] unit coordinates relative to canvas
static func to_canvas_unit_strokes(strokes: Array, canvas_rect: Rect2) -> Array:
	if canvas_rect.size.x > 0.0 and canvas_rect.size.y > 0.0:
		var unit_strokes: Array = []
		for stroke in strokes:
			if stroke is Array:
				var u_stroke: Array[Vector2] = []
				for pt in stroke:
					if pt is Vector2:
						var u_pt = (pt - canvas_rect.position) / canvas_rect.size
						u_stroke.append(u_pt.clamp(Vector2.ZERO, Vector2.ONE))
				unit_strokes.append(u_stroke)
		return unit_strokes

	# Check if coordinates are in pixel space (> 2.0)
	var max_coord = 0.0
	for s in strokes:
		if s is Array:
			for p in s:
				if p is Vector2:
					max_coord = maxf(max_coord, maxf(p.x, p.y))

	if max_coord > 2.0:
		var min_p = Vector2(999999, 999999)
		var max_p = Vector2(-999999, -999999)
		for s in strokes:
			if s is Array:
				for p in s:
					if p is Vector2:
						min_p.x = minf(min_p.x, p.x)
						min_p.y = minf(min_p.y, p.y)
						max_p.x = maxf(max_p.x, p.x)
						max_p.y = maxf(max_p.y, p.y)
		var sz = maxf(max_p.x - min_p.x, max_p.y - min_p.y)
		sz = maxf(sz, 1.0)
		var u_strokes: Array = []
		for s in strokes:
			if s is Array:
				var u_s: Array[Vector2] = []
				for p in s:
					if p is Vector2:
						u_s.append((p - min_p) / sz)
				u_strokes.append(u_s)
		return u_strokes

	return strokes

# Recognizes a drawn gesture (array of stroke point arrays)
# Returns Dictionary:
#   { "element": String, "hanzi": String, "score": float, "distance": float, "stroke_count": int, "candidates": Array }
static func recognize(strokes: Array, canvas_rect: Rect2 = Rect2()) -> Dictionary:
	_ensure_templates()

	if strokes.is_empty():
		return {
			"element": "",
			"hanzi": "",
			"score": 0.0,
			"distance": 999999.0,
			"stroke_count": 0,
			"candidates": []
		}

	var unit_strokes = to_canvas_unit_strokes(strokes, canvas_rect)
	var normalized_points = normalize_strokes(unit_strokes)
	if normalized_points.is_empty():
		return {
			"element": "",
			"hanzi": "",
			"score": 0.0,
			"distance": 999999.0,
			"stroke_count": strokes.size(),
			"candidates": []
		}

	var stroke_count = strokes.size()
	var user_centroid = _compute_raw_centroid(unit_strokes)

	var element_scores: Dictionary = {}
	var element_distances: Dictionary = {}

	# For each of the 4 elements, find the closest matching template among:
	# 1. Templates matching current stroke count (stroke-by-stroke progressive check)
	# 2. Full templates (in case user completed character in fewer/more strokes)
	for elem in ["fire", "water", "air", "earth"]:
		var min_dist = 999999.0

		for t in _templates:
			if t.name != elem:
				continue

			if t.stroke_count != stroke_count and not t.is_full:
				continue

			var shape_dist = _greedy_cloud_match(normalized_points, t.points)
			var centroid_dist = user_centroid.distance_to(t.unit_centroid)

			# Centroid weighting to distinguish spatially distinct strokes (e.g. left vs center)
			var total_dist = shape_dist + centroid_dist * 0.35

			if total_dist < min_dist:
				min_dist = total_dist

		element_distances[elem] = min_dist
		# Significantly reduced distance penalty threshold (from 0.65 to 1.15) for much more forgiving recognition
		var score = clampf(1.0 - (min_dist / 1.15), 0.0, 1.0)
		element_scores[elem] = score

	# Candidate ranking list sorted by match confidence
	var candidates: Array = []
	for elem in ["fire", "water", "air", "earth"]:
		candidates.append({
			"element": elem,
			"hanzi": ELEMENT_HANZI[elem],
			"score": element_scores[elem],
			"distance": element_distances[elem]
		})

	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var best = candidates[0]
	return {
		"element": best["element"],
		"hanzi": best["hanzi"],
		"score": best["score"],
		"distance": best["distance"],
		"stroke_count": stroke_count,
		"candidates": candidates
	}

# Converts array of strokes into a single normalized point cloud of SAMPLING_POINTS points
static func normalize_strokes(strokes: Array) -> Array[Vector2]:
	var flat_points: Array[Vector2] = []
	for stroke in strokes:
		if stroke is Array:
			for pt in stroke:
				if pt is Vector2:
					flat_points.append(pt)

	if flat_points.is_empty():
		return []

	# If single point (tap/dot), duplicate so it is resamplable
	if flat_points.size() == 1:
		flat_points.append(flat_points[0] + Vector2(0.005, 0.005))

	# 1. Resample to SAMPLING_POINTS
	var resampled = _resample(flat_points, SAMPLING_POINTS)

	# 2. Scale uniformly preserving aspect ratio
	var scaled = _scale_aspect(resampled)

	# 3. Translate centroid to origin (0, 0)
	var translated = _translate_to_origin(scaled)

	return translated

static func _resample(points: Array[Vector2], n: int) -> Array[Vector2]:
	var total_len: float = 0.0
	for i in range(points.size() - 1):
		total_len += points[i].distance_to(points[i + 1])

	if total_len <= 0.0001:
		var dup: Array[Vector2] = []
		for i in range(n):
			dup.append(points[0])
		return dup

	var interval = total_len / float(n - 1)
	var resampled: Array[Vector2] = [points[0]]
	var dist_accum: float = 0.0

	var i: int = 0
	var curr_pt = points[0]

	while i < points.size() - 1:
		var next_pt = points[i + 1]
		var seg_dist = curr_pt.distance_to(next_pt)

		if (dist_accum + seg_dist) >= interval:
			var t = (interval - dist_accum) / maxf(seg_dist, 0.0001)
			curr_pt = curr_pt.lerp(next_pt, t)
			resampled.append(curr_pt)
			dist_accum = 0.0
			if resampled.size() == n:
				break
		else:
			dist_accum += seg_dist
			curr_pt = next_pt
			i += 1

	while resampled.size() < n:
		resampled.append(points[points.size() - 1])

	return resampled

static func _scale_aspect(points: Array[Vector2]) -> Array[Vector2]:
	var min_x = points[0].x
	var max_x = points[0].x
	var min_y = points[0].y
	var max_y = points[0].y

	for pt in points:
		min_x = minf(min_x, pt.x)
		max_x = maxf(max_x, pt.x)
		min_y = minf(min_y, pt.y)
		max_y = maxf(max_y, pt.y)

	var w = maxf(max_x - min_x, 0.0001)
	var h = maxf(max_y - min_y, 0.0001)
	var scale_factor = maxf(w, h)

	var scaled: Array[Vector2] = []
	for pt in points:
		scaled.append(Vector2(
			(pt.x - min_x) / scale_factor,
			(pt.y - min_y) / scale_factor
		))
	return scaled

static func _translate_to_origin(points: Array[Vector2]) -> Array[Vector2]:
	var centroid = Vector2.ZERO
	for pt in points:
		centroid += pt
	centroid /= float(points.size())

	var translated: Array[Vector2] = []
	for pt in points:
		translated.append(pt - centroid)
	return translated

# Bidirectional greedy cloud matching
static func _greedy_cloud_match(pts1: Array[Vector2], pts2: Array[Vector2]) -> float:
	var n = pts1.size()
	if n == 0 or pts2.size() == 0:
		return 999999.0

	var sum_dist: float = 0.0

	# 1 -> 2
	for p1 in pts1:
		var min_d = 999999.0
		for p2 in pts2:
			var d = p1.distance_squared_to(p2)
			if d < min_d:
				min_d = d
		sum_dist += sqrt(min_d)

	# 2 -> 1
	for p2 in pts2:
		var min_d = 999999.0
		for p1 in pts1:
			var d = p2.distance_squared_to(p1)
			if d < min_d:
				min_d = d
		sum_dist += sqrt(min_d)

	return sum_dist / float(2 * n)
