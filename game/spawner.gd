extends Node
## Projectile pool. Weapons acquire() instead of instantiate() and spent shots
## release() themselves instead of queue_free() — a dozen shooters' churn
## becomes reuse. Nodes opt in to being recycled via a pool_reset() method
## (called when they return); anything without one is simply freed. Duck-typed
## only — this script never names Vehicle or Projectile, so it can pool any
## scene. Every call site falls back to instantiate/queue_free when
## /root/Spawner is missing (bare fixtures, tools) or the pool is disabled.

static var pool_enabled := true   # kill switch (perf A/B, debugging)
static var pool_cap := 48         # idle nodes kept per scene key; overflow freed

var _pools: Dictionary = {}       # scene resource_path -> Array of idle nodes

func acquire(scene: PackedScene) -> Node:
	var key := scene.resource_path
	if pool_enabled and key != "":
		var bucket: Array = _pools.get(key, [])
		while not bucket.is_empty():
			var node: Node = bucket.pop_back()
			if is_instance_valid(node):
				node.set_meta(&"pool_idle", false)
				return node
	var fresh := scene.instantiate()
	if key != "":
		fresh.set_meta(&"pool_key", key)
	return fresh

## Safe to call from physics callbacks: the tree detach is deferred. Callers
## must treat the node as gone the moment they release it.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var key: String = node.get_meta(&"pool_key", "")
	if not pool_enabled or key == "":
		node.queue_free()
		return
	_bank.call_deferred(node, key)

func _bank(node: Node, key: String) -> void:
	if not is_instance_valid(node):
		return
	if node.get_meta(&"pool_idle", false):
		return  # double release — already banked; re-appending would alias it
	var parent := node.get_parent()
	if parent:
		parent.remove_child(node)
	if node.has_method(&"pool_reset"):
		node.pool_reset()
	var bucket: Array = _pools.get(key, [])
	if bucket.size() >= pool_cap:
		node.queue_free()
		return
	node.set_meta(&"pool_idle", true)
	bucket.append(node)
	_pools[key] = bucket

func idle_count(scene: PackedScene) -> int:
	var bucket: Array = _pools.get(scene.resource_path, [])
	return bucket.size()

## Frees every idle node (banked nodes are parentless — nothing else owns
## them). Level teardown hygiene and test cleanup.
func clear() -> void:
	for key in _pools:
		for node in _pools[key]:
			if is_instance_valid(node):
				node.free()
	_pools.clear()

func _exit_tree() -> void:
	clear()
