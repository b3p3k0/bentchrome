class_name NetProtocol
extends RefCounted
## Wire-contract constants for LAN multiplayer. Pure data — no sockets, no
## tree. PROTOCOL_VERSION gates every handshake: bump it whenever the auth
## payload, the control RPC surface, or the snapshot format changes shape.

const PROTOCOL_VERSION := 8

# Peer budget: 4 drivers + 8 observers.
const MAX_PLAYERS := 4
const MAX_OBSERVERS := 8
const MAX_PEERS := MAX_PLAYERS + MAX_OBSERVERS

# ENet channels: control must never stall behind state spam.
const CH_CONTROL := 0  # reliable — auth, lobby, seats, match flow
const CH_STATE := 1    # unreliable — host->all snapshots
const CH_INPUT := 2    # unreliable — client->host intent frames

# Channel count baked into the ENet handshake (both ends must agree). Sized
# past CH_* + Godot's reserved channels so later cards never re-shake hands.
const ENET_CHANNELS := 8

# Defaults + live tunables (static var per house rules; const is frozen).
# The host-setup screen can override the game port per session.
static var default_game_port := 42998
static var discovery_port := 42999
static var snapshot_hz := 30.0      # host->client state rate
static var input_hz := 60.0         # client->host intent rate
static var interp_delay_ms := 50.0  # puppet render-behind buffer
