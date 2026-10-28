class_name FollowCameraConfig
extends Resource
## Tuning values for FollowCamera. Saved as a `.tres` under `assets/data/`.
##
## Smoothing values are exponential rates (1/s): higher is snappier.
##
## Usage:
##     camera.config = load("res://assets/data/follow_camera.tres")

## How far ahead of Ryn the camera leans in the facing direction, px.
@export var look_ahead_distance: float = 28.0
## Rate at which the look-ahead lean eases in and out, 1/s.
@export var look_ahead_smoothing: float = 5.0
## Horizontal follow rate, 1/s.
@export var follow_smoothing_x: float = 9.0
## Vertical follow rate, 1/s. Slower than horizontal so jumps do not bounce the view.
@export var follow_smoothing_y: float = 4.0
## Added to Ryn's feet position to find the view centre (negative = above the feet), px.
@export var vertical_offset: float = -24.0

@export_group("Dynamics")
## 下落时镜头额外下移的最大量,px。给出落点,别让玩家盲跳。
@export var fall_look_down: float = 30.0
## 达到最大下移所需的下落速度,px/s。
@export var fall_look_speed: float = 320.0
## 下移的跟随速率。进要快(马上看见下面),出要慢(落地不要猛弹回)。
@export var fall_look_in_rate: float = 6.0
@export var fall_look_out_rate: float = 2.6
## 全速奔跑时额外增加的前瞻,px。慢走时不加 —— 潜行时视野不该乱晃。
@export var speed_look_ahead: float = 16.0
## 达到最大额外前瞻所需的水平速度,px/s。
@export var speed_look_full: float = 100.0
