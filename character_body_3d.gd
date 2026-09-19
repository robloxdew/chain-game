extends CharacterBody3D

@export var speed = 5.0
var U = 0.25
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var move_input = Vector2.ZERO
var joystick_center = Vector2.ZERO
var joystick_touch_id = -1
var max_radius = 100.0

var look_touch_id = -1
var last_look_pos = Vector2.ZERO
var yaw = 0.0
var pitch = 0.0
@export var look_sensitivity = 0.005

var walk_phase = 0.0
var is_moving = false
var arm_l_pivot: Node3D
var arm_r_pivot: Node3D
var leg_l_pivot: Node3D
var leg_r_pivot: Node3D

var attack_anim_time = 0.0
const ATTACK_ANIM_DUR = 1.2
const PARRY_START = 0.3
const PARRY_END = 0.9
const ATTACK_HIT_TIME = 0.6
var attack_hit_done = false

var is_blocking = false
var block_time = 0.0
const BLOCK_DURATION = 1.5
const BLOCK_PARRY_START = 0.4
const BLOCK_PARRY_END = 1.25
var block_btn: Button = null

var machete_node: Node3D = null
var hand_machete: Node3D = null
var has_machete: bool = false
var pickup_btn: Button = null

var player_hp = 100.0
var player_max_hp = 100.0
var is_dead = false
var death_panel: Control = null

var game_started = false
var loading_canvas: CanvasLayer
var loading_btn: Button
var loading_progress: Label

var hp_bar_fill: ColorRect
var hp_text: Label
const HP_BAR_WIDTH = 220.0
const HP_BAR_HEIGHT = 26.0

var parry_flash_label: Label
var parry_flash_time = 0.0

var crosshair_control: Control
var hitmarker_time = 0.0
const HITMARKER_DUR = 0.25

# 血渍特效
var blood_overlay: ColorRect = null
var blood_intensity = 0.0
const BLOOD_DECAY_SPEED = 0.15

# 回血
var regen_timer = 0.0
const REGEN_INTERVAL = 15.0
const REGEN_AMOUNT = 5.0

# ⭐ 爆炸特效（花屏 + Danger）
var glitch_overlay: ColorRect = null
var glitch_time = 0.0
const GLITCH_DURATION = 0.4
var danger_label: Label = null
var danger_time = 0.0
const DANGER_DURATION = 1.5

# 震撼弹
var has_flashbang = false
var pin_pulled = false
var pulling_pin = false
var pull_pin_time = 0.0
const PULL_PIN_DUR = 1.2
var flashbang_model: Node3D = null
var pull_btn: Button = null
var throw_btn: Button = null
var throwing_flash = false
var throw_anim_time = 0.0
const THROW_ANIM_DUR = 0.6

const TREE_COUNT = 40
const MAP_RADIUS = 45.0
const SAFE_ZONE = 8.0
var trunk_mesh: CylinderMesh
var leaf_mesh: SphereMesh
var trunk_mat: StandardMaterial3D
var leaf_mat1: StandardMaterial3D
var leaf_mat2: StandardMaterial3D

func _ready():
	build_r6()
	setup_collision()
	create_loading_ui()

func setup_collision():
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.45
		shape.height = 1.5
		col.shape = shape
		col.position.y = 0.75
		add_child(col)

func is_in_parry_window() -> bool:
	if attack_anim_time > 0:
		var elapsed = ATTACK_ANIM_DUR - attack_anim_time
		if elapsed >= PARRY_START and elapsed <= PARRY_END:
			return true
	if is_blocking:
		var eb = BLOCK_DURATION - block_time
		if eb >= BLOCK_PARRY_START and eb <= BLOCK_PARRY_END:
			return true
	return false

func on_parry_success():
	attack_anim_time = 0.0
	attack_hit_done = true
	is_blocking = false
	block_time = 0.0
	if parry_flash_label:
		parry_flash_label.modulate.a = 1.0
		parry_flash_time = 0.8

# ⭐ 爆炸特效：屏幕花屏 + Danger 警告
func trigger_explosion_effect():
	glitch_time = GLITCH_DURATION
	danger_time = DANGER_DURATION
	if danger_label:
		danger_label.modulate.a = 1.0
	print("[Player] 触发爆炸花屏 + Danger 警告")

func give_flashbang():
	has_flashbang = true
	pin_pulled = false
	pulling_pin = false
	_update_flashbang_ui()
	print("获得震撼弹")

