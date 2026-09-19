extends CharacterBody3D

@export var patrol_speed = 1.8
@export var chase_speed = 3.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var U = 0.25

# ⭐ 出生激活控制
var is_active = false

enum State { PATROL, CHASE }
var state = State.PATROL
var target: Node3D = null
var patrol_target = Vector3.ZERO
var patrol_wait = 0.0

const VISION_RANGE = 18.0
const ATTACK_RANGE = 2.0
const CHASE_RANGE = 26.0
const ATTACK_DAMAGE = 33.0
const ATTACK_COOLDOWN = 1.5
const ATTACK_ANIM_DUR = 0.4
const ATTACK_HIT_START = 0.2
const ATTACK_HIT_END = 0.4
const STUN_DURATION = 0.6

var attack_cooldown = 0.0
var attack_anim_time = 0.0
var attack_hit_done = false
var stun_time = 0.0

var hp = 200.0
var max_hp = 200.0

# 自爆：动画 4.1s，4.0s 时触发伤害
const EXPLOSION_RADIUS = 15.0
const EXPLOSION_MAX_DAMAGE = 100.0
const EXPLOSION_MIN_DAMAGE = 10.0
const SELF_DESTRUCT_ANIM_DUR = 4.1
const SELF_DESTRUCT_HIT_TIME = 4.0
const SELF_DESTRUCT_DAMAGE_MIN = 20.0
const SELF_DESTRUCT_DAMAGE_MAX = 25.0

var is_self_destructing = false
var self_destruct_timer = 0.0
var destruct_hit_done = false
var last_destruct_hp = 200.0
var next_destruct_threshold = 25.0

# 三个模型
var model_idle: Node3D = null
var model_run: Node3D = null
var model_explode: Node3D = null
var anim_idle: AnimationPlayer = null
var anim_run: AnimationPlayer = null
var anim_explode: AnimationPlayer = null
var current_mode = "run"

var walk_phase = 0.0
var is_moving = false

var hp_bar_root: Control
var hp_fill: ColorRect
const HP_BAR_WIDTH = 80.0
const HP_BAR_HEIGHT = 8.0

const GRID_CELL = 1.5
const GRID_SIZE = 60
const GRID_OFFSET = 45.0
const REPATH_INTERVAL = 0.5
const MAX_PATH_ITER = 1500

var current_path: Array = []
var path_index = 0
var repath_timer = 0.0
var _walk_cache: Dictionary = {}

func _ready():
	load_model()
	setup_collision()
	create_hp_bar_ui()
	
	last_destruct_hp = max_hp
	next_destruct_threshold = randf_range(SELF_DESTRUCT_DAMAGE_MIN, SELF_DESTRUCT_DAMAGE_MAX)
	
	# ⭐ 一开始隐藏血条
	if hp_bar_root:
		hp_bar_root.visible = false
	
	await get_tree().process_frame
	target = get_parent().get_node_or_null("CharacterBody3D")
	pick_patrol_target()

# ⭐ 激活：由法阵调用
func activate():
	is_active = true
	if hp_bar_root:
		hp_bar_root.visible = true
	if model_run:
		model_run.visible = true
	if model_idle:
		model_idle.visible = false
	if model_explode:
		model_explode.visible = false
	current_mode = "run"
	print("[CHAIN] 已激活，开始追捕玩家")

# ⭐ 反激活：藏到地底，隐藏血条和模型
func deactivate():
	is_active = false
	if hp_bar_root:
		hp_bar_root.visible = false
	if model_run:
		model_run.visible = false
	if model_idle:
		model_idle.visible = false
	if model_explode:
		model_explode.visible = false
	global_position = Vector3(0, -50, 0)

