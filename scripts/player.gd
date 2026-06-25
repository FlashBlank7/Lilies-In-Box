extends CharacterBody2D
class_name LiliesPlayer

signal interacted
signal reached_exit

@export var speed := 185.0
@export var acceleration := 1400.0
@export var friction := 1700.0
@export var jump_velocity := -365.0
@export var gravity := 980.0

var facing := Vector2.RIGHT
var can_finish := false
var movement_locked := false

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite") as AnimatedSprite2D

func _ready() -> void:
	name = "Lilith"

func _physics_process(delta: float) -> void:
	var direction := 0.0
	if not movement_locked:
		direction = Input.get_axis("move_left", "move_right")

	if direction != 0.0:
		facing = Vector2.RIGHT if direction > 0.0 else Vector2.LEFT
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if not is_on_floor():
		velocity.y += gravity * delta
	elif not movement_locked and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()
	_update_animation(direction)

func _unhandled_input(event: InputEvent) -> void:
	if movement_locked:
		return
	if event.is_action_pressed("interact"):
		interacted.emit()

func set_movement_locked(locked: bool) -> void:
	movement_locked = locked
	if locked:
		velocity = Vector2.ZERO

func _update_animation(direction: float) -> void:
	if sprite == null:
		return
	sprite.flip_h = facing.x < 0.0
	if not is_on_floor():
		_play_if_needed("jump")
	elif absf(direction) > 0.01:
		_play_if_needed("run")
	else:
		_play_if_needed("idle")

func _play_if_needed(animation_name: String) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(animation_name):
		return
	if sprite.animation != animation_name:
		sprite.play(animation_name)

func _on_exit_area_entered(area: Area2D) -> void:
	if can_finish and area.is_in_group("exit"):
		reached_exit.emit()
