extends Node3D

# ==================== 安全屋配置 ====================
const HOUSE_SIZE = 8.0
const HOUSE_HEIGHT = 4.0
const WALL_THICKNESS = 0.4
const DOOR_WIDTH = 3.0
const DOOR_HEIGHT = 2.8
const DOOR_SLIDE = 1.5
const DOOR_ANIM_SPEED = 2.0

var door_open = false
var door_progress = 0.0
var door_left: AnimatableBody3D = null
var door_right: AnimatableBody3D = null
var lever_handle: Node3D = null
var lever_anim = 0.0
var interact_btn: Button = null
var target_player: Node3D = null

# ⭐ 宝箱
var chest: Node3D = null
var chest_lid: Node3D = null
var chest_opened = false
var chest_btn: Button = null

func _ready():
	build_house()
	build_door()
	build_lever()
	build_chest()
	build_interact_ui()
	await get_tree().process_frame
	target_player = get_parent().get_node_or_null("CharacterBody3D")

# ==================== 房屋结构 ====================
func build_house():
	var wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.55, 0.5, 0.45)
	wall_mat.roughness = 0.9
	
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.3, 0.25, 0.2)
	roof_mat.roughness = 0.9
	
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.4, 0.35, 0.3)
	floor_mat.roughness = 1.0
	
	add_static_box(Vector3(HOUSE_SIZE + 0.4, 0.1, HOUSE_SIZE + 0.4), Vector3(0, 0.05, 0), floor_mat)
	add_static_box(Vector3(HOUSE_SIZE, HOUSE_HEIGHT, WALL_THICKNESS), 
		Vector3(0, HOUSE_HEIGHT/2, HOUSE_SIZE/2), wall_mat)
	add_static_box(Vector3(WALL_THICKNESS, HOUSE_HEIGHT, HOUSE_SIZE), 
		Vector3(-HOUSE_SIZE/2, HOUSE_HEIGHT/2, 0), wall_mat)
	add_static_box(Vector3(WALL_THICKNESS, HOUSE_HEIGHT, HOUSE_SIZE), 
		Vector3(HOUSE_SIZE/2, HOUSE_HEIGHT/2, 0), wall_mat)
	
	var seg_width = (HOUSE_SIZE - DOOR_WIDTH) / 2.0
	add_static_box(Vector3(seg_width, HOUSE_HEIGHT, WALL_THICKNESS),
		Vector3(-(DOOR_WIDTH/2 + seg_width/2), HOUSE_HEIGHT/2, -HOUSE_SIZE/2), wall_mat)
	add_static_box(Vector3(seg_width, HOUSE_HEIGHT, WALL_THICKNESS),
		Vector3(DOOR_WIDTH/2 + seg_width/2, HOUSE_HEIGHT/2, -HOUSE_SIZE/2), wall_mat)
	
	var beam_h = HOUSE_HEIGHT - DOOR_HEIGHT
	add_static_box(Vector3(DOOR_WIDTH, beam_h, WALL_THICKNESS),
		Vector3(0, DOOR_HEIGHT + beam_h/2, -HOUSE_SIZE/2), wall_mat)
	
	add_static_box(Vector3(HOUSE_SIZE + 0.6, 0.3, HOUSE_SIZE + 0.6),
		Vector3(0, HOUSE_HEIGHT + 0.15, 0), roof_mat)

# ==================== 电压门 ====================
func build_door():
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.15, 0.15, 0.18)
	door_mat.metallic = 0.9
	door_mat.roughness = 0.35
	
	var stripe_mat = StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.9, 0.3, 0.05)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(0.9, 0.3, 0.05)
	stripe_mat.emission_energy_multiplier = 0.8
	
	door_left = AnimatableBody3D.new()
	door_left.position = Vector3(-DOOR_WIDTH/4, DOOR_HEIGHT/2, -HOUSE_SIZE/2)
	add_child(door_left)
	add_mesh_and_collision(door_left, Vector3(DOOR_WIDTH/2, DOOR_HEIGHT, 0.2), door_mat)
	var stripe_l = MeshInstance3D.new()
	var sm_l = BoxMesh.new(); sm_l.size = Vector3(DOOR_WIDTH/2, 0.12, 0.22)
	stripe_l.mesh = sm_l
	stripe_l.material_override = stripe_mat
	stripe_l.position.y = DOOR_HEIGHT/2 - 0.3
	door_left.add_child(stripe_l)
	
	door_right = AnimatableBody3D.new()
	door_right.position = Vector3(DOOR_WIDTH/4, DOOR_HEIGHT/2, -HOUSE_SIZE/2)
	add_child(door_right)
	add_mesh_and_collision(door_right, Vector3(DOOR_WIDTH/2, DOOR_HEIGHT, 0.2), door_mat)
	var stripe_r = MeshInstance3D.new()
	var sm_r = BoxMesh.new(); sm_r.size = Vector3(DOOR_WIDTH/2, 0.12, 0.22)
	stripe_r.mesh = sm_r
	stripe_r.material_override = stripe_mat
	stripe_r.position.y = DOOR_HEIGHT/2 - 0.3
	door_right.add_child(stripe_r)