func load_model():
	var model_scale = Vector3(0.25, 0.25, 0.25)
	
	# --- Run 模型 ---
	var run_scene = load("res://models/run.gltf")
	if run_scene:
		model_run = run_scene.instantiate()
		add_child(model_run)
		model_run.scale = model_scale
		model_run.position = Vector3(0, 0, 0)
		anim_run = model_run.find_child("AnimationPlayer", true, false)
		if anim_run:
			var run_list = anim_run.get_animation_list()
			if run_list.size() > 0:
				var anim_name = run_list[0]
				_set_anim_loop(anim_run, anim_name)
				anim_run.play(anim_name)
				anim_run.speed_scale = 0.7
		print("Run 模型加载")
	
	# --- Idle 模型 ---
	var idle_scene = load("res://models/idle.gltf")
	if idle_scene:
		model_idle = idle_scene.instantiate()
		add_child(model_idle)
		model_idle.scale = model_scale
		model_idle.position = Vector3(0, 0, 0)
		anim_idle = model_idle.find_child("AnimationPlayer", true, false)
		if anim_idle:
			var idle_list = anim_idle.get_animation_list()
			if idle_list.size() > 0:
				var anim_name = idle_list[0]
				_set_anim_loop(anim_idle, anim_name)
				anim_idle.play(anim_name)
		model_idle.visible = false
		print("Idle 模型加载")
	
	# --- Explode 模型 ---
	var explode_scene = load("res://models/explode.gltf")
	if explode_scene:
		model_explode = explode_scene.instantiate()
		add_child(model_explode)
		model_explode.scale = model_scale
		model_explode.position = Vector3(0, 0, 0)
		anim_explode = model_explode.find_child("AnimationPlayer", true, false)
		if anim_explode:
			var exp_list = anim_explode.get_animation_list()
			if exp_list.size() > 0:
				anim_explode.play(exp_list[0])
				anim_explode.pause()
		model_explode.visible = false
		print("Explode 模型加载")
	else:
		print("⚠ 未找到 explode.gltf")
	
	current_mode = "run"

func _set_anim_loop(player: AnimationPlayer, anim_name: String):
	var lib = player.get_animation_library("")
	if not lib:
		return
	var anim = lib.get_animation(anim_name)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR

func set_mode(mode: String):
	if current_mode == mode:
		return
	current_mode = mode
	if mode == "idle":
		if model_idle: model_idle.visible = true
		if model_run: model_run.visible = false
		if model_explode: model_explode.visible = false
	elif mode == "run":
		if model_run: model_run.visible = true
		if model_idle: model_idle.visible = false
		if model_explode: model_explode.visible = false
	elif mode == "explode":
		if model_explode: model_explode.visible = true
		if model_idle: model_idle.visible = false
		if model_run: model_run.visible = false

func setup_collision():
	if not has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		shape.radius = 0.45
		shape.height = 1.5
		col.shape = shape
		col.position.y = 0.75
		add_child(col)

func create_hp_bar_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	hp_bar_root = Control.new()
	hp_bar_root.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	canvas.add_child(hp_bar_root)
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_root.add_child(bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.9, 0.12, 0.12)
	hp_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	hp_bar_root.add_child(hp_fill)
	# ⭐ 初始隐藏
	hp_bar_root.visible = false

func update_hp_bar_visual():
	if not hp_fill:
		return
	var ratio = clamp(hp / max_hp, 0.0, 1.0)
	hp_fill.size.x = HP_BAR_WIDTH * ratio

func update_hp_bar_position():
	if not hp_bar_root:
		return
	# ⭐ 未激活时不显示血条
	if not is_active:
		hp_bar_root.visible = false
		return
	var cam = get_viewport().get_camera_3d()
	if not cam:
		hp_bar_root.visible = false
		return
	var world_pos = global_position + Vector3(0, 2.1, 0)
	if cam.is_position_behind(world_pos):
		hp_bar_root.visible = false
		return
	var screen_pos = cam.unproject_position(world_pos)
	hp_bar_root.visible = true
	hp_bar_root.position = screen_pos - Vector2(HP_BAR_WIDTH / 2.0, HP_BAR_HEIGHT / 2.0)