func create_loading_ui():
	loading_canvas = CanvasLayer.new()
	loading_canvas.layer = 200
	add_child(loading_canvas)
	
	var vp = get_viewport().get_visible_rect().size
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_canvas.add_child(bg)
	
	var title = Label.new()
	title.text = "CHAIN"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(vp.x / 2 - 200, vp.y / 2 - 200)
	title.size = Vector2(400, 100)
	loading_canvas.add_child(title)
	
	loading_btn = Button.new()
	loading_btn.text = "开 始 游 戏"
	loading_btn.add_theme_font_size_override("font_size", 24)
	loading_btn.position = Vector2(vp.x / 2 - 120, vp.y / 2 + 40)
	loading_btn.size = Vector2(240, 80)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.7, 0.1, 0.1)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	loading_btn.add_theme_stylebox_override("normal", style)
	loading_btn.add_theme_stylebox_override("hover", style)
	loading_btn.add_theme_stylebox_override("pressed", style)
	loading_canvas.add_child(loading_btn)
	loading_btn.pressed.connect(_on_start_pressed)
	
	loading_progress = Label.new()
	loading_progress.text = ""
	loading_progress.add_theme_font_size_override("font_size", 20)
	loading_progress.add_theme_color_override("font_color", Color(1, 1, 1))
	loading_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_progress.position = Vector2(vp.x / 2 - 200, vp.y / 2 + 160)
	loading_progress.size = Vector2(400, 40)
	loading_progress.visible = false
	loading_canvas.add_child(loading_progress)

func _on_start_pressed():
	loading_btn.visible = false
	loading_progress.visible = true
	loading_progress.text = "正在准备..."
	
	trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.4
	trunk_mesh.height = 4.0
	
	leaf_mesh = SphereMesh.new()
	leaf_mesh.radius = 1.8
	leaf_mesh.height = 3.0
	
	trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.2, 0.1)
	
	leaf_mat1 = StandardMaterial3D.new()
	leaf_mat1.albedo_color = Color(0.1, 0.45, 0.15)
	
	leaf_mat2 = StandardMaterial3D.new()
	leaf_mat2.albedo_color = Color(0.2, 0.55, 0.25)
	
	for i in range(TREE_COUNT):
		loading_progress.text = "正在生成树木 %d / %d" % [i + 1, TREE_COUNT]
		spawn_one_tree()
		await get_tree().process_frame
	
	loading_progress.text = "加载完成！"
	await get_tree().create_timer(0.4).timeout
	
	loading_canvas.visible = false
	start_game()

func start_game():
	create_joystick_ui()
	create_attack_ui()
	create_block_ui()
	create_pickup_ui()
	create_hp_ui()
	create_parry_flash_ui()
	create_crosshair_ui()
	create_flashbang_ui()
	create_blood_overlay()
	create_explosion_fx_ui()
	create_death_ui()
	spawn_machete()
	game_started = true
	print("游戏已开始")

func spawn_one_tree():
	var angle = randf() * PI * 2
	var dist = randf_range(SAFE_ZONE, MAP_RADIUS)
	var x = cos(angle) * dist
	var z = sin(angle) * dist
	var tree = Node3D.new()
	tree.position = Vector3(x, 0, z)
	tree.rotation.y = randf() * PI * 2
	var s = randf_range(0.8, 1.4)
	tree.scale = Vector3(s, s, s)
	get_parent().add_child(tree)
	
	var trunk = MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_mat
	trunk.position.y = 2.0
	tree.add_child(trunk)
	
	var leaves = MeshInstance3D.new()
	leaves.mesh = leaf_mesh
	leaves.material_override = leaf_mat1 if randf() > 0.5 else leaf_mat2
	leaves.position.y = 4.5
	tree.add_child(leaves)
	
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 4.0
	col.shape = shape
	col.position.y = 2.0
	body.add_child(col)
	tree.add_child(body)

# ⭐ 爆炸特效 UI（花屏 + Danger）
func create_explosion_fx_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 22
	add_child(canvas)
	
	# 花屏叠层
	glitch_overlay = ColorRect.new()
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.color = Color(0, 0, 0, 0)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(glitch_overlay)
	
	# Danger 警告
	danger_label = Label.new()
	danger_label.text = "⚠️ Danger"
	danger_label.add_theme_font_size_override("font_size", 64)
	danger_label.add_theme_color_override("font_color", Color(1, 0.15, 0.15))
	danger_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	danger_label.add_theme_constant_override("outline_size", 8)
	danger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vp = get_viewport().get_visible_rect().size
	danger_label.position = Vector2(vp.x / 2 - 300, vp.y / 2 - 100)
	danger_label.size = Vector2(600, 100)
	danger_label.modulate.a = 0
	canvas.add_child(danger_label)

