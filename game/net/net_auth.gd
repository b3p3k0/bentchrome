class_name NetAuth
extends RefCounted
## The pre-admit handshake math: nonce challenges, salted password proofs, and
## the pure admit/reject verdict. No sockets — NetSession feeds it packets,
## tests feed it dictionaries. The password never crosses the wire: the client
## sends SHA256(nonce + SHA256(SALT + password)), so a captured proof is dead
## outside its single-use nonce.
##
## Sibling net modules are preloaded by path (not global class_name) so this
## compiles under bare headless -s runs with a stale class cache.

const Proto := preload("res://game/net/net_protocol.gd")

const SALT := "bentchrome-v1"  # namespaces proofs; not a secret
const NAME_MAX := 24

static func make_nonce() -> PackedByteArray:
	return Crypto.new().generate_random_bytes(16)

## One deterministic stretch of the shared secret; proof() binds it to a nonce.
static func password_key(password: String) -> PackedByteArray:
	return _sha256((SALT + password).to_utf8_buffer())

static func proof(nonce: PackedByteArray, password: String) -> PackedByteArray:
	var joined := PackedByteArray(nonce)
	joined.append_array(password_key(password))
	return _sha256(joined)

## Timing-safe compare — a proof check must not leak how much of it matched.
static func constant_time_eq(a: PackedByteArray, b: PackedByteArray) -> bool:
	if a.size() != b.size():
		return false
	var diff := 0
	for i in a.size():
		diff |= a[i] ^ b[i]
	return diff == 0

## Server -> connecting peer, before admission.
static func challenge(nonce: PackedByteArray, needs_password: bool) -> Dictionary:
	return {
		"proto": Proto.PROTOCOL_VERSION,
		"nonce": Marshalls.raw_to_base64(nonce),
		"needs_password": needs_password,
	}

## Connecting peer -> server. checksum comes from NetManifest.cached().
static func response(chal: Dictionary, password: String, name: String, checksum: String) -> Dictionary:
	var nonce := Marshalls.base64_to_raw(String(chal.get("nonce", "")))
	return {
		"proto": Proto.PROTOCOL_VERSION,
		"name": name,
		"proof": Marshalls.raw_to_base64(proof(nonce, password)),
		"checksum": checksum,
	}

## The server-side verdict — a pure truth table. ctx carries the server's own
## state: {nonce: PackedByteArray, password: String, needs_password: bool,
## host_checksum: String, strict_mods: bool, peers: int}.
## Returns {admit, modded, reason, name}; the server never trusts a client
## field it can recompute.
static func decide(resp: Dictionary, ctx: Dictionary) -> Dictionary:
	if int(resp.get("proto", -1)) != Proto.PROTOCOL_VERSION:
		return _reject("protocol mismatch")
	# Effective cap: MAX_PEERS normally, MAX_PLAYERS when the host runs a
	# no-observers session (the ctx decides — never the client).
	if int(ctx.get("peers", 0)) >= int(ctx.get("max_peers", Proto.MAX_PEERS)):
		return _reject("server full")
	if bool(ctx.get("needs_password", false)):
		var got := Marshalls.base64_to_raw(String(resp.get("proof", "")))
		var nonce: PackedByteArray = ctx.get("nonce", PackedByteArray())
		var want := proof(nonce, String(ctx.get("password", "")))
		if not constant_time_eq(got, want):
			return _reject("bad password")
	var modded := String(resp.get("checksum", "")) != String(ctx.get("host_checksum", ""))
	if modded and bool(ctx.get("strict_mods", false)):
		return _reject("modified build")
	var name := String(resp.get("name", "")).strip_edges().left(NAME_MAX)
	return {"admit": true, "modded": modded, "reason": "", "name": name}

## Auth packets ride SceneMultiplayer's auth channel as UTF-8 JSON — two
## packets per join, so debuggability beats byte-shaving here.
static func pack(d: Dictionary) -> PackedByteArray:
	return JSON.stringify(d).to_utf8_buffer()

## Instance parse: garbage from a fuzzing peer degrades to {} silently instead
## of printing an engine ERROR (which would also trip the test gates).
static func unpack(bytes: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var data: Variant = json.data
	return data if typeof(data) == TYPE_DICTIONARY else {}

static func _reject(reason: String) -> Dictionary:
	return {"admit": false, "modded": false, "reason": reason, "name": ""}

static func _sha256(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()