func _process(delta):
	update_hp_bar_position()

# ⭐ 震撼弹调用
func stun(duration: float):
	stun_time = duration
	attack_anim_time = 0.0
	attack_hit_done = true
	velocity.x = 0
	velocity.z = 0
	print("⚡ CHAIN 被震撼弹眩晕 ", duration, " 秒")
	set_mode("idle")

func _physics_process(delta):
	# ⭐ 未激活：完全冻结，不移动
	if not is_active:
		velocity.x = 0
		velocity.y = 0
		velocity.z = 0
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	if attack_cooldown > 0:
		attack_cooldown -= delta
	
	# ⭐ 自爆动画进行中
	if is_self_destructing:
		self_destruct_timer += delta
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		if target:
			face_direction((target.global_position - global_position).normalized())
		
		# 4.0s 触发伤害
		if not destruct_hit_done and self_destruct_timer >= SELF_DESTRUCT_HIT_TIME:
			destruct_hit_done = true
			do_explosion_damage()
		
		# 4.1s 动画结束
		if self_destruct_timer >= SELF_DESTRUCT_ANIM_DUR:
			is_self_destructing = false
			self_destruct_timer = 0.0
			destruct_hit_done = false
			if is_moving:
				set_mode("run")
			else:
				set_mode("idle")
			return
		
		move_and_slide()
		return
	
	if stun_time > 0:
		stun_time -= delta
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		if attack_anim_time > 0:
			attack_anim_time = 0.0
			attack_hit_done = true
		set_mode("idle")
		move_and_slide()
		return
	
	if attack_anim_time > 0:
		attack_anim_time -= delta
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		if target:
			face_direction((target.global_position - global_position).normalized())
		var elapsed = ATTACK_ANIM_DUR - attack_anim_time
		if not attack_hit_done and elapsed >= ATTACK_HIT_START:
			attack_hit_done = true
			attack_player()
		if attack_anim_time < 0:
			attack_anim_time = 0.0
		move_and_slide()
		return
	
	update_state()
	match state:
		State.PATROL: do_patrol(delta)
		State.CHASE: do_chase(delta)
	
	if is_moving:
		set_mode("run")
	else:
		set_mode("idle")
	
	move_and_slide()

func update_state():
	if not target:
		state = State.PATROL
		return
	var dist = global_position.distance_to(target.global_position)
	match state:
		State.PATROL:
			if dist < VISION_RANGE: state = State.CHASE
		State.CHASE:
			if dist > CHASE_RANGE:
				state = State.PATROL
				current_path.clear()
				pick_patrol_target()

func do_patrol(delta):
	if patrol_wait > 0:
		patrol_wait -= delta
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		return
	var dir = patrol_target - global_position
	dir.y = 0
	var dist = dir.length()
	if dist < 1.0:
		patrol_wait = randf_range(1.5, 3.0)
		pick_patrol_target()
		return
	dir = dir.normalized()
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	is_moving = true
	face_direction(dir)

func pick_patrol_target():
	for i in range(10):
		var angle = randf() * PI * 2
		var dist = randf_range(8.0, 20.0)
		var pos = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		if pos.length() < 45.0:
			patrol_target = pos
			return

func do_chase(delta):
	if not target: return
	var dist = global_position.distance_to(target.global_position)
	if dist < ATTACK_RANGE:
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		current_path.clear()
		face_direction((target.global_position - global_position).normalized())
		if attack_cooldown <= 0: start_attack()
		return
	if has_line_of_sight():
		current_path.clear()
		var dir = target.global_position - global_position
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
		is_moving = true
		face_direction(dir)
	else:
		repath_timer -= delta
		if repath_timer <= 0 or current_path.size() == 0:
			repath_timer = REPATH_INTERVAL
			current_path = find_path(global_position, target.global_position)
			path_index = 0
		if current_path.size() > 0: follow_path()
		else:
			var dir = target.global_position - global_position
			dir.y = 0
			dir = dir.normalized()
			velocity.x = dir.x * chase_speed
			velocity.z = dir.z * chase_speed
			is_moving = true
			face_direction(dir)