func update_explosion_fx(delta):
	# 花屏
	if glitch_time > 0:
		glitch_time -= delta
		var r = randf()
		if r < 0.33:
			glitch_overlay.color = Color(1, 0, 0, randf_range(0.3, 0.6))
		elif r < 0.66:
			glitch_overlay.color = Color(0, 1, 1, randf_range(0.2, 0.5))
		else:
			glitch_overlay.color = Color(1, 0.8, 0, randf_range(0.3, 0.5))
		glitch_overlay.position = Vector2(randf_range(-20, 20), randf_range(-20, 20))
	else:
		if glitch_overlay:
			glitch_overlay.color = Color(0, 0, 0, 0)
			glitch_overlay.position = Vector2.ZERO
	
	# Danger
	if danger_time > 0:
		danger_time -= delta
		if danger_time < 0.3:
			danger_label.modulate.a = danger_time / 0.3
		else:
			var blink = sin(danger_time * 20) * 0.5 + 0.5
			danger_label.modulate.a = 0.6 + blink * 0.4
	else:
		if danger_label:
			danger_label.modulate.a = 0

# ⭐ 血渍特效
func create_blood_overlay():
	var canvas = CanvasLayer.new()
	canvas.layer = 18
	add_child(canvas)
	
	blood_overlay = ColorRect.new()
	blood_overlay.color = Color(0.6, 0, 0, 0)
	blood_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(blood_overlay)
	
	var edge = ColorRect.new()
	edge.name = "EdgeVignette"
	edge.color = Color(0.4, 0, 0, 0)
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(edge)
	blood_overlay.set_meta("edge", edge)

func update_blood_overlay(delta):
	if not blood_overlay:
		return
	if blood_intensity > 0:
		blood_intensity = max(0.0, blood_intensity - BLOOD_DECAY_SPEED * delta)
	var alpha = blood_intensity * 0.5
	blood_overlay.color = Color(0.55, 0, 0, alpha)
	var edge = blood_overlay.get_meta("edge")
	if edge:
		edge.color = Color(0.3, 0, 0, blood_intensity * 0.7)

func _physics_process(delta):
	if not game_started or is_dead:
		return
	
	rotation.y = yaw
	if has_node("Camera3D"):
		$Camera3D.rotation.x = pitch
		$Camera3D.rotation.y = 0

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	var speed_mult = 0.5 if (is_blocking or pulling_pin) else 1.0
	
	var direction = (transform.basis * Vector3(move_input.x, 0, move_input.y)).normalized()
	if direction:
		is_moving = true
		velocity.x = direction.x * speed * speed_mult
		velocity.z = direction.z * speed * speed_mult
	else:
		is_moving = false
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	if is_blocking:
		block_time -= delta
		if block_time <= 0:
			is_blocking = false
			block_time = 0.0
	
	if pulling_pin:
		pull_pin_time -= delta
		if pull_pin_time <= 0:
			pulling_pin = false
			pin_pulled = true
			_update_flashbang_ui()
			print("拉环完成，可以投掷了")
	
	if throw_anim_time > 0:
		throw_anim_time -= delta
		if throw_anim_time <= 0:
			throwing_flash = false
	
	# 回血
	regen_timer += delta
	if regen_timer >= REGEN_INTERVAL:
		regen_timer = 0.0
		if player_hp < player_max_hp:
			player_hp = min(player_max_hp, player_hp + REGEN_AMOUNT)
			update_hp_ui()
			print("回血 +%d，当前 HP: %d" % [int(REGEN_AMOUNT), int(player_hp)])

	move_and_slide()
	animate_limbs(delta)
	check_attack_hit()
	check_machete_distance()
	check_void_death()

func _process(delta):
	if machete_node and not has_machete:
		machete_node.rotation.y += delta * 2.0
		machete_node.position.y = 0.8 + sin(Time.get_ticks_msec() * 0.003) * 0.15
	
	if parry_flash_time > 0:
		parry_flash_time -= delta
		if parry_flash_label:
			parry_flash_label.modulate.a = clamp(parry_flash_time / 0.8, 0.0, 1.0)
	
	if hitmarker_time > 0:
		hitmarker_time -= delta
	
	# ⭐ 更新特效
	update_blood_overlay(delta)
	update_explosion_fx(delta)
	
	if crosshair_control:
		crosshair_control.queue_redraw()

func check_attack_hit():
	if attack_anim_time <= 0:
		return
	if attack_hit_done:
		return
	var elapsed = ATTACK_ANIM_DUR - attack_anim_time
	if elapsed >= ATTACK_HIT_TIME:
		attack_hit_done = true
		var chain = get_parent().get_node_or_null("Chain")
		if chain and chain.has_method("take_damage"):
			var dist = global_position.distance_to(chain.global_position)
			if dist < 2.5:
				chain.take_damage(2.0)
				show_hitmarker()

