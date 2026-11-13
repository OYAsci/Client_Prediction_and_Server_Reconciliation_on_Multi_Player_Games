
extends Node
class_name GameServer

const WALL_DISTANCE: float = 120.0
const PLAYER_HALF_SIZE: float = 15.0

var player_a_position: Vector2 = Vector2.ZERO
var player_b_position: Vector2 = Vector2.ZERO

var last_sequence_a: int = 0
var last_sequence_b: int = 0

var wall_a_x: float = 0.0
var wall_b_x: float = 0.0

var door_open: bool = false
var door_version: int = 0


func initialize_players(position_a: Vector2, position_b: Vector2) -> void:
	player_a_position = position_a
	player_b_position = position_b

	last_sequence_a = 0
	last_sequence_b = 0

	wall_a_x = position_a.x + WALL_DISTANCE
	wall_b_x = position_b.x + WALL_DISTANCE

	door_open = false
	door_version = 0


func set_door_open(is_open: bool) -> void:
	if door_open == is_open:
		return

	door_open = is_open
	door_version += 1


func apply_server_collision(position: Vector2, wall_x: float) -> Vector2:
	if door_open:
		return position

	var result: Vector2 = position
	result.x = min(result.x, wall_x - PLAYER_HALF_SIZE)

	return result


func process_input(data: Dictionary) -> Dictionary:
	var player_id: String = data["player_id"]
	var direction: Vector2 = data["direction"]
	var delta: float = data["delta"]
	var sequence: int = data["sequence"]

	var position: Vector2 = Vector2.ZERO
	var last_sequence: int = 0

	if player_id == "A":
		if sequence > last_sequence_a:
			player_a_position = apply_server_collision(
				Movement.simulate(player_a_position, direction, delta),
				wall_a_x
			)
			last_sequence_a = sequence

		position = player_a_position
		last_sequence = last_sequence_a

	elif player_id == "B":
		if sequence > last_sequence_b:
			player_b_position = apply_server_collision(
				Movement.simulate(player_b_position, direction, delta),
				wall_b_x
			)
			last_sequence_b = sequence

		position = player_b_position
		last_sequence = last_sequence_b

	return {
		"player_id": player_id,
		"position": position,
		"last_processed_sequence": last_sequence,
		"door_open": door_open,
		"door_version": door_version
	}


func get_door_snapshot() -> Dictionary:
	return {
		"door_open": door_open,
		"door_version": door_version
	}
