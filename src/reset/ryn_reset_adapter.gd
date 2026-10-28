class_name RynResetAdapter
extends Node
## Makes Ryn a participant in the checkpoint snapshot without touching
## `src/player/ryn.gd`. Add it as a child of the Ryn node.
##
## Implements the resettable interface documented on `CheckpointManager`:
## `capture_state()` / `restore_state()`, joined through
## `CheckpointManager.RESETTABLE_GROUP`. Ryn gets no special treatment — the
## guard adapter and Story 005's objects use the identical contract.
##
## Deliberately NOT restored:
##  - `input_enabled` — owned by `DetectionReset`, which hands control back when
##    the fade finishes. Restoring it here would fight the sequence.
##  - crouch — derived state. Zeroing `intent` lets Ryn's own crouch rules stand
##    her up on the next physics tick, or keep her crouched under a low ceiling.
##
## Usage (in a scene):
##     [node name="ResetAdapter" type="Node" parent="Ryn"]
##     script = res://src/reset/ryn_reset_adapter.gd

## The player. Defaults to the parent node when left unset.
@export var ryn: Ryn


func _ready() -> void:
	if ryn == null:
		ryn = get_parent() as Ryn
	assert(ryn != null, "RynResetAdapter must be a child of a Ryn (or have `ryn` set)")
	add_to_group(CheckpointManager.RESETTABLE_GROUP)


## Snapshots Ryn's placement. See `CheckpointManager` for the interface.
##
## Usage: `var s: Dictionary = adapter.capture_state()`
func capture_state() -> Dictionary:
	return {
		&"position": ryn.global_position,
		&"velocity": ryn.velocity,
		&"facing": ryn.facing,
	}


## Puts Ryn back where the snapshot found her, standing still and not climbing.
##
## Usage: `adapter.restore_state(s)`
func restore_state(state: Dictionary) -> void:
	if ryn == null or not is_instance_valid(ryn):
		return
	ryn.global_position = state.get(&"position", ryn.global_position)
	ryn.velocity = state.get(&"velocity", Vector2.ZERO)
	ryn.facing = int(state.get(&"facing", ryn.facing))
	# Leave any ladder behind: CLIMBING turns gravity off, so a stale climb
	# would leave Ryn hanging in the air at the respawn point.
	ryn.state = Ryn.State.NORMAL
	# 也离开柜子/通风管:回到存档点的人不该还「躲」在原来那个柜子里
	ryn.hiding_spot = null
	ryn.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.LADDER_TOP
	# Fresh intent, or a key still held at the moment of the sighting would keep
	# driving Ryn through the whole fail sequence and the respawn.
	ryn.intent = RynIntent.new()