# ==================== 震撼弹 UI ====================
func create_flashbang_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 14
	add_child(canvas)
	
	var vp = get_viewport().get_visible_rect().size
	
	pull_btn = Button.new()
	pull_btn.text = "拉 开 拉 环"
	pull_btn.add_theme_font_size_override("font_size", 18)
	pull_btn.size = Vector2(180, 70)
	pull_btn.position = Vector2(vp.x - 380, vp.y - 130)
	var s1 = StyleBoxFlat.new()
	s1.bg_color = Color(0.9, 0.7, 0.2, 0.9)
	s1.corner_radius_top_left = 12
	s1.corner_radius_top_right = 12
	s1.corner_radius_bottom_left = 12
	s1.corner_radius_bottom_right = 12
	pull_btn.add_theme_stylebox_override("normal", s1)
	pull_btn.visible = false
	pull_btn.pressed.connect(_on_pull_pin_pressed)
	canvas.add_child(pull_btn)
	
	throw_btn = Button.new()
	throw_btn.text = "投 掷"
	throw_btn.add_theme_font_size_override("font_size", 20)
	throw_btn.size = Vector2(180, 70)
	throw_btn.position = Vector2(vp.x - 380, vp.y - 130)
	var s2 = StyleBoxFlat.new()
	s2.bg_color = Color(0.3, 0.75, 0.3, 0.9)
	s2.corner_radius_top_left = 12
	s2.corner_radius_top_right = 12
	s2.corner_radius_bottom_left = 12
	s2.corner_radius_bottom_right = 12
	throw_btn.add_theme_stylebox_override("normal", s2)
	throw_btn.visible = false
	throw_btn.pressed.connect(_on_throw_pressed)
	canvas.add_child(throw_btn)

func _update_flashbang_ui():
	if not pull_btn or not throw_btn:
		return
	pull_btn.visible = has_flashbang and not pin_pulled and not pulling_pin
	throw_btn.visible = has_flashbang and pin_pulled and not pulling_pin

func _on_pull_pin_pressed():
	if not has_flashbang or pin_pulled or pulling_pin:
		return
	pulling_pin = true
	pull_pin_time = PULL_PIN_DUR
	_create_flashbang_model()
	_update_flashbang_ui()
	print("开始拉环，速度减半")

func _create_flashbang_model():
	if not arm_l_pivot:
		return
	flashbang_model = Node3D.new()
	var body = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = 0.14
	body.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.3)
	body.material_override = mat
	flashbang_model.add_child(body)
	
	var ring = MeshInstance3D.new()
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.03
	ring_mesh.outer_radius = 0.045
	ring.mesh = ring_mesh
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.7, 0.7, 0.75)
	ring_mat.metallic = 0.8
	ring.material_override = ring_mat
	ring.position.y = 0.08
	flashbang_model.add_child(ring)
	
	flashbang_model.position = Vector3(0, -2*U, -0.15)
	flashbang_model.rotation = Vector3(PI/2, 0, 0)
	arm_l_pivot.add_child(flashbang_model)

func _on_throw_pressed():
	if not pin_pulled:
		return
	pin_pulled = false
	has_flashbang = false
	pulling_pin = false
	throwing_flash = true
	throw_anim_time = THROW_ANIM_DUR
	_update_flashbang_ui()
	
	if flashbang_model:
		flashbang_model.queue_free()
		flashbang_model = null
	
	var parent = get_parent()
	var stunned_count = 0
	for child in parent.get_children():
		if child.name == "Chain" and child.has_method("stun"):
			var dist = global_position.distance_to(child.global_position)
			if dist <= 10.0:
				child.stun(5.0)
				stunned_count += 1
	print("震撼弹投掷！眩晕了 ", stunned_count, " 个 CHAIN")

# ==================== 准心 ====================
func create_crosshair_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)
	crosshair_control = Control.new()
	crosshair_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(crosshair_control)
	crosshair_control.draw.connect(_draw_crosshair)