# ==================== 拉杆 ====================
func build_lever():
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.25, 0.25, 0.3)
	base_mat.metallic = 0.7
	base_mat.roughness = 0.5
	
	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.9, 0.15, 0.1)
	handle_mat.emission_enabled = true
	handle_mat.emission = Color(0.9, 0.15, 0.1)
	handle_mat.emission_energy_multiplier = 1.0
	
	var lever_pos = Vector3(-2.5, 0, -2.5)
	
	var base = MeshInstance3D.new()
	var base_mesh = BoxMesh.new(); base_mesh.size = Vector3(0.6, 0.3, 0.6)
	base.mesh = base_mesh
	base.material_override = base_mat
	base.position = lever_pos + Vector3(0, 0.15, 0)
	add_child(base)
	
	var post = MeshInstance3D.new()
	var post_mesh = BoxMesh.new(); post_mesh.size = Vector3(0.15, 1.2, 0.15)
	post.mesh = post_mesh
	post.material_override = base_mat
	post.position = lever_pos + Vector3(0, 0.9, 0)
	add_child(post)
	
	lever_handle = Node3D.new()
	lever_handle.position = lever_pos + Vector3(0, 1.5, 0)
	add_child(lever_handle)
	
	var bar = MeshInstance3D.new()
	var bar_mesh = BoxMesh.new(); bar_mesh.size = Vector3(0.1, 0.1, 0.7)
	bar.mesh = bar_mesh
	bar.material_override = handle_mat
	bar.position.z = 0.35
	lever_handle.add_child(bar)
	
	var tip = MeshInstance3D.new()
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.12
	tip_mesh.height = 0.24
	tip.mesh = tip_mesh
	tip.material_override = handle_mat
	tip.position.z = 0.75
	lever_handle.add_child(tip)
	
	var area = Area3D.new()
	var col = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 3.0
	col.shape = shape
	area.add_child(col)
	area.position = lever_pos + Vector3(0, 1.0, 0)
	area.body_entered.connect(_on_area_entered)
	area.body_exited.connect(_on_area_exited)
	add_child(area)

# ⭐ 宝箱
func build_chest():
	var chest_group = Node3D.new()
	chest_group.position = Vector3(2.5, 0, 2.5)
	add_child(chest_group)
	
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.4, 0.25, 0.1)
	body_mat.roughness = 0.8
	
	var body = MeshInstance3D.new()
	var body_mesh = BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.6, 0.6)
	body.mesh = body_mesh
	body.material_override = body_mat
	body.position.y = 0.3
	chest_group.add_child(body)
	
	var static_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.9, 0.6, 0.6)
	col.shape = box
	col.position.y = 0.3
	static_body.add_child(col)
	chest_group.add_child(static_body)
	
	# 盖子（绕后沿转）
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0, 0.6, -0.3)
	chest_group.add_child(chest_lid)
	
	var lid_mesh = MeshInstance3D.new()
	var lid_box = BoxMesh.new()
	lid_box.size = Vector3(0.9, 0.1, 0.6)
	lid_mesh.mesh = lid_box
	lid_mesh.material_override = body_mat
	lid_mesh.position = Vector3(0, 0.05, 0.3)
	chest_lid.add_child(lid_mesh)
	
	# 金色发光饰条
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1, 0.8, 0.2)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1, 0.8, 0.2)
	glow_mat.emission_energy_multiplier = 1.5
	var glow_mesh = MeshInstance3D.new()
	var glow_box = BoxMesh.new()
	glow_box.size = Vector3(0.94, 0.05, 0.64)
	glow_mesh.mesh = glow_box
	glow_mesh.material_override = glow_mat
	glow_mesh.position.y = 0.6
	chest_group.add_child(glow_mesh)
	
	# 玩家靠近感应
	var area = Area3D.new()
	var col2 = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 2.5
	col2.shape = shape
	area.add_child(col2)
	area.position.y = 0.5
	area.body_entered.connect(_on_chest_entered)
	area.body_exited.connect(_on_chest_exited)
	chest_group.add_child(area)
	
	chest = chest_group

