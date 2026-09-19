extends Node3D

# ==================== 配置 ====================
const MAP_HALF = 50.0         # 地图半边长（围墙位置）
const WALL_HEIGHT = 7.0       # 围墙高度
const WALL_THICKNESS = 1.5    # 围墙厚度
const SEG_LEN = 3.0           # 每块墙砖长度
const GATE_WIDTH = 10.0       # 大门宽度
const GATE_HEIGHT = 6.0       # 大门高度
const MOUNTAIN_SINK = 1.5     # 山体下沉深度（避免悬空）

func _ready():
	# ⭐ 不用额外地面，避免和主地面 Z-fighting
	build_walls()
	build_gate()
	build_mountains()

# ==================== 围墙 ====================
func build_walls():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.38)
	mat.roughness = 0.95
	
	var mat2 = StandardMaterial3D.new()
	mat2.albedo_color = Color(0.35, 0.32, 0.3)
	mat2.roughness = 0.95
	
	# 北墙 (+Z)：中间留门洞
	build_wall_x(MAP_HALF, -MAP_HALF, -GATE_WIDTH/2, mat, mat2)
	build_wall_x(MAP_HALF, GATE_WIDTH/2, MAP_HALF, mat, mat2)
	
	# 南墙 (-Z)：完整
	build_wall_x(-MAP_HALF, -MAP_HALF, MAP_HALF, mat, mat2)
	
	# 东墙 (+X)：完整
	build_wall_z(MAP_HALF, -MAP_HALF, MAP_HALF, mat, mat2)
	
	# 西墙 (-X)：完整
	build_wall_z(-MAP_HALF, -MAP_HALF, MAP_HALF, mat, mat2)

# 沿 X 轴建一段墙（固定 z 位置）
func build_wall_x(z_pos: float, x_start: float, x_end: float, mat: Material, mat2: Material):
	var length = x_end - x_start
	if length <= 0.1:
		return
	var seg_count = int(ceil(length / SEG_LEN))
	var actual_seg = length / seg_count
	
	for i in range(seg_count):
		var x = x_start + actual_seg * (i + 0.5)
		var seg_h = WALL_HEIGHT * randf_range(0.92, 1.08)
		
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(actual_seg * 0.98, seg_h, WALL_THICKNESS)
		seg.mesh = box
		seg.material_override = mat if i % 3 != 2 else mat2
		seg.position = Vector3(x, seg_h / 2, z_pos)
		add_child(seg)
		
		# 碰撞
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		col.position = seg.position
		body.add_child(col)
		add_child(body)

# 沿 Z 轴建一段墙（固定 x 位置）
func build_wall_z(x_pos: float, z_start: float, z_end: float, mat: Material, mat2: Material):
	var length = z_end - z_start
	if length <= 0.1:
		return
	var seg_count = int(ceil(length / SEG_LEN))
	var actual_seg = length / seg_count
	
	for i in range(seg_count):
		var z = z_start + actual_seg * (i + 0.5)
		var seg_h = WALL_HEIGHT * randf_range(0.92, 1.08)
		
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(WALL_THICKNESS, seg_h, actual_seg * 0.98)
		seg.mesh = box
		seg.material_override = mat if i % 3 != 2 else mat2
		seg.position = Vector3(x_pos, seg_h / 2, z)
		add_child(seg)
		
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = box.size
		col.shape = shape
		col.position = seg.position
		body.add_child(col)
		add_child(body)