func _draw_crosshair():
	if not crosshair_control:
		return
	var center = crosshair_control.size / 2.0
	crosshair_control.draw_circle(center, 2.5, Color(1, 1, 1, 0.95))
	
	if not has_machete:
		return
	
	var ring_color = Color(1, 1, 1, 0.85)
	var ring_radius = 32.0
	var arc_start = -PI / 2.0
	var arc_end = arc_start + TAU
	
	if is_blocking:
		var eb = BLOCK_DURATION - block_time
		var in_parry = eb >= BLOCK_PARRY_START and eb <= BLOCK_PARRY_END
		ring_color = Color(0.3, 0.7, 1.0, 1.0) if in_parry else Color(0.6, 0.6, 0.7, 0.6)
		arc_end = arc_start + TAU * (1.0 - clamp(eb / BLOCK_DURATION, 0, 1))
	elif attack_anim_time > 0:
		var elapsed = ATTACK_ANIM_DUR - attack_anim_time
		arc_end = arc_start + TAU * (1.0 - clamp(elapsed / ATTACK_ANIM_DUR, 0, 1))
		if elapsed >= PARRY_START and elapsed <= PARRY_END:
			ring_color = Color(1.0, 0.2, 0.2, 1.0)
	
	if arc_end > arc_start + 0.01:
		crosshair_control.draw_arc(center, ring_radius, arc_start, arc_end, 64, ring_color, 3.0)
	
	if hitmarker_time > 0:
		var progress = hitmarker_time / HITMARKER_DUR
		var alpha = progress
		var mark_size = 12.0 + (1.0 - progress) * 6.0
		var mark_gap = 6.0 + (1.0 - progress) * 4.0
		var mark_color = Color(1, 0.95, 0.9, alpha)
		crosshair_control.draw_line(center + Vector2(mark_gap, -mark_gap), center + Vector2(mark_gap + mark_size, -mark_gap - mark_size), mark_color, 2.5)
		crosshair_control.draw_line(center + Vector2(mark_gap, mark_gap), center + Vector2(mark_gap + mark_size, mark_gap + mark_size), mark_color, 2.5)
		crosshair_control.draw_line(center + Vector2(-mark_gap, -mark_gap), center + Vector2(-mark_gap - mark_size, -mark_gap - mark_size), mark_color, 2.5)
		crosshair_control.draw_line(center + Vector2(-mark_gap, mark_gap), center + Vector2(-mark_gap - mark_size, mark_gap + mark_size), mark_color, 2.5)

func show_hitmarker():
	hitmarker_time = HITMARKER_DUR

func check_void_death():
	if is_dead:
		return
	if global_position.y < -10.0:
		die("你 掉 入 了 虚 空")

func die(reason: String):
	if is_dead:
		return
	is_dead = true
	print("玩家死亡：", reason)
	if death_panel:
		death_panel.visible = true
		var title = death_panel.get_node_or_null("Title")
		if title:
			title.text = reason
		var info = death_panel.get_node_or_null("Info")
		if info:
			info.text = "你活了 " + str(int(Time.get_ticks_msec() / 1000.0)) + " 秒"
	get_tree().paused = true

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func create_death_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	death_panel = Control.new()
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.visible = false
	death_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(death_panel)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.add_child(bg)
	var vp = get_viewport().get_visible_rect().size
	var title = Label.new()
	title.name = "Title"
	title.text = "你 死 了"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(vp.x / 2 - 200, vp.y / 2 - 150)
	title.size = Vector2(400, 80)
	death_panel.add_child(title)
	var info = Label.new()
	info.name = "Info"
	info.text = "你活了 0 秒"
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.position = Vector2(vp.x / 2 - 200, vp.y / 2 - 40)
	info.size = Vector2(400, 40)
	death_panel.add_child(info)
	var btn = Button.new()
	btn.text = "重 新 开 始"
	btn.add_theme_font_size_override("font_size", 22)
	btn.position = Vector2(vp.x / 2 - 90, vp.y / 2 + 40)
	btn.size = Vector2(180, 60)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.8, 0.15, 0.15, 0.9)
	btn_style.corner_radius_top_left = 12
	btn_style.corner_radius_top_right = 12
	btn_style.corner_radius_bottom_left = 12
	btn_style.corner_radius_bottom_right = 12
	btn.add_theme_stylebox_override("normal", btn_style)
	death_panel.add_child(btn)
	btn.pressed.connect(_on_restart_pressed)

func _input(event):
	if not game_started or is_dead:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x / 2.0:
				joystick_touch_id = event.index
				joystick_center = event.position
				move_input = Vector2.ZERO
			else:
				look_touch_id = event.index
				last_look_pos = event.position
		else:
			if event.index == joystick_touch_id:
				joystick_touch_id = -1
				move_input = Vector2.ZERO
			if event.index == look_touch_id:
				look_touch_id = -1
	if event is InputEventScreenDrag:
		if event.index == joystick_touch_id:
			var diff = event.position - joystick_center
			if diff.length() > max_radius:
				diff = diff.normalized() * max_radius
			move_input = diff / max_radius
		elif event.index == look_touch_id:
			var delta_pos = event.position - last_look_pos
			last_look_pos = event.position
			yaw -= delta_pos.x * look_sensitivity
			pitch -= delta_pos.y * look_sensitivity
			pitch = clamp(pitch, -1.4, 1.4)

func create_joystick_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var bg = ColorRect.new()
	bg.color = Color(1, 1, 1, 0.2)
	bg.size = Vector2(200, 200)
	bg.position = Vector2(60, get_viewport().get_visible_rect().size.y - 260)
	canvas.add_child(bg)
	var knob = ColorRect.new()
	knob.color = Color(1, 1, 1, 0.7)
	knob.size = Vector2(80, 80)
	knob.position = bg.position + Vector2(60, 60)
	canvas.add_child(knob)

