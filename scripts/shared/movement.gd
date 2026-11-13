
extends RefCounted
class_name Movement

const SPEED: float = 200.0
const PLAYER_HALF_SIZE: float = 15.0


static func calculate_direction() -> Vector2:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0

	return direction.normalized()


static func simulate(
	current_position: Vector2,
	direction: Vector2,
	delta: float
) -> Vector2:
	return current_position + direction * SPEED * delta


static func simulate_with_collision(
	current_position: Vector2,
	direction: Vector2,
	delta: float,
	wall_x: float,
	door_open: bool = false
) -> Vector2:
	var new_position := simulate(
		current_position,
		direction,
		delta
	)

	if not door_open:
		new_position.x = min(
			new_position.x,
			wall_x - PLAYER_HALF_SIZE
		)

	return new_position
