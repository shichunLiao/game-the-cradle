extends Node2D
## Gray-box scene for feeling out Ryn's movement. Not a tower level.
## Sets the background to the palette's ink-deep so flat blocks read clearly.

const INK_DEEP: Color = Color("0B1220")


func _ready() -> void:
	RenderingServer.set_default_clear_color(INK_DEEP)