func create_attack_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var btn = Button.new()
	btn.text = "攻击"
	btn.size = Vector2(120, 120)
	btn.position = Vector2(get_viewport().get_visible_rect().size.x - 180, get_viewport().get_visible_rect().size.y - 220)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0.3, 0.3, 0.8)
	style.corner_radius_top_left = 60
	style.corner_radius_top_right = 60
	style.corner_radius_bottom_left = 60
	style.corner_radius_bottom_right = 60
	btn.add_theme_stylebox_override("normal", style)
	canvas.add_child(btn)
	btn.pressed.connect(_on_attack_pressed)

func create_block_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	block_btn = Button.new()
	block_btn.text = "格挡"
	block_btn.size = Vector2(110, 110)
	block_btn.position = Vector2(get_viewport().get_visible_rect().size.x - 320, get_viewport().get_visible_rect().size.y - 200)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.9, 0.8)
	style.corner_radius_top_left = 55
	style.corner_radius_top_right = 55
	style.corner_radius_bottom_left = 55
	style.corner_radius_bottom_right = 55
	block_btn.add_theme_stylebox_override("normal", style)
	canvas.add_child(block_btn)
	block_btn.pressed.connect(_on_block_pressed)

func _on_block_pressed():
	if is_dead or not has_machete or is_blocking or attack_anim_time > 0 or pulling_pin:
		return
	is_blocking = true
	block_time = BLOCK_DURATION

func create_pickup_ui():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	pickup_btn = Button.new()
	pickup_btn.text = "拾取砍刀"
	pickup_btn.size = Vector2(160, 60)
	var screen_size = get_viewport().get_visible_rect().size
	pickup_btn.position = Vector2(screen_size.x / 2 - 80, screen_size.y - 160)
	pickup_btn.visible = false
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 0.8, 0.2, 0.8)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	pickup_btn.add_theme_stylebox_override("normal", style)
	canvas.add_child(pickup_btn)
	pickup_btn.pressed.connect(_on_pickup_pressed)

func create_hp_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var hp_bar_bg = ColorRect.new()
	hp_bar_bg.color = Color(0, 0, 0, 0.55)
	hp_bar_bg.size = Vector2(HP_BAR_WIDTH + 4, HP_BAR_HEIGHT + 4)
	hp_bar_bg.position = Vector2(18, 18)
	canvas.add_child(hp_bar_bg)
	hp_bar_fill = ColorRect.new()
	hp_bar_fill.color = Color(0.85, 0.12, 0.12)
	hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_fill.position = Vector2(20, 20)
	canvas.add_child(hp_bar_fill)
	hp_text = Label.new()
	hp_text.text = "HP 100 / 100"
	hp_text.add_theme_font_size_override("font_size", 16)
	hp_text.add_theme_color_override("font_color", Color(1, 1, 1))
	hp_text.position = Vector2(28, 22)
	canvas.add_child(hp_text)

func update_hp_ui():
	if not hp_bar_fill:
		return
	var ratio = clamp(player_hp / player_max_hp, 0.0, 1.0)
	hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
	hp_text.text = "HP " + str(int(player_hp)) + " / " + str(int(player_max_hp))

func create_parry_flash_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	parry_flash_label = Label.new()
	parry_flash_label.text = "擦 刀 ！"
	parry_flash_label.add_theme_font_size_override("font_size", 32)
	parry_flash_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	parry_flash_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	parry_flash_label.add_theme_constant_override("outline_size", 4)
	parry_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vp = get_viewport().get_visible_rect().size
	parry_flash_label.position = Vector2(vp.x / 2 - 150, vp.y / 2 - 100)
	parry_flash_label.size = Vector2(300, 60)
	parry_flash_label.modulate.a = 0
	canvas.add_child(parry_flash_label)

func spawn_machete():
	var machete_group = Node3D.new()
	var angle = randf() * PI * 2
	var dist = randf_range(10.0, 20.0)
	var pos = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	machete_group.global_position = pos
	var handle = MeshInstance3D.new()
	var h_mesh = BoxMesh.new(); h_mesh.size = Vector3(0.06, 0.06, 0.25)
	handle.mesh = h_mesh
	var h_mat = StandardMaterial3D.new(); h_mat.albedo_color = Color(0.2, 0.1, 0.05)
	handle.material_override = h_mat
	handle.position.z = 0.1
	machete_group.add_child(handle)
	var blade = MeshInstance3D.new()
	var b_mesh = BoxMesh.new(); b_mesh.size = Vector3(0.08, 0.02, 0.6)
	blade.mesh = b_mesh
	var b_mat = StandardMaterial3D.new(); b_mat.albedo_color = Color(0.7, 0.7, 0.75); b_mat.metallic = 0.8
	blade.material_override = b_mat
	blade.position.z = -0.3
	machete_group.add_child(blade)
	var glow = OmniLight3D.new()
	glow.light_color = Color(1, 0.8, 0.2)
	glow.light_energy = 2.0
	glow.omni_range = 5.0
	machete_group.add_child(glow)
	get_parent().add_child(machete_group)
	machete_node = machete_group

