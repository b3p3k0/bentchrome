extends RefCounted
## NetAuth: proof math, timing-safe compare, packet pack/unpack tolerance, and
## the full admit/reject truth table. Pure — no sockets, no tree.

const Auth := preload("res://game/net/net_auth.gd")
const Proto := preload("res://game/net/net_protocol.gd")

var t

func _init(runner) -> void:
	t = runner

func _ctx(overrides := {}) -> Dictionary:
	var ctx := {
		"nonce": Auth.make_nonce(),
		"password": "",
		"needs_password": false,
		"host_checksum": "abc123",
		"strict_mods": false,
		"peers": 0,
	}
	for k in overrides:
		ctx[k] = overrides[k]
	return ctx

func _resp(ctx: Dictionary, password := "", name := "Hotrod", checksum := "abc123") -> Dictionary:
	var chal: Dictionary = Auth.challenge(ctx.nonce, ctx.needs_password)
	return Auth.response(chal, password, name, checksum)

func test_proof_math() -> void:
	var nonce := Auth.make_nonce()
	t.check(nonce.size() == 16, "auth: nonce is 16 bytes")
	t.check(Auth.proof(nonce, "pw") == Auth.proof(nonce, "pw"),
		"auth: proof is deterministic")
	t.check(Auth.proof(nonce, "pw") != Auth.proof(nonce, "other"),
		"auth: proof binds the password")
	t.check(Auth.proof(nonce, "pw") != Auth.proof(Auth.make_nonce(), "pw"),
		"auth: proof binds the nonce (no replay)")

func test_constant_time_eq() -> void:
	var a := PackedByteArray([1, 2, 3])
	t.check(Auth.constant_time_eq(a, PackedByteArray([1, 2, 3])), "auth: eq matches equal")
	t.check(not Auth.constant_time_eq(a, PackedByteArray([1, 2, 4])), "auth: eq catches diff")
	t.check(not Auth.constant_time_eq(a, PackedByteArray([1, 2])), "auth: eq catches length")

func test_pack_unpack() -> void:
	var d := {"proto": 1, "name": "Mongoose"}
	var back: Dictionary = Auth.unpack(Auth.pack(d))
	t.check(int(back.get("proto", -1)) == 1 and String(back.get("name", "")) == "Mongoose",
		"auth: pack/unpack round-trips")
	t.check(Auth.unpack("{not json".to_utf8_buffer()).is_empty(),
		"auth: garbage bytes degrade to empty, silently")
	t.check(Auth.unpack("[1,2]".to_utf8_buffer()).is_empty(),
		"auth: non-dict JSON degrades to empty")

func test_decide_happy_path() -> void:
	var ctx := _ctx()
	var verdict: Dictionary = Auth.decide(_resp(ctx), ctx)
	t.check(verdict.admit and not verdict.modded, "auth: clean peer admitted")
	t.check(verdict.name == "Hotrod", "auth: name carried through")

func test_decide_rejections() -> void:
	var ctx := _ctx()
	var bad_proto := _resp(ctx)
	bad_proto["proto"] = Proto.PROTOCOL_VERSION + 1
	t.check(not Auth.decide(bad_proto, ctx).admit, "auth: proto mismatch rejected")
	t.check(Auth.decide(bad_proto, ctx).reason == "protocol mismatch",
		"auth: proto reject carries reason")
	t.check(not Auth.decide({}, ctx).admit, "auth: empty response rejected")
	var full := _ctx({"peers": Proto.MAX_PEERS})
	t.check(not Auth.decide(_resp(full), full).admit, "auth: 13th peer bounced")

func test_decide_password() -> void:
	var ctx := _ctx({"password": "vroom", "needs_password": true})
	t.check(Auth.decide(_resp(ctx, "vroom"), ctx).admit, "auth: right password admitted")
	t.check(not Auth.decide(_resp(ctx, "wrong"), ctx).admit, "auth: wrong password rejected")
	var no_proof := _resp(ctx, "vroom")
	no_proof.erase("proof")
	t.check(not Auth.decide(no_proof, ctx).admit, "auth: missing proof rejected")
	var open := _ctx()
	t.check(Auth.decide(_resp(open, "whatever"), open).admit,
		"auth: open server ignores proof entirely")

func test_decide_mod_checksum() -> void:
	var ctx := _ctx()
	var modded_verdict: Dictionary = Auth.decide(_resp(ctx, "", "Hotrod", "deadbeef"), ctx)
	t.check(modded_verdict.admit and modded_verdict.modded,
		"auth: checksum mismatch admits, flagged MODDED")
	var strict := _ctx({"strict_mods": true})
	var strict_verdict: Dictionary = Auth.decide(_resp(strict, "", "Hotrod", "deadbeef"), strict)
	t.check(not strict_verdict.admit and strict_verdict.reason == "modified build",
		"auth: strict mode rejects a modded build")
	t.check(Auth.decide(_resp(strict), strict).admit, "auth: strict mode admits a clean build")

func test_decide_name_hygiene() -> void:
	var ctx := _ctx()
	var long_name := _resp(ctx, "", "  The Duke Of New York, A-Number-One  ")
	var verdict: Dictionary = Auth.decide(long_name, ctx)
	t.check(verdict.name.length() <= Auth.NAME_MAX, "auth: names trimmed to cap")
	t.check(not verdict.name.begins_with(" "), "auth: names stripped of edge whitespace")
