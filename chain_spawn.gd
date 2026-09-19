extends Node3D

# 配置
const SPAWN_WAIT = 30.0
const CHAIN_SPAWN_DELAY = 5.0
const FADE_IN_DUR = 1.5
const FADE_OUT_DUR = 2.0
const LOW_BRIGHTNESS = 0.3
const HIGH_BRIGHTNESS = 4.0

var spawn_timer = 0.0
var phase = 0
var circle_glow_mat: StandardMaterial3D
var rune_mats: Array = []
var circle_light: OmniLight3D = null
var chain_ref: Node3D = null

func _ready():
	build_ground()
	build_pillars()
	build_rocks()
	build_magic_circle()
	await get_tree().process_frame
	chain_ref = get_parent().get_node_or_null("Chain")
	# ⭐ Chain 藏到地底，血条隐藏
	if chain_ref:
		if chain_ref.has_method("deactivate"):
			chain_ref.deactivate()

func _process(delta):
	if phase >= 2:
		return
	spawn_timer += delta
	
	if phase == 0 and spawn_timer >= SPAWN_WAIT:
		phase = 1
		print("[ChainSpawn] 法阵开始变亮")
		start_circle_glow()
	
	if phase == 1 and spawn_timer >= SPAWN_WAIT + CHAIN_SPAWN_DELAY:
		phase = 2
		print("[ChainSpawn] Chain 出生！")
		spawn_chain()

# ==================== 地面 ====================
func build_ground():
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.22, 0.2)
	mat.roughness = 1.0
	var base = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(20, 0.3, 20)
	base.mesh = box
	base.material_override = mat
	base.position.y = -0.15
	add_child(base)
	
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(20, 0.3, 20)
	col.shape = shape
	col.position.y = -0.15
	body.add_child(col)
	add_child(body)

# ==================== 斜石柱 ====================
func build_pillars():
	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.35, 0.33, 0.3)
	stone_mat.roughness = 0.95
	
	var stone_mat2 = StandardMaterial3D.new()
	stone_mat2.albedo_color = Color(0.28, 0.26, 0.24)
	stone_mat2.roughness = 0.95
	
	# 左侧斜柱
	var left = Node3D.new()
	left.position = Vector3(-4.5, 0, 0)
	left.rotation.z = -0.35
	add_child(left)
	
	for i in range(3):
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		var w = 1.2 - i * 0.15
		box.size = Vector3(w, 1.8, w)
		seg.mesh = box
		seg.material_override = stone_mat if i % 2 == 0 else stone_mat2
		seg.position.y = 0.9 + i * 1.7
		left.add_child(seg)
	
	var lbody = StaticBody3D.new()
	var lcol = CollisionShape3D.new()
	var lbox = BoxShape3D.new()
	lbox.size = Vector3(1.5, 6.0, 1.5)
	lcol.shape = lbox
	lcol.position.y = 3.0
	lbody.add_child(lcol)
	left.add_child(lbody)
	
	# 右侧斜柱
	var right = Node3D.new()
	right.position = Vector3(4.5, 0, 0)
	right.rotation.z = 0.35
	add_child(right)
	
	for i in range(3):
		var seg = MeshInstance3D.new()
		var box = BoxMesh.new()
		var w = 1.2 - i * 0.15
		box.size = Vector3(w, 1.8, w)
		seg.mesh = box
		seg.material_override = stone_mat if i % 2 == 0 else stone_mat2
		seg.position.y = 0.9 + i * 1.7
		right.add_child(seg)
	
	var rbody = StaticBody3D.new()
	var rcol = CollisionShape3D.new()
	var rbox = BoxShape3D.new()
	rbox.size = Vector3(1.5, 6.0, 1.5)
	rcol.shape = rbox
	rcol.position.y = 3.0
	rbody.add_child(rcol)
	right.add_child(rbody)

# ==================== 石块 ====================
func build_rocks():
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.3, 0.28, 0.26)
	rock_mat.roughness = 1.0
	
	for i in range(25):
		var rock = MeshInstance3D.new()
		var box = BoxMesh.new()
		var s = randf_range(0.6, 1.8)
		box.size = Vector3(s, s * randf_range(0.5, 1.2), s)
		rock.mesh = box
		rock.material_override = rock_mat
		var angle = randf() * TAU
		var dist = randf_range(6.0, 9.5)
		rock.position = Vector3(cos(angle) * dist, s * 0.4, sin(angle) * dist)
		rock.rotation = Vector3(randf() * 0.3, randf() * TAU, randf() * 0.3)
		add_child(rock)
		
		var rb = StaticBody3D.new()
		var rc = CollisionShape3D.new()
		var rsh = BoxShape3D.new()
		rsh.size = box.size
		rc.shape = rsh
		rc.position = rock.position
		rb.add_child(rc)
		add_child(rb)