func check_machete_distance():
	if machete_node and not has_machete:
		var dist = global_position.distance_to(machete_node.global_position)
		pickup_btn.visible = dist < 2.0
	elif has_machete and pickup_btn:
		pickup_btn.visible = false

func _on_pickup_pressed():
	if machete_node and not has_machete:
		has_machete = true
		machete_node.queue_free()
		machete_node = null
		pickup_btn.visible = false
		hand_machete = Node3D.new()
		var handle = MeshInstance3D.new()
		var h_mesh = BoxMesh.new(); h_mesh.size = Vector3(0.06, 0.06, 0.25)
		handle.mesh = h_mesh
		var h_mat = StandardMaterial3D.new(); h_mat.albedo_color = Color(0.2, 0.1, 0.05)
		handle.material_override = h_mat
		handle.position.z = 0.1
		hand_machete.add_child(handle)
		var blade = MeshInstance3D.new()
		var b_mesh = BoxMesh.new(); b_mesh.size = Vector3(0.08, 0.02, 0.6)
		blade.mesh = b_mesh
		var b_mat = StandardMaterial3D.new(); b_mat.albedo_color = Color(0.7, 0.7, 0.75); b_mat.metallic = 0.8
		blade.material_override = b_mat
		blade.position.z = -0.3
		hand_machete.add_child(blade)
		arm_r_pivot.add_child(hand_machete)
		hand_machete.position = Vector3(0, -2*U, 0)
		hand_machete.rotation = Vector3(-PI/2, 0, 0)

func _on_attack_pressed():
	if is_dead or not has_machete or is_blocking or pulling_pin:
		return
	if attack_anim_time > 0:
		return
	attack_anim_time = ATTACK_ANIM_DUR
	attack_hit_done = false

func take_damage(amount: float):
	if is_dead:
		return
	player_hp -= amount
	if player_hp < 0:
		player_hp = 0
	update_hp_ui()
	print("玩家受到伤害！剩余血量：", player_hp)
	var blood_add = amount / 100.0 * 1.5
	blood_intensity = min(1.0, blood_intensity + blood_add)
	if player_hp <= 0:
		die("你 被 CHAIN 处 决 了")

