extends Node2D

# ─── Constants ───
const TILE = 64
const FOV = PI / 3
const HALF_FOV = FOV / 2

const MAP = [
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,1,0,1,0,0,0,0,0,1,0,1,0,0,1],
	[1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1],
	[1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1],
	[1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,0,0,0,0,1,1,1,1,0,0,0,0,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1],
	[1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,1],
	[1,0,1,0,0,0,0,0,0,0,0,0,1,0,0,1],
	[1,0,1,0,1,0,0,0,0,0,1,0,1,0,0,1],
	[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
	[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
]
const MAP_W = 16
const MAP_H = 16

var WEAPONS = {
	"pistol": {"name": "Pistole", "dmg": 34, "fire_rate": 0.35, "ammo": INF, "max_ammo": INF, "auto": false},
	"mp5": {"name": "MP5", "dmg": 20, "fire_rate": 0.08, "ammo": 120, "max_ammo": 120, "auto": true, "spread": 0.05},
	"flamer": {"name": "Flammenwerfer", "dmg": 8, "fire_rate": 0.03, "ammo": 100, "max_ammo": 100, "auto": true, "cone": 0.35, "range": 200},
	"sniper": {"name": "Sniper", "dmg": 150, "fire_rate": 1.2, "ammo": 30, "max_ammo": 30, "auto": false, "sniper": true},
}

# ─── State ───
var player = {
	"x": 3.5 * TILE, "y": 5.5 * TILE, "angle": 0.0, "pitch": 0.0,
	"hp": 150, "speed": 2.8, "turn_speed": 0.045,
	"jump_z": 0.0, "jump_vz": 0.0, "jumping": false, "floor_z": 0.0
}
var enemies = []
var enemy_bullets = []
var particles = []
var grenades = []
var wall_distances = []

var current_weapon = "pistol"
var last_shot = {}
var grenade_count = 3
var wave = 0
var score = 0
var wave_timer = 0.0
var enemies_to_spawn = 0
var spawn_timer = 0.0
var game_running = false
var muzzle_flash = false
var muzzle_timer = 0.0

var W = 960.0
var H = 540.0

# ─── Audio ───
var audio_players = []
var default_font: Font

func _ready():
	W = get_viewport().get_window().size.x
	H = get_viewport().get_window().size.y
	default_font = get_window().get_theme_default_font()

func _process(dt):
	if not game_running:
		if Input.is_action_just_pressed("start"):
			start_game()
		queue_redraw()
		return

	if dt > 0.05: dt = 0.05
	update_game(dt)
	queue_redraw()

func _draw():
	render()

# ─── Game Logic ───
func start_game():
	game_running = true
	init_game()

func init_game():
	player.x = 3.5 * TILE
	player.y = 5.5 * TILE
	player.angle = 0.0
	player.pitch = 0.0
	player.hp = 150
	player.jump_z = 0.0
	player.jump_vz = 0.0
	player.jumping = false
	player.floor_z = 0.0
	enemies = []
	enemy_bullets = []
	particles = []
	grenades = []
	current_weapon = "pistol"
	last_shot = {}
	wave = 0
	score = 0
	grenade_count = 3
	muzzle_flash = false
	muzzle_timer = 0.0
	for k in WEAPONS:
		WEAPONS[k]["ammo"] = WEAPONS[k]["max_ammo"]
	start_wave()

func start_wave():
	wave += 1
	enemies_to_spawn = 1
	spawn_timer = 0.0
	snd_wave()

func spawn_enemy():
	var x = 0.0
	var y = 0.0
	for i in range(20):
		var mx = randi() % MAP_W
		var my = randi() % MAP_H
		if MAP[my][mx] == 0:
			x = (mx + 0.5) * TILE
			y = (my + 0.5) * TILE
			if Vector2(x, y).distance_to(Vector2(player.x, player.y)) > TILE * 3:
				break
	var boss_weapons = ["pistol", "mp5", "flamer", "sniper"]
	enemies.append({
		"x": x, "y": y, "r": 14,
		"hp": 80 + wave * 40, "speed": 1.0 + wave * 0.1,
		"dmg": 10 + wave * 3, "color": Color.RED,
		"can_shoot": wave >= 2,
		"shot_timer": 1000.0,
		"boss_weapons": boss_weapons.duplicate(),
		"boss_weapon_idx": 0,
		"weapon_swap_timer": 4000.0,
		"wave": wave
	})

func kill_enemy(e):
	var idx = enemies.find(e)
	if idx >= 0: enemies.remove_at(idx)
	score += 50 + wave * 10
	grenade_count = min(5, grenade_count + 1)
	if randf() < 0.2:
		var wks = ["mp5", "flamer", "sniper"]
		var wk = wks[randi() % wks.size()]
		WEAPONS[wk]["ammo"] = min(WEAPONS[wk]["max_ammo"], WEAPONS[wk]["ammo"] + int(WEAPONS[wk]["max_ammo"] * 0.3))

func tile_at(x, y):
	var mx = int(float(x) / TILE)
	var my = int(float(y) / TILE)
	if my < 0 or my >= MAP_H or mx < 0 or mx >= MAP_W: return 1
	return MAP[my][mx]

func can_move(nx, ny):
	var r = 12
	var corners = [[nx-r, ny-r], [nx+r, ny-r], [nx-r, ny+r], [nx+r, ny+r]]
	var player_top = player.floor_z + player.jump_z
	for c in corners:
		var mx = int(float(c[0]) / TILE)
		var my = int(float(c[1]) / TILE)
		if my < 0 or my >= MAP_H or mx < 0 or mx >= MAP_W: return false
		if MAP[my][mx] == 1:
			if player_top < TILE - 5: return false
	return true

func cast_ray(angle):
	var dx = cos(angle)
	var dy = sin(angle)
	var map_x = int(float(player.x) / TILE)
	var map_y = int(float(player.y) / TILE)
	var ddx = 1e30 if dx == 0 else abs(1.0 / dx)
	var ddy = 1e30 if dy == 0 else abs(1.0 / dy)
	var step_x = 1 if dx > 0 else -1
	var step_y = 1 if dy > 0 else -1
	var side_x = (map_x + 1 - player.x/TILE) * ddx if dx > 0 else (player.x/TILE - map_x) * ddx
	var side_y = (map_y + 1 - player.y/TILE) * ddy if dy > 0 else (player.y/TILE - map_y) * ddy
	var _hit = false
	var side = 0
	for i in range(50):
		if side_x < side_y:
			side_x += ddx; map_x += step_x; side = 0
		else:
			side_y += ddy; map_y += step_y; side = 1
		if map_y < 0 or map_y >= MAP_H or map_x < 0 or map_x >= MAP_W:
			_hit = true; break
		if MAP[map_y][map_x] == 1:
			_hit = true; break
	var pd = 0.01
	if side == 0:
		pd = (map_x - player.x/TILE + (1 - step_x) / 2.0) / dx
	else:
		pd = (map_y - player.y/TILE + (1 - step_y) / 2.0) / dy
	if pd < 0.01: pd = 0.01
	return pd * TILE

func try_jump():
	if not game_running or player.jumping: return
	player.jumping = true
	player.jump_vz = 11.0
	snd_jump()
	if player.floor_z > 0:
		player.jump_z = player.floor_z
		player.floor_z = 0.0

func throw_grenade():
	if not game_running or grenade_count <= 0: return
	grenade_count -= 1
	grenades.append({
		"x": player.x, "y": player.y,
		"vx": cos(player.angle) * 4, "vy": sin(player.angle) * 4,
		"z": 0.0, "vz": 6.0, "timer": 1.5, "exploded": false
	})

func try_shoot(now):
	var w = WEAPONS[current_weapon]
	if w.ammo <= 0: return
	if now - (last_shot.get(current_weapon, 0.0)) < w.fire_rate: return
	last_shot[current_weapon] = now
	w.ammo -= 1
	muzzle_flash = true
	muzzle_timer = 0.08
	snd_shoot(current_weapon)

	var aim = player.angle + (w.get("spread", 0) * (randf() - 0.5) if w.has("spread") else 0.0)

	if current_weapon == "flamer":
		for e in enemies:
			var dx = e.x - player.x
			var dy = e.y - player.y
			var dist = sqrt(dx*dx + dy*dy)
			if dist > w.range: continue
			var ang = atan2(dy, dx)
			var diff = abs(ang - player.angle)
			if diff > PI: diff = PI * 2 - diff
			if diff < w.cone:
				var wd = cast_ray(ang)
				if dist < wd:
					var headshot = player.pitch > 0.15
					var dmg = w.dmg * (3 if headshot else 1)
					e.hp -= dmg
					if headshot: snd_headshot()
					else: snd_hit()
					if e.hp <= 0: kill_enemy(e)
	elif current_weapon == "sniper":
		var hit = []
		for e in enemies:
			var dx = e.x - player.x
			var dy = e.y - player.y
			var dist = sqrt(dx*dx + dy*dy)
			var ang = atan2(dy, dx)
			var diff = abs(ang - aim)
			if diff > PI: diff = PI * 2 - diff
			var ang_size = atan2(e.r, dist)
			if diff < ang_size:
				var wd = cast_ray(ang)
				if dist < wd: hit.append(e)
		for e in hit:
			var headshot = player.pitch > 0.15
			var dmg = w.dmg * (3 if headshot else 1)
			e.hp -= dmg
			if headshot: snd_headshot()
			else: snd_hit()
			if e.hp <= 0: kill_enemy(e)
	else:
		var closest = null
		var closest_dist = INF
		for e in enemies:
			var dx = e.x - player.x
			var dy = e.y - player.y
			var dist = sqrt(dx*dx + dy*dy)
			var ang = atan2(dy, dx)
			var diff = abs(ang - aim)
			if diff > PI: diff = PI * 2 - diff
			var ang_size = atan2(e.r, dist)
			if diff < ang_size and dist < closest_dist:
				var wd = cast_ray(ang)
				if dist < wd:
					closest = e
					closest_dist = dist
		if closest:
			var headshot = player.pitch > 0.15
			var dmg = w.dmg * (3 if headshot else 1)
			closest.hp -= dmg
			if headshot: snd_headshot()
			else: snd_hit()
			if closest.hp <= 0: kill_enemy(closest)

func switch_weapon(k):
	if WEAPONS.has(k) and WEAPONS[k].ammo > 0:
		current_weapon = k

func reload():
	var w = WEAPONS[current_weapon]
	if w.max_ammo != INF: w.ammo = w.max_ammo
	snd_reload()

# ─── Update ───
func update_game(dt):
	# Turning
	var ts = player.turn_speed * dt * 60
	var turn_input = (1 if Input.is_action_pressed("turn_right") else 0) - (1 if Input.is_action_pressed("turn_left") else 0)
	player.angle += ts * turn_input

	# Pitch
	var pitch_speed = 0.03 * dt * 60
	var pitch_input = (1 if Input.is_action_pressed("look_up") else 0) - (1 if Input.is_action_pressed("look_down") else 0)
	player.pitch += pitch_speed * pitch_input
	player.pitch = clamp(player.pitch, -0.6, 0.6)

	# Movement
	var ps = player.speed * dt * 60
	var fwd = (1 if Input.is_action_pressed("move_forward") else 0) - (1 if Input.is_action_pressed("move_back") else 0)
	if fwd != 0:
		var nx = player.x + cos(player.angle) * fwd * ps
		var ny = player.y + sin(player.angle) * fwd * ps
		if can_move(nx, player.y): player.x = nx
		if can_move(player.x, ny): player.y = ny

	# Shooting
	var w = WEAPONS[current_weapon]
	var shooting = Input.is_action_pressed("shoot")
	if shooting and (w.auto or not last_shot.get("_semi", false)):
		try_shoot(Time.get_ticks_msec() / 1000.0)
		if not w.auto: last_shot["_semi"] = true
	if not shooting: last_shot["_semi"] = false

	# Jump
	if Input.is_action_just_pressed("jump"): try_jump()
	if Input.is_action_just_pressed("grenade"): throw_grenade()
	if Input.is_action_just_pressed("reload"): reload()
	if Input.is_action_just_pressed("weapon_1"): switch_weapon("pistol")
	if Input.is_action_just_pressed("weapon_2"): switch_weapon("mp5")
	if Input.is_action_just_pressed("weapon_3"): switch_weapon("flamer")
	if Input.is_action_just_pressed("weapon_4"): switch_weapon("sniper")

	# Jump physics
	if player.jumping:
		player.jump_vz -= 0.6 * dt * 60
		player.jump_z += player.jump_vz * dt * 60
		if player.jump_z <= 0:
			var on_wall = tile_at(player.x, player.y) == 1
			if on_wall and player.floor_z == 0:
				player.floor_z = TILE
			player.jump_z = 0; player.jump_vz = 0; player.jumping = false

	# Walked off wall
	if not player.jumping and player.floor_z > 0:
		if tile_at(player.x, player.y) != 1:
			player.jumping = true
			player.jump_z = player.floor_z
			player.floor_z = 0
			player.jump_vz = 0

	# Muzzle flash
	if muzzle_timer > 0:
		muzzle_timer -= dt
		if muzzle_timer <= 0: muzzle_flash = false

	# Enemies
	for e in enemies:
		var dx = player.x - e.x
		var dy = player.y - e.y
		var dist = sqrt(dx*dx + dy*dy)
		var step = e.speed * dt * 60
		if dist > 0:
			var nx = e.x + (dx/dist) * step
			var ny = e.y + (dy/dist) * step
			if can_move(nx, e.y): e.x = nx
			if can_move(e.x, ny): e.y = ny
		if dist < e.r + 14 and (player.floor_z + player.jump_z) < 20:
			player.hp -= e.dmg * dt
			if player.hp <= 0:
				player.hp = 0
				game_over()
		if e.can_shoot and dist < 600:
			e.weapon_swap_timer -= dt * 1000
			if e.weapon_swap_timer <= 0:
				e.boss_weapon_idx = (e.boss_weapon_idx + 1) % e.boss_weapons.size()
				e.weapon_swap_timer = 4000 + randf() * 2000
				e.shot_timer = 500
			e.shot_timer -= dt * 1000
			if e.shot_timer <= 0:
				var ang = atan2(dy, dx) + (randf() - 0.5) * 0.08
				var bw = e.boss_weapons[e.boss_weapon_idx]
				if bw == "flamer":
					for s in range(-2, 3):
						var sa = ang + s * 0.12
						enemy_bullets.append({"x": e.x, "y": e.y, "vx": cos(sa)*4, "vy": sin(sa)*4, "dmg": 6+wave, "r": 5, "life": 120, "color": Color.ORANGE})
					e.shot_timer = 300
				elif bw == "sniper":
					enemy_bullets.append({"x": e.x, "y": e.y, "vx": cos(ang)*9, "vy": sin(ang)*9, "dmg": 25+wave*5, "r": 5, "life": 300, "color": Color.CYAN})
					e.shot_timer = 1500
				elif bw == "mp5":
					enemy_bullets.append({"x": e.x, "y": e.y, "vx": cos(ang)*6, "vy": sin(ang)*6, "dmg": 8+wave*2, "r": 5, "life": 250, "color": Color.YELLOW})
					e.shot_timer = 200
				else:
					enemy_bullets.append({"x": e.x, "y": e.y, "vx": cos(ang)*5, "vy": sin(ang)*5, "dmg": 12+wave*3, "r": 6, "life": 300, "color": Color.ORANGE_RED})
					e.shot_timer = 600
				snd_enemy_shoot(bw)

	# Enemy bullets
	for i in range(enemy_bullets.size() - 1, -1, -1):
		var b = enemy_bullets[i]
		b.x += b.vx * dt * 60
		b.y += b.vy * dt * 60
		b.life -= dt * 60
		if b.life <= 0:
			enemy_bullets.remove_at(i)
			continue
		var mx = int(float(b.x) / TILE)
		var my = int(float(b.y) / TILE)
		if my >= 0 and my < MAP_H and mx >= 0 and mx < MAP_W and MAP[my][mx] == 1:
			enemy_bullets.remove_at(i)
			continue
		if sqrt((b.x-player.x)**2 + (b.y-player.y)**2) < 14 + b.r and (player.floor_z + player.jump_z) < 5:
			player.hp -= b.dmg
			enemy_bullets.remove_at(i)
			if player.hp <= 0:
				player.hp = 0
				game_over()

	# Grenades
	for i in range(grenades.size() - 1, -1, -1):
		var g = grenades[i]
		if not g.exploded:
			g.x += g.vx * dt * 60
			g.y += g.vy * dt * 60
			g.z += g.vz * dt * 60
			g.vz -= 0.3 * dt * 60
			if g.z <= 0: g.z = 0; g.vz = 0; g.vx *= 0.5; g.vy *= 0.5
			g.timer -= dt
			if g.timer <= 0:
				g.exploded = true
				snd_explosion()
				for e in enemies:
					var d = sqrt((e.x-g.x)**2 + (e.y-g.y)**2)
					if d < 120:
						e.hp -= 100 * (1 - d/120.0)
						if e.hp <= 0: kill_enemy(e)
				var pd = sqrt((player.x-g.x)**2 + (player.y-g.y)**2)
				if pd < 100:
					player.hp -= 30 * (1 - pd/100.0)
		else:
			g.timer -= dt
			if g.timer <= -0.3:
				grenades.remove_at(i)

	# Particles
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.x += p.vx; p.y += p.vy
		p.vx *= 0.92; p.vy *= 0.92
		p.life -= 1
		if p.life <= 0: particles.remove_at(i)

	# Spawn
	if enemies_to_spawn > 0:
		spawn_timer -= dt * 1000
		if spawn_timer <= 0:
			spawn_enemy()
			enemies_to_spawn -= 1
			spawn_timer = max(500, 1500 - wave * 50)
	elif enemies.size() == 0:
		wave_timer -= dt * 1000
		if wave_timer <= 0:
			wave_timer = 2000
			start_wave()

func game_over():
	game_running = false
	snd_game_over()

# ─── Render ───
func render():
	var cam_y = (player.jump_z + player.floor_z) * 0.8 + player.pitch * H * 0.4

	# Sky + floor
	draw_rect(Rect2(0, 0, W, H/2 - cam_y), Color("1a1a2e"))
	draw_rect(Rect2(0, H/2 - cam_y, W, H/2 + cam_y), Color("2a2a3e"))

	# Walls
	wall_distances = []
	wall_distances.resize(W)
	for x in range(W):
		var ra = player.angle - HALF_FOV + (float(x) / W) * FOV
		var dist = cast_ray(ra)
		wall_distances[x] = dist
		var cd = dist * cos(ra - player.angle)
		if cd < 1: cd = 1
		var wall_h = (TILE * H) / cd
		var wall_top = H/2 - wall_h/2 - cam_y
		var shade = clamp(1.0 - cd / 600.0, 0.15, 1.0)
		var side = abs(fmod(ra, PI))
		if side < 0.5 or side > 2.64: shade *= 0.7
		draw_rect(Rect2(x, wall_top, 1, wall_h), Color(0.4 * shade, 0.4 * shade, 0.5 * shade))

	# Enemies
	var sorted_enemies = enemies.duplicate()
	sorted_enemies.sort_custom(func(a, b):
		return Vector2(b.x, b.y).distance_to(Vector2(player.x, player.y)) > Vector2(a.x, a.y).distance_to(Vector2(player.x, player.y)))
	for e in sorted_enemies:
		var dx = e.x - player.x
		var dy = e.y - player.y
		var dist = sqrt(dx*dx + dy*dy)
		if dist < 5: continue
		var ang = atan2(dy, dx)
		var rel = ang - player.angle
		while rel > PI: rel -= PI * 2
		while rel < -PI: rel += PI * 2
		if abs(rel) > HALF_FOV + 0.2: continue
		var cd = dist * cos(rel)
		var sx = W/2 + (rel / HALF_FOV) * (W/2)
		var size = min(H * 2, (TILE * H * 0.8) / max(1, cd))
		var col = int(sx)
		if col < 0 or col >= W or cd >= wall_distances[col]: continue

		var cy = H/2 - cam_y
		var hs = size / 2
		var bw = hs * 0.7
		var bh = hs * 1.4

		# Legs
		draw_rect(Rect2(sx - bw*0.35, cy + hs*0.2, bw*0.25, hs*0.6), Color("2a2a2a"))
		draw_rect(Rect2(sx + bw*0.1, cy + hs*0.2, bw*0.25, hs*0.6), Color("2a2a2a"))
		# Torso
		draw_rect(Rect2(sx - bw/2, cy - hs*0.3, bw, bh*0.55), e.color)
		# Arms
		draw_rect(Rect2(sx - bw*0.65, cy - hs*0.2, bw*0.15, hs*0.4), e.color)
		draw_rect(Rect2(sx + bw*0.5, cy - hs*0.2, bw*0.15, hs*0.4), e.color)
		# Head
		draw_circle(Vector2(sx, cy - hs*0.5), hs*0.28, Color("d4a373"))
		# Eyes
		draw_circle(Vector2(sx - hs*0.1, cy - hs*0.52), hs*0.06, Color.RED)
		draw_circle(Vector2(sx + hs*0.1, cy - hs*0.52), hs*0.06, Color.RED)
		# Weapon
		var bw_name = e.boss_weapons[e.boss_weapon_idx] if e.has("boss_weapons") else ""
		if bw_name:
			var wx = sx + bw*0.55
			var wy = cy - hs*0.1
			if bw_name == "sniper":
				draw_rect(Rect2(wx, wy - hs*0.04, hs*0.8, hs*0.08), Color("0aa"))
			elif bw_name == "mp5":
				draw_rect(Rect2(wx, wy - hs*0.06, hs*0.45, hs*0.12), Color("cc0"))
			elif bw_name == "flamer":
				draw_rect(Rect2(wx, wy - hs*0.08, hs*0.4, hs*0.16), Color("c60"))
			else:
				draw_rect(Rect2(wx, wy - hs*0.04, hs*0.25, hs*0.1), Color("888"))
		# HP bar
		var bar_w = size * 0.8
		var max_hp = 80 + e.wave * 40
		var hp_r = clamp(e.hp / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(sx - bar_w/2, cy - hs - 8, bar_w, 4), Color("333"))
		var hp_color = Color.GREEN if hp_r > 0.5 else Color.YELLOW if hp_r > 0.25 else Color.RED
		draw_rect(Rect2(sx - bar_w/2, cy - hs - 8, bar_w * hp_r, 4), hp_color)

	# Enemy bullets
	for b in enemy_bullets:
		var dx = b.x - player.x
		var dy = b.y - player.y
		var dist = sqrt(dx*dx + dy*dy)
		if dist < 5: continue
		var ang = atan2(dy, dx)
		var rel = ang - player.angle
		while rel > PI: rel -= PI * 2
		while rel < -PI: rel += PI * 2
		if abs(rel) > HALF_FOV + 0.2: continue
		var cd = dist * cos(rel)
		var sx = W/2 + (rel / HALF_FOV) * (W/2)
		var size = min(H, (TILE * H * 0.15) / max(1, cd))
		var col = int(sx)
		if col >= 0 and col < W and cd < wall_distances[col]:
			draw_circle(Vector2(sx, H/2 - cam_y), size, b.color)

	# Crosshair
	var ch_color = Color(1, 1, 1, 0.6)
	draw_line(Vector2(W/2-10, H/2 - cam_y), Vector2(W/2-4, H/2 - cam_y), ch_color, 2)
	draw_line(Vector2(W/2+4, H/2 - cam_y), Vector2(W/2+10, H/2 - cam_y), ch_color, 2)
	draw_line(Vector2(W/2, H/2-10 - cam_y), Vector2(W/2, H/2-4 - cam_y), ch_color, 2)
	draw_line(Vector2(W/2, H/2+4 - cam_y), Vector2(W/2, H/2+10 - cam_y), ch_color, 2)

	# HUD
	draw_string(default_font, Vector2(10, 25), "HP: %d" % int(max(0, player.hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(default_font, Vector2(10, 50), "SCORE: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(default_font, Vector2(10, 75), "WAVE: %d" % wave, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(default_font, Vector2(10, 100), "GRANATEN: %d" % grenade_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(default_font, Vector2(W/2 - 50, H - 30), WEAPONS[current_weapon].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

	# Start screen
	if not game_running:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.85))
		draw_string(default_font, Vector2(W/2 - 80, H/2 - 40), "SHOOTER FPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(default_font, Vector2(W/2 - 120, H/2 + 10), "Druecke [E] um zu starten", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.GRAY)
		draw_string(default_font, Vector2(W/2 - 180, H/2 + 50), "WASD - Bewegen | Leertaste - Schiessen | Shift - Springen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.DIM_GRAY)
		draw_string(default_font, Vector2(W/2 - 180, H/2 + 70), "Q - Granate | R/F - Schauen | 1-4 - Waffe | N - Nachladen", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.DIM_GRAY)

# ─── Sound ───
func play_tone(freq, dur, _type, vol, slide):
	# Simple beep using AudioStreamPlayer
	var player_node = AudioStreamPlayer.new()
	add_child(player_node)
	# Generate a simple WAV-like tone
	var sample_rate = 44100
	var num_samples = int(sample_rate * dur)
	var audio = StreamPeerBuffer.new()
	# WAV header
	audio.put_data("RIFF".to_ascii_buffer())
	audio.put_32(36 + num_samples * 2)
	audio.put_data("WAVE".to_ascii_buffer())
	audio.put_data("fmt ".to_ascii_buffer())
	audio.put_32(16)
	audio.put_16(1) # PCM
	audio.put_16(1) # mono
	audio.put_32(sample_rate)
	audio.put_32(sample_rate * 2)
	audio.put_16(2)
	audio.put_16(16)
	audio.put_data("data".to_ascii_buffer())
	audio.put_32(num_samples * 2)
	for i in range(num_samples):
		var t = float(i) / sample_rate
		var f = freq
		if slide: f = freq * pow(slide / freq, t / dur)
		var val = sin(f * t * PI * 2) * vol * (1 - float(i) / num_samples)
		audio.put_16(int(val * 32767))
	audio.seek(0)
	var stream = AudioStreamWAV.new()
	stream.data = audio.get_data_array()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	player_node.stream = stream
	player_node.play()
	audio_players.append(player_node)
	# Cleanup after playback
	get_tree().create_timer(dur + 0.1).timeout.connect(func(): player_node.queue_free())

func snd_shoot(weapon):
	match weapon:
		"pistol": play_tone(220, 0.08, "square", 0.12, 80)
		"mp5": play_tone(180, 0.05, "sawtooth", 0.1, 60)
		"sniper": play_tone(150, 0.15, "sawtooth", 0.18, 40)
		"flamer": play_tone(100, 0.12, "sawtooth", 0.08, 50)

func snd_explosion():
	play_tone(60, 0.4, "sine", 0.2, 20)

func snd_jump():
	play_tone(300, 0.15, "sine", 0.1, 600)

func snd_hit():
	play_tone(100, 0.05, "square", 0.08, 50)

func snd_headshot():
	play_tone(800, 0.08, "sine", 0.15, 1200)

func snd_reload():
	play_tone(400, 0.05, "square", 0.08, 0)

func snd_enemy_shoot(weapon):
	match weapon:
		"sniper": play_tone(120, 0.1, "sawtooth", 0.06, 40)
		"flamer": play_tone(80, 0.08, "sawtooth", 0.04, 50)
		_: play_tone(160, 0.05, "square", 0.05, 60)

func snd_wave():
	play_tone(440, 0.15, "sine", 0.1, 660)

func snd_game_over():
	play_tone(200, 0.5, "sawtooth", 0.15, 50)