func _on_chest_entered(body):
	if body.name == "CharacterBody3D" and not chest_opened:
		if chest_btn:
			chest_btn.visible = true

func _on_chest_exited(body):
	if body.name == "CharacterBody3D":
		if chest_btn:
			chest_btn.visible = false

func _on_chest_open_pressed():
	if chest_opened:
		return
	chest_opened = true
	if chest_btn:
		chest_btn.visible = false
	var player = get_parent().get_node_or_null("CharacterBody3D")
	if player and player.has_method("give_flashbang"):
		player.give_flashbang()
	print("宝箱打开，获得震撼弹")

# ==================== 拉杆/门交互 ====================
func _on_area_entered(body):
	if body.name == "CharacterBody3D":
		if interact_btn:
			interact_btn.visible = true

func _on_area_exited(body):
	if body.name == "CharacterBody3D":
		if interact_btn:
			interact_btn.visible = false

# ==================== 交互 UI ====================
func build_interact_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	var vp = get_viewport().get_visible_rect().size
	
	# 拉杆按钮
	interact_btn = Button.new()
	interact_btn.text = "拉 动 拉 杆"
	interact_btn.add_theme_font_size_override("font_size", 20)
	interact_btn.size = Vector2(220, 70)
	interact_btn.position = Vector2(vp.x / 2 - 110, vp.y - 300)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.4, 0.1, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	interact_btn.add_theme_stylebox_override("normal", style)
	interact_btn.visible = false
	interact_btn.pressed.connect(_on_interact_pressed)
	canvas.add_child(interact_btn)
	
	# 宝箱按钮
	chest_btn = Button.new()
	chest_btn.text = "打 开 宝 箱"
	chest_btn.add_theme_font_size_override("font_size", 20)
	chest_btn.size = Vector2(200, 65)
	chest_btn.position = Vector2(vp.x / 2 - 100, vp.y - 380)
	var cstyle = StyleBoxFlat.new()
	cstyle.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	cstyle.corner_radius_top_left = 12
	cstyle.corner_radius_top_right = 12
	cstyle.corner_radius_bottom_left = 12
	cstyle.corner_radius_bottom_right = 12
	chest_btn.add_theme_stylebox_override("normal", cstyle)
	chest_btn.visible = false
	chest_btn.pressed.connect(_on_chest_open_pressed)
	canvas.add_child(chest_btn)

func _on_interact_pressed():
	door_open = not door_open
	lever_anim = 1.0
	print("门状态：", "开启" if door_open else "关闭")

# ==================== 主循环 ====================
func _process(delta):
	# 门开合
	var target = 1.0 if door_open else 0.0
	if abs(door_progress - target) > 0.001:
		door_progress = move_toward(door_progress, target, DOOR_ANIM_SPEED * delta)
	if door_left and door_right:
		door_left.position.x = -DOOR_WIDTH/4 - door_progress * DOOR_SLIDE
		door_right.position.x = DOOR_WIDTH/4 + door_progress * DOOR_SLIDE
	
	# 拉杆挥动
	if lever_anim > 0:
		lever_anim -= delta * 3.0
		if lever_handle:
			var angle = sin((1.0 - lever_anim) * PI * 2) * 0.5
			lever_handle.rotation.x = angle
		if lever_anim <= 0 and lever_handle:
			lever_handle.rotation.x = 0
	
	# 宝箱开盖动画
	if chest_opened and chest_lid:
		chest_lid.rotation.x = move_toward(chest_lid.rotation.x, -PI/2, delta * 4.0)

# ==================== 辅助 ====================
func add_static_box(size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	add_child(body)
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

func add_mesh_and_collision(parent: Node3D, size: Vector3, mat: Material):
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	parent.add_child(col)