# ==================== 动画 ====================
func animate_limbs(delta):
	if pulling_pin:
		var p = 1.0 - pull_pin_time / PULL_PIN_DUR
		if arm_l_pivot:
			arm_l_pivot.rotation.x = PI/2
			arm_l_pivot.rotation.y = -0.4
			arm_l_pivot.rotation.z = 0.2
		if arm_r_pivot:
			var pull_phase = sin(p * PI)
			arm_r_pivot.rotation.x = PI/2 - pull_phase * 0.3
			arm_r_pivot.rotation.y = -0.4 - pull_phase * 0.6
			arm_r_pivot.rotation.z = 0
		if leg_l_pivot:
			leg_l_pivot.rotation.x = move_toward(leg_l_pivot.rotation.x, 0, delta * 10.0)
		if leg_r_pivot:
			leg_r_pivot.rotation.x = move_toward(leg_r_pivot.rotation.x, 0, delta * 10.0)
		return
	
	if throwing_flash:
		var p = 1.0 - throw_anim_time / THROW_ANIM_DUR
		if arm_r_pivot:
			arm_r_pivot.rotation.x = PI/2 + p * 0.8
			arm_r_pivot.rotation.y = 0
			arm_r_pivot.rotation.z = 0
		if arm_l_pivot:
			arm_l_pivot.rotation.x = PI/2 - p * 0.8
			arm_l_pivot.rotation.y = 0
			arm_l_pivot.rotation.z = 0
		return
	
	if is_blocking:
		if arm_l_pivot:
			arm_l_pivot.rotation.x = PI/2
			arm_l_pivot.rotation.y = 0.2
			arm_l_pivot.rotation.z = 0.3
		if arm_r_pivot:
			arm_r_pivot.rotation.x = PI/2
			arm_r_pivot.rotation.y = 0
			arm_r_pivot.rotation.z = 0
		if leg_l_pivot:
			leg_l_pivot.rotation.x = move_toward(leg_l_pivot.rotation.x, 0, delta * 10.0)
		if leg_r_pivot:
			leg_r_pivot.rotation.x = move_toward(leg_r_pivot.rotation.x, 0, delta * 10.0)
		return
	
	if attack_anim_time > 0:
		attack_anim_time -= delta
		var t = 1.0 - attack_anim_time / ATTACK_ANIM_DUR
		var arm_x = PI/2
		var arm_z = 0.0
		var arm_y = 0.0
		if t < 0.3:
			var p = t / 0.3
			arm_x = PI/2 - p * 0.5
			arm_z = -p * 0.9
			arm_y = p * 0.5
		elif t < 0.7:
			var p = (t - 0.3) / 0.4
			var ep = p * p * (3.0 - 2.0 * p)
			arm_x = PI/2 - 0.5 + ep * 0.9
			arm_z = -0.9 + ep * 1.8
			arm_y = 0.5 - ep * 1.0
		else:
			var p = (t - 0.7) / 0.3
			var ep = p * p * (3.0 - 2.0 * p)
			arm_x = PI/2 + 0.4 * (1.0 - ep)
			arm_z = 0.9 * (1.0 - ep)
			arm_y = -0.5 * (1.0 - ep)
		if arm_r_pivot:
			arm_r_pivot.rotation.x = arm_x
			arm_r_pivot.rotation.z = arm_z
			arm_r_pivot.rotation.y = arm_y
		if arm_l_pivot:
			arm_l_pivot.rotation.x = -0.4 * sin(t * PI)
			arm_l_pivot.rotation.y = 0
			arm_l_pivot.rotation.z = 0
		return
	
	if is_moving:
		walk_phase += delta * 8.0 
		var swing = sin(walk_phase) * 0.6
		if arm_l_pivot:
			arm_l_pivot.rotation.x = swing
			arm_l_pivot.rotation.y = 0
			arm_l_pivot.rotation.z = 0
			leg_l_pivot.rotation.x = -swing
			leg_r_pivot.rotation.x = swing
		if arm_r_pivot:
			if has_machete:
				arm_r_pivot.rotation.x = PI/2
				arm_r_pivot.rotation.z = 0
				arm_r_pivot.rotation.y = 0
			else:
				arm_r_pivot.rotation.x = -swing
	else:
		walk_phase = 0.0
		var rest_speed = delta * 10.0
		if arm_l_pivot:
			arm_l_pivot.rotation.x = move_toward(arm_l_pivot.rotation.x, 0, rest_speed)
			arm_l_pivot.rotation.y = move_toward(arm_l_pivot.rotation.y, 0, rest_speed)
			arm_l_pivot.rotation.z = move_toward(arm_l_pivot.rotation.z, 0, rest_speed)
			leg_l_pivot.rotation.x = move_toward(leg_l_pivot.rotation.x, 0, rest_speed)
			leg_r_pivot.rotation.x = move_toward(leg_r_pivot.rotation.x, 0, rest_speed)
		if arm_r_pivot:
			if has_machete:
				arm_r_pivot.rotation.x = move_toward(arm_r_pivot.rotation.x, PI/2, rest_speed)
				arm_r_pivot.rotation.z = move_toward(arm_r_pivot.rotation.z, 0, rest_speed)
				arm_r_pivot.rotation.y = move_toward(arm_r_pivot.rotation.y, 0, rest_speed)
			else:
				arm_r_pivot.rotation.x = move_toward(arm_r_pivot.rotation.x, 0, rest_speed)

func build_r6():
	var col_body = Color(0.23, 0.35, 0.54)
	var col_limb = Color(0.18, 0.29, 0.44)
	var col_head = Color(0.94, 0.85, 0.72)
	arm_l_pivot = Node3D.new(); arm_l_pivot.position = Vector3(-1.5*U, 4*U, 0); add_child(arm_l_pivot)
	arm_r_pivot = Node3D.new(); arm_r_pivot.position = Vector3(1.5*U, 4*U, 0); add_child(arm_r_pivot)
	leg_l_pivot = Node3D.new(); leg_l_pivot.position = Vector3(-0.5*U, 2*U, 0); add_child(leg_l_pivot)
	leg_r_pivot = Node3D.new(); leg_r_pivot.position = Vector3(0.5*U, 2*U, 0); add_child(leg_r_pivot)
	add_box(Vector3(2*U, 2*U, 1*U), Vector3(0, 3*U, 0), col_body)
	var head = add_box(Vector3(1*U, 1*U, 1*U), Vector3(0, 4.5*U, 0), col_head)
	head.visible = false
	add_box(Vector3(1*U, 2*U, 1*U), Vector3(0, -1*U, 0), col_limb, arm_l_pivot)
	add_box(Vector3(1*U, 2*U, 1*U), Vector3(0, -1*U, 0), col_limb, arm_r_pivot)
	add_box(Vector3(1*U, 2*U, 1*U), Vector3(0, -1*U, 0), col_limb, leg_l_pivot)
	add_box(Vector3(1*U, 2*U, 1*U), Vector3(0, -1*U, 0), col_limb, leg_r_pivot)

func add_box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	if parent:
		parent.add_child(mi)
	else:
		add_child(mi)
	return mi