# ==================== 法阵 ====================
func build_magic_circle():
	var disc_mat = StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.15, 0.05, 0.15, 0.85)
	disc_mat.emission_enabled = true
	disc_mat.emission = Color(0.6, 0.2, 1.0)
	disc_mat.emission_energy_multiplier = LOW_BRIGHTNESS
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	circle_glow_mat = disc_mat
	
	var disc = MeshInstance3D.new()
	var dm = CylinderMesh.new()
	dm.top_radius = 4.0
	dm.bottom_radius = 4.0
	dm.height = 0.05
	disc.mesh = dm
	disc.material_override = disc_mat
	disc.position.y = 0.03
	add_child(disc)
	
	# 内圈
	var inner_mat = StandardMaterial3D.new()
	inner_mat.albedo_color = Color(0.05, 0.02, 0.05)
	inner_mat.emission_enabled = true
	inner_mat.emission = Color(0.4, 0.1, 0.8)
	inner_mat.emission_energy_multiplier = LOW_BRIGHTNESS
	rune_mats.append(inner_mat)
	
	var inner = MeshInstance3D.new()
	var im = CylinderMesh.new()
	im.top_radius = 3.0
	im.bottom_radius = 3.0
	im.height = 0.07
	inner.mesh = im
	inner.material_override = inner_mat
	inner.position.y = 0.035
	add_child(inner)
	
	# 外环
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.6, 0.3, 1.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.6, 0.3, 1.0)
	ring_mat.emission_energy_multiplier = LOW_BRIGHTNESS
	rune_mats.append(ring_mat)
	
	var ring = MeshInstance3D.new()
	var t = TorusMesh.new()
	t.inner_radius = 3.7
	t.outer_radius = 3.9
	ring.mesh = t
	ring.material_override = ring_mat
	ring.position.y = 0.08
	add_child(ring)
	
	# 希腊字符
	var greek = "α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω"
	var chars = greek.split(" ")
	var cnt = chars.size()
	
	for i in range(cnt):
		var lbl = Label3D.new()
		lbl.text = chars[i]
		lbl.font_size = 96
		lbl.pixel_size = 0.006
		lbl.no_depth_test = true
		lbl.shaded = false
		lbl.double_sided = true
		
		var lbl_mat = StandardMaterial3D.new()
		lbl_mat.albedo_color = Color(0.8, 0.5, 1.0)
		lbl_mat.emission_enabled = true
		lbl_mat.emission = Color(0.7, 0.3, 1.0)
		lbl_mat.emission_energy_multiplier = LOW_BRIGHTNESS
		lbl.material_override = lbl_mat
		rune_mats.append(lbl_mat)
		
		var a = (i / float(cnt)) * TAU
		lbl.position = Vector3(cos(a) * 3.4, 0.12, sin(a) * 3.4)
		lbl.rotation = Vector3(-PI/2, 0, 0)
		lbl.rotate_y(-a)
		add_child(lbl)
	
	# 中心光
	circle_light = OmniLight3D.new()
	circle_light.light_color = Color(0.7, 0.3, 1.0)
	circle_light.light_energy = 0.8
	circle_light.omni_range = 12.0
	circle_light.position = Vector3(0, 1.5, 0)
	add_child(circle_light)

# ==================== 亮度动画 ====================
func start_circle_glow():
	var tween = create_tween()
	tween.tween_method(_set_brightness, LOW_BRIGHTNESS, HIGH_BRIGHTNESS, FADE_IN_DUR)
	tween.tween_interval(0.3)
	tween.tween_method(_set_brightness, HIGH_BRIGHTNESS, LOW_BRIGHTNESS, FADE_OUT_DUR)

func _set_brightness(v: float):
	for m in rune_mats:
		if m:
			m.emission_energy_multiplier = v
	if circle_glow_mat:
		circle_glow_mat.emission_energy_multiplier = v
	if circle_light:
		circle_light.light_energy = v * 2.5

# ==================== 生成 Chain ====================
func spawn_chain():
	if not chain_ref:
		print("⚠ 没找到 Chain 节点")
		return
	# ⭐ 传送到法阵中心
	chain_ref.global_position = global_position
	chain_ref.global_position.y = 0
	# ⭐ 激活 Chain
	if chain_ref.has_method("activate"):
		chain_ref.activate()
	print("[ChainSpawn] Chain 已传送并激活，位置：", chain_ref.global_position)
