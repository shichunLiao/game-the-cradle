class_name PhysicsLayers
extends RefCounted
## 2D physics layer bit values shared by gameplay scripts and scenes.
##
## These are bit VALUES (layer N = 2^(N-1)), as used by `collision_layer` /
## `collision_mask`. Scenes set the same numbers in the inspector.
##
## Usage:
##     body.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.LADDER_TOP

## Layer 1: solid level geometry.
const WORLD: int = 1
## Layer 2: one-way platform capping a ladder, so Ryn can stand on its top.
const LADDER_TOP: int = 2
## Layer 3: ladder climb zones (Area2D, detected by Ryn's sensor only).
const LADDER: int = 4
## Layer 4: the player body.
const PLAYER: int = 8
## Layer 5: guard vision cones (Area2D broad phase; detects PLAYER only).
const GUARD_VISION: int = 16
## Layer 6: authored darkness regions (Area2D, inert — see ShadowZone).
const SHADOW: int = 32

## Layer 7: dismantlable panels (Area2D reach sensor; detects PLAYER only).
const DISMANTLABLE: int = 64