# ==================== 大门 ====================
func build_gate():
	# --- 门框 ---
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.25, 0.22, 0.2)
	frame_mat.roughness = 0.85
	
	# 左门柱
	add_box(Vector3(1.2, GATE_HEIGHT, 1.8), 
		Vector3(-GATE_WIDTH/2 - 0.6, GATE_HEIGHT/2, MAP_HALF), frame_mat)
	# 右门柱
	add_box(Vector3(1.2, GATE_HEIGHT, 1.8), 
		Vector3(GATE_WIDTH/2 + 0.6, GATE_HEIGHT/2, MAP_HALF), frame_mat)
	# 横梁
	add_box(Vector3(GATE_WIDTH + 2.4, 1.0, 1.8), 
		Vector3(0, GATE_HEIGHT + 0.5, MAP_HALF), frame_mat)
	
	# --- 门板（左右两扇） ---
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.35, 0.22, 0.12)
	door_mat.roughness = 0.7
	
	# 左门板
	add_box(Vector3(GATE_WIDTH/2 - 0.1, GATE_HEIGHT - 0.3, 0.35),
		Vector3(-GATE_WIDTH/4, (GATE_HEIGHT - 0.3) / 2, MAP_HALF), door_mat)
	# 右门板
	add_box(Vector3(GATE_WIDTH/2 - 0.1, GATE_HEIGHT - 0.3, 0.35),
		Vector3(GATE_WIDTH/4, (GATE_HEIGHT - 0.3) / 2, MAP_HALF), door_mat)
	
	# --- 门板上的铁钉装饰 ---
	var rivet_mat = StandardMaterial3D.new()
	rivet_mat.albedo_color = Color(0.15, 0.15, 0.18)
	rivet_mat.metallic = 0.9
	rivet_mat.roughness = 0.4
	
	for row in range(4):
		var y = 1.0 + row * 1.2
		for col in range(3):
			var offset = (col - 1) * 1.2
			# 左门钉
			var rl = MeshInstance3D.new()
			var sp = SphereMesh.new()
			sp.radius = 0.1
			sp.height = 0.2
			rl.mesh = sp
			rl.material_override = rivet_mat
			rl.position = Vector3(-GATE_WIDTH/4 + offset, y, MAP_HALF - 0.22)
			add_child(rl)
			# 右门钉
			var rr = MeshInstance3D.new()
			rr.mesh = sp
			rr.material_override = rivet_mat
			rr.position = Vector3(GATE_WIDTH/4 + offset, y, MAP_HALF - 0.22)
			add_child(rr)
	
	# --- 门上的文字 "dewrb" ---
	var text_label = Label3D.new()
	text_label.text = "dewrb"
	text_label.font_size = 256
	text_label.pixel_size = 0.014
	text_label.position = Vector3(0, GATE_HEIGHT * 0.55, MAP_HALF - 0.25)
	text_label.rotation = Vector3(0, PI, 0)
	text_label.modulate = Color(0.95, 0.95, 1.0)
	text_label.outline_size = 24
	text_label.outline_modulate = Color(0, 0, 0)
	text_label.shaded = false
	text_label.no_depth_test = false
	add_child(text_label)
	
	# --- 门上方匾额 ---
	var plaque_mat = StandardMaterial3D.new()
	plaque_mat.albedo_color = Color(0.6, 0.5, 0.2)
	plaque_mat.metallic = 0.5
	plaque_mat.roughness = 0.5
	add_box(Vector3(GATE_WIDTH - 1.0, 0.15, 1.9), 
		Vector3(0, GATE_HEIGHT - 0.2, MAP_HALF), plaque_mat)

# 辅助：加一个方块（视觉 + 碰撞）
func add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)
	add_child(body)
	
	return mi

# ==================== 山脉 ====================
func build_mountains():
	var mat1 = StandardMaterial3D.new()
	mat1.albedo_color = Color(0.22, 0.2, 0.18)
	mat1.roughness = 1.0
	
	var mat2 = StandardMaterial3D.new()
	mat2.albedo_color = Color(0.3, 0.28, 0.25)
	mat2.roughness = 1.0
	
	var mat3 = StandardMaterial3D.new()
	mat3.albedo_color = Color(0.15, 0.14, 0.13)
	mat3.roughness = 1.0
	
	var mats = [mat1, mat2, mat3]
	
	spawn_range("north", mats)
	spawn_range("south", mats)
	spawn_range("east", mats)
	spawn_range("west", mats)

func spawn_range(direction: String, mats: Array):
	var base_offset = MAP_HALF + 10.0
	var range_len = 100.0
	var count = 18
	
	for i in range(count):
		var t = (i / float(count - 1)) - 0.5
		var along = t * range_len + randf_range(-3.0, 3.0)
		var outward = randf_range(6.0, 40.0)
		var h = randf_range(10.0, 25.0)
		var r = h * randf_range(0.6, 1.0)
		
		var pos = Vector3.ZERO
		match direction:
			"north": pos = Vector3(along, 0, base_offset + outward)
			"south": pos = Vector3(along, 0, -(base_offset + outward))
			"east":  pos = Vector3(base_offset + outward, 0, along)
			"west":  pos = Vector3(-(base_offset + outward), 0, along)
		
		# ⭐ 主体山锥（下沉，避免底部悬空）
		var mountain = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = r
		cyl.height = h
		cyl.radial_segments = 6
		mountain.mesh = cyl
		mountain.material_override = mats[randi() % mats.size()]
		# 下沉 MOUNTAIN_SINK 米，让山底埋在地面下
		mountain.position = pos + Vector3(0, h / 2 - MOUNTAIN_SINK, 0)
		mountain.rotation.y = randf() * TAU
		add_child(mountain)
		
		# 碰撞（可选）
		var body = StaticBody3D.new()
		var col = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = r * 0.9
		shape.height = h
		col.shape = shape
		col.position = mountain.position
		body.add_child(col)
		add_child(body)
		
		# 山顶雪（30% 概率）
		if randf() < 0.3:
			var snow = MeshInstance3D.new()
			var snow_mesh = SphereMesh.new()
			snow_mesh.radius = r * 0.3
			snow_mesh.height = r * 0.5
			snow.mesh = snow_mesh
			var snow_mat = StandardMaterial3D.new()
			snow_mat.albedo_color = Color(0.9, 0.92, 0.95)
			snow_mat.roughness = 0.7
			snow.material_override = snow_mat
			snow.position = pos + Vector3(0, h * 0.9 - MOUNTAIN_SINK, 0)
			add_child(snow)