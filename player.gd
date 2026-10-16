extends CharacterBody2D

const SPEED := 260.0
const JUMP_VELOCITY := -430.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var spaw_position := Vector2.ZERO

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	spaw_position = global_position
	modulate = Color("ff7f50") if get_multiplayer_authority() == 1 else Color("00bfff")

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if position.y > 700:
		position.y = 40

	move_and_slide()
	update_animation(direction)

func update_animation(direction: float) -> void:
	if not is_on_floor():
		sprite.play("jump")
	elif direction:
		sprite.play("run")
	else:
		sprite.play("idle")
