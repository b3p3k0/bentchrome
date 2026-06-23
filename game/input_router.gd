extends Node
## Central input action names + boot-time InputMap validation/repair (carries
## forward the old anti-regression safety). Bindings are created/verified in
## Phase 1; for now this just owns the canonical action-name constants.

const ACTION_MOVE_UP := &"move_up"
const ACTION_MOVE_DOWN := &"move_down"
const ACTION_MOVE_LEFT := &"move_left"
const ACTION_MOVE_RIGHT := &"move_right"
const ACTION_FIRE_MG := &"fire_mg"
const ACTION_FIRE_SPECIAL := &"fire_special"