func start_attack():
	attack_anim_time = ATTACK_ANIM_DUR
	attack_hit_done = false
	attack_cooldown = ATTACK_COOLDOWN

func face_direction(dir: Vector3):
	if dir.length() > 0.01:
		look_at(Vector3(global_position.x + dir.x, global_position.y, global_position.z + dir.z))

func attack_player():
	if not target: return
	if target.has_method("is_in_parry_window") and target.is_in_parry_window():
		stun_time = STUN_DURATION
		attack_anim_time = 0.0
		attack_hit_done = true
		print("⚡ 擦刀成功！CHAIN 眩晕")
		if target.has_method("on_parry_success"): target.on_parry_success()
	else:
		if target.has_method("take_damage"): target.take_damage(ATTACK_DAMAGE)

func take_damage(amount: float):
	if is_self_destructing: return
	hp -= amount
	update_hp_bar_visual()
	print("CHAIN 受到伤害！剩余血量：", hp)
	if hp <= 0:
		hp = 0
		print("CHAIN 被击败！")
		if hp_bar_root: hp_bar_root.visible = false
		queue_free()
		return
	var damage_since_last = last_destruct_hp - hp
	if damage_since_last >= next_destruct_threshold:
		print("累计扣血 %.1f >= %.1f，触发自爆" % [damage_since_last, next_destruct_threshold])
		last_destruct_hp = hp
		next_destruct_threshold = randf_range(SELF_DESTRUCT_DAMAGE_MIN, SELF_DESTRUCT_DAMAGE_MAX)
		start_self_destruct()

# ⭐ 自爆开始：切模型 + 通知玩家花屏
func start_self_destruct():
	is_self_destructing = true
	self_destruct_timer = 0.0
	destruct_hit_done = false
	attack_anim_time = 0.0
	attack_hit_done = true
	stun_time = 0.0
	current_path.clear()
	set_mode("explode")
	if anim_explode:
		var exp_list = anim_explode.get_animation_list()
		if exp_list.size() > 0:
			anim_explode.play(exp_list[0])
			anim_explode.seek(0, true)
	if hp_fill: hp_fill.color = Color(1.0, 0.6, 0.0)
	
	# ⭐ 通知玩家：触发花屏 + 警告
	if target and target.has_method("trigger_explosion_effect"):
		target.trigger_explosion_effect()
	
	print("⚠⚠⚠ CHAIN 开始自爆动画（%.1fs）" % SELF_DESTRUCT_ANIM_DUR)

# ⭐ 4.0s 时的伤害判定
func do_explosion_damage():
	print("💥💥💥 CHAIN 爆炸伤害！")
	if target and target.has_method("take_damage"):
		var dist = global_position.distance_to(target.global_position)
		if dist <= EXPLOSION_RADIUS:
			var dr = 1.0 - (dist / EXPLOSION_RADIUS)
			var damage = EXPLOSION_MIN_DAMAGE + (EXPLOSION_MAX_DAMAGE - EXPLOSION_MIN_DAMAGE) * dr
			print("💥 距离: %.1fm  伤害: %.1f" % [dist, damage])
			target.take_damage(damage)
		else:
			print("💥 玩家躲过了爆炸（距离 %.1fm）" % dist)

