extends RefCounted
## Impact punctuation is cosmetic but contractual: authored styles, terminal
## wall/body hits, nonterminal soft spatter, pool hygiene, and host shot IDs.

const ProjectileScene := preload("res://weapons/projectile.tscn")
const MissileScene := preload("res://weapons/missile.tscn")
const ImpactScene := preload("res://weapons/impact_fx.tscn")
const NetEvents := preload("res://game/net/net_events.gd")
const SOFT := 1 << 9

var t

func _init(runner) -> void:
	t = runner

func test_authored_styles_and_reset() -> void:
	var bullet: Projectile = ProjectileScene.instantiate()
	var missile: Projectile = MissileScene.instantiate()
	t.check(bullet.impact_style == Projectile.ImpactStyle.SPARK,
		"impact: standard projectile authors a spark")
	t.check(missile.impact_style == Projectile.ImpactStyle.MISSILE,
		"impact: shared missile authors the compact explosion")
	var fx: ImpactFX = ImpactScene.instantiate()
	fx.setup(Vector2(11, 22), Projectile.ImpactStyle.SPATTER)
	t.check(fx.style == Projectile.ImpactStyle.SPATTER and fx.visible,
		"impact: setup stamps style and activates pooled visual")
	fx.pool_reset()
	t.check(fx.style == Projectile.ImpactStyle.NONE and not fx.visible,
		"impact: pool reset sheds style and visibility")
	bullet.free()
	missile.free()
	fx.free()

func test_body_impacts_are_terminal_with_or_without_health() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var wall := StaticBody2D.new()
	container.add_child(wall)
	var shot: Projectile = ProjectileScene.instantiate()
	container.add_child(shot)
	shot.setup(Vector2(5, 6), Vector2.RIGHT, 100.0, 3.0, 1.0, null)
	shot._on_body_entered(wall)
	t.check(shot._spent, "impact: a wall without Health still consumes the bullet")
	t.check(_find_fx(container, Projectile.ImpactStyle.SPARK) != null,
		"impact: a wall without Health still answers with a spark")
	var body := StaticBody2D.new()
	var health := Health.new()
	health.max_hp = 10.0
	health.hp = 10.0
	body.add_child(health)
	container.add_child(body)
	var missile: Projectile = MissileScene.instantiate()
	container.add_child(missile)
	missile.setup(Vector2(9, 10), Vector2.RIGHT, 100.0, 4.0, 1.0, null)
	missile._on_body_entered(body)
	t.check(is_equal_approx(health.hp, 6.0) and missile._spent,
		"impact: Health-bearing cover takes damage and consumes the missile")
	t.check(_find_fx(container, Projectile.ImpactStyle.MISSILE) != null,
		"impact: missile collision uses compact missile punctuation")
	t.root.remove_child(container)
	container.free()

func test_soft_target_spatters_without_consuming_shot() -> void:
	var container := Node2D.new()
	t.root.add_child(container)
	var soft := Area2D.new()
	soft.collision_layer = SOFT
	var health := Health.new()
	health.max_hp = 1.0
	health.hp = 1.0
	soft.add_child(health)
	container.add_child(soft)
	var shot: Projectile = ProjectileScene.instantiate()
	container.add_child(shot)
	shot.setup(Vector2.ZERO, Vector2.RIGHT, 100.0, 3.0, 1.0, null)
	shot._on_area_entered(soft)
	t.check(not shot._spent, "impact: soft target never consumes the projectile")
	t.check(health.hp <= 0.0, "impact: soft target still takes its cosmetic one HP")
	t.check(_find_fx(container, Projectile.ImpactStyle.SPATTER) != null,
		"impact: soft pass-through uses minimal red spatter")
	t.root.remove_child(container)
	container.free()

func test_network_shot_id_and_impact_lifecycle() -> void:
	NetEvents.reset()
	t.check(NetEvents.projectile_spawned("res://weapons/projectile.tscn", Vector2.ZERO,
		Vector2.RIGHT, 1.0, 1.0, 0.0, null) == 0,
		"impact net: dormant tap allocates no shot id")
	NetEvents.armed = true
	var first := NetEvents.projectile_spawned("res://weapons/projectile.tscn", Vector2.ZERO,
		Vector2.RIGHT, 1.0, 1.0, 0.0, null)
	var second := NetEvents.projectile_spawned("res://weapons/projectile.tscn", Vector2.ZERO,
		Vector2.RIGHT, 1.0, 1.0, 0.0, null)
	NetEvents.projectile_impact(first, Vector2(4, 8), Projectile.ImpactStyle.SPARK, true)
	var events := NetEvents.drain()
	t.check(first == 1 and second == 2, "impact net: host shot IDs are monotonic u32 values")
	t.check(events.size() == 3 and events[2].shot_id == first and events[2].terminal,
		"impact net: impact carries its shot identity and terminal state")
	NetEvents.reset()
	NetEvents.armed = true
	t.check(NetEvents.projectile_spawned("res://weapons/projectile.tscn", Vector2.ZERO,
		Vector2.RIGHT, 1.0, 1.0, 0.0, null) == 1,
		"impact net: session reset restarts the shot-id lifecycle")
	NetEvents.reset()

func _find_fx(root: Node, wanted: int) -> ImpactFX:
	for child in root.get_children():
		if child is ImpactFX and child.style == wanted:
			return child
	return null
