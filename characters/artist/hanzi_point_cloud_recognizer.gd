class_name HanziPointCloudRecognizer
extends RefCounted

# $P Point-Cloud Recognizer (Vatavu, Anthony, Wobbrock 2012)
# Robust stroke-order, stroke-number, and stroke-direction invariant gesture recognizer.

const SAMPLING_POINTS: int = 32

class PointCloudTemplate extends RefCounted:
	var name: String = ""
	var hanzi: String = ""
	var points: Array[Vector2] = []

	func _init(p_name: String, p_hanzi: String, p_points: Array[Vector2]) -> void:
		name = p_name
		hanzi = p_hanzi
		points = p_points

static var _templates: Array[PointCloudTemplate] = []
static var _initialized: bool = false

static func _ensure_templates() -> void:
	if _initialized:
		return
	_initialized = true

	# 1. 火 (Fire)
	# Left dot, right slant, center curved down-left, right falling
	var fire_strokes: Array = [
		[Vector2(0.25, 0.35), Vector2(0.32, 0.48)],
		[Vector2(0.75, 0.35), Vector2(0.68, 0.48)],
		[Vector2(0.50, 0.15), Vector2(0.50, 0.42), Vector2(0.35, 0.70), Vector2(0.18, 0.90)],
		[Vector2(0.48, 0.45), Vector2(0.65, 0.68), Vector2(0.85, 0.90)]
	]
	_templates.append(PointCloudTemplate.new("fire", "火", normalize_strokes(fire_strokes)))

	# 2. 水 (Water)
	# Center vertical hook, left horizontal-turn, right falling
	var water_strokes: Array = [
		[Vector2(0.50, 0.10), Vector2(0.50, 0.85), Vector2(0.42, 0.78)],
		[Vector2(0.20, 0.38), Vector2(0.38, 0.38), Vector2(0.22, 0.65)],
		[Vector2(0.65, 0.28), Vector2(0.82, 0.78)]
	]
	_templates.append(PointCloudTemplate.new("water", "水", normalize_strokes(water_strokes)))

	# 3. 风 (Air / Wind)
	# Left vertical, top-right frame hook, inner slants
	var air_strokes: Array = [
		[Vector2(0.20, 0.15), Vector2(0.20, 0.85)],
		[Vector2(0.20, 0.15), Vector2(0.80, 0.15), Vector2(0.80, 0.80), Vector2(0.70, 0.75)],
		[Vector2(0.35, 0.40), Vector2(0.65, 0.70)],
		[Vector2(0.55, 0.42), Vector2(0.42, 0.65)]
	]
	_templates.append(PointCloudTemplate.new("air", "风", normalize_strokes(air_strokes)))

	# 4. 土 (Earth)
	# Top horizontal, center vertical, bottom wide horizontal
	var earth_strokes: Array = [
		[Vector2(0.30, 0.40), Vector2(0.70, 0.40)],
		[Vector2(0.50, 0.15), Vector2(0.50, 0.85)],
		[Vector2(0.15, 0.85), Vector2(0.85, 0.85)]
	]
	_templates.append(PointCloudTemplate.new("earth", "土", normalize_strokes(earth_strokes)))

# Recognizes a drawn gesture (array of stroke point arrays)
# Returns Dictionary: { "element": String, "hanzi": String, "score": float, "distance": float }
static func recognize(strokes: Array) -> Dictionary:
	_ensure_templates()

	var normalized_points = normalize_strokes(strokes)
	if normalized_points.is_empty():
		return {"element": "", "hanzi": "", "score": 0.0, "distance": 999999.0}

	var best_dist: float = 999999.0
	var best_template: PointCloudTemplate = null

	for t in _templates:
		var dist = _greedy_cloud_match(normalized_points, t.points)
		if dist < best_dist:
			best_dist = dist
			best_template = t

	if best_template:
		var score = clampf(1.0 - (best_dist / 0.70), 0.0, 1.0)
		return {
			"element": best_template.name,
			"hanzi": best_template.hanzi,
			"score": score,
			"distance": best_dist
		}

	return {"element": "", "hanzi": "", "score": 0.0, "distance": 999999.0}

# Converts array of strokes into a single normalized point cloud of SAMPLING_POINTS points
static func normalize_strokes(strokes: Array) -> Array[Vector2]:
	var flat_points: Array[Vector2] = []
	for stroke in strokes:
		if stroke is Array:
			for pt in stroke:
				if pt is Vector2:
					flat_points.append(pt)

	if flat_points.size() < 2:
		return []

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