func has_line_of_sight() -> bool:
	if not target: return false
	var from = global_position + Vector3(0, 1.0, 0)
	var to = target.global_position + Vector3(0, 1.0, 0)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self.get_rid(), target.get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func follow_path():
	while path_index < current_path.size():
		var wp = current_path[path_index]
		var to_wp = wp - global_position
		to_wp.y = 0
		if to_wp.length() < 0.9: path_index += 1
		else: break
	if path_index >= current_path.size():
		velocity.x = 0
		velocity.z = 0
		is_moving = false
		return
	var wp = current_path[path_index]
	var dir = wp - global_position
	dir.y = 0
	dir = dir.normalized()
	velocity.x = dir.x * chase_speed
	velocity.z = dir.z * chase_speed
	is_moving = true
	face_direction(dir)

func find_path(start_world: Vector3, end_world: Vector3) -> Array:
	_walk_cache.clear()
	var start_grid = world_to_grid(start_world)
	var end_grid = world_to_grid(end_world)
	if not is_walkable(end_grid):
		end_grid = find_nearest_walkable(end_grid)
		if end_grid.x < 0: return []
	var open = {}
	var closed = {}
	var sk = _gkey(start_grid)
	open[sk] = {"pos": start_grid, "g": 0.0, "h": _heur(start_grid, end_grid), "parent": null}
	var iter = 0
	while open.size() > 0 and iter < MAX_PATH_ITER:
		iter += 1
		var best_key = ""
		var best_f = INF
		for k in open.keys():
			var n = open[k]
			var f = n.g + n.h
			if f < best_f:
				best_f = f
				best_key = k
		var cur = open[best_key]
		open.erase(best_key)
		closed[best_key] = true
		if cur.pos == end_grid:
			return _build_path(cur)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				if dx == 0 and dz == 0: continue
				var nb = cur.pos + Vector2i(dx, dz)
				var nk = _gkey(nb)
				if closed.has(nk): continue
				if not is_walkable(nb): continue
				if dx != 0 and dz != 0:
					if not is_walkable(cur.pos + Vector2i(dx, 0)): continue
					if not is_walkable(cur.pos + Vector2i(0, dz)): continue
				var step = 1.0 if (dx == 0 or dz == 0) else 1.414
				var ng = cur.g + step
				if open.has(nk):
					if ng < open[nk].g:
						open[nk].g = ng
						open[nk].parent = cur
				else:
					open[nk] = {"pos": nb, "g": ng, "h": _heur(nb, end_grid), "parent": cur}
	return []

func _build_path(node) -> Array:
	var path = []
	var n = node
	while n != null:
		path.append(grid_to_world(n.pos))
		n = n.parent
	path.reverse()
	if path.size() > 0: path.remove_at(0)
	return path

func _heur(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _gkey(pos: Vector2i) -> String:
	return str(pos.x) + "," + str(pos.y)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((world_pos.x + GRID_OFFSET) / GRID_CELL)),
		int(floor((world_pos.z + GRID_OFFSET) / GRID_CELL))
	)

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		(grid_pos.x + 0.5) * GRID_CELL - GRID_OFFSET,
		0,
		(grid_pos.y + 0.5) * GRID_CELL - GRID_OFFSET
	)

func is_walkable(grid_pos: Vector2i) -> bool:
	if grid_pos.x < 0 or grid_pos.x >= GRID_SIZE: return false
	if grid_pos.y < 0 or grid_pos.y >= GRID_SIZE: return false
	var key = grid_pos.x * 10000 + grid_pos.y
	if _walk_cache.has(key): return _walk_cache[key]
	var world_pos = grid_to_world(grid_pos)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		world_pos + Vector3(0, 2.5, 0),
		world_pos + Vector3(0, 0.3, 0)
	)
	query.exclude = [self.get_rid()]
	if target: query.exclude.append(target.get_rid())
	var result = space_state.intersect_ray(query)
	var walkable = result.is_empty()
	_walk_cache[key] = walkable
	return walkable

func find_nearest_walkable(center: Vector2i) -> Vector2i:
	if is_walkable(center): return center
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if abs(dx) != r and abs(dz) != r: continue
				var p = center + Vector2i(dx, dz)
				if is_walkable(p): return p
	return Vector2i(-1, -1)
