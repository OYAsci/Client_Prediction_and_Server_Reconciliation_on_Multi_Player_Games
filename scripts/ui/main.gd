
extends Node2D

const SMALL_ERROR: float = 2.0
const SNAP_THRESHOLD: float = 50.0
const SMOOTH_SPEED: float = 12.0

@onready var left_area: Control = $ComparisonUI/HBoxContainer/WithoutPrediction/VBoxContainer/GameArea
@onready var right_area: Control = $ComparisonUI/HBoxContainer/WithPrediction/VBoxContainer/GameArea

@onready var left_player: Node2D = $ComparisonUI/HBoxContainer/WithoutPrediction/VBoxContainer/GameArea/PlayerA
@onready var right_player: Node2D = $ComparisonUI/HBoxContainer/WithPrediction/VBoxContainer/GameArea/PlayerB
@onready var right_sprite: Polygon2D = $ComparisonUI/HBoxContainer/WithPrediction/VBoxContainer/GameArea/PlayerB/PlayerSprite

@onready var network: NetworkSimulator = $NetworkSimulator
@onready var server: GameServer = $GameServer

var initialized: bool = false
var input_sequence: int = 0
var pending_inputs: Array[Dictionary] = []

var last_ack_a: int = 0
var last_ack_b: int = 0

var client_a_door_open: bool = false
var client_b_door_open: bool = false

var client_a_door_version: int = 0
var client_b_door_version: int = 0

var door_a: ColorRect
var door_b: ColorRect
var server_marker: ColorRect

var debug_label_a: Label
var debug_label_b: Label
var server_status: Label

var last_server_position: Vector2 = Vector2.ZERO
var last_correction: float = 0.0
var maximum_correction: float = 0.0
var reconciliation_count: int = 0
var debug_timer: float = 0.0

var visual_offset: Vector2 = Vector2.ZERO
var correction_mode: String = "NONE"


func _ready() -> void:
	create_debug_dashboard()
	create_server_status()

	await get_tree().process_frame

	left_player.position = left_area.size / 2.0
	right_player.position = right_area.size / 2.0

	server.initialize_players(
		left_player.position,
		right_player.position
	)

	client_a_door_open = server.door_open
	client_b_door_open = server.door_open

	client_a_door_version = server.door_version
	client_b_door_version = server.door_version

	create_server_walls()

	last_server_position = right_player.position

	update_server_marker()
	update_door_visuals()

	initialized = true
	update_debug_dashboard()


func _physics_process(delta: float) -> void:
	if not initialized:
		return

	var direction: Vector2 = Movement.calculate_direction()
	input_sequence += 1

	network.send_message(
		receive_server_input,
		{
			"player_id": "A",
			"sequence": input_sequence,
			"direction": direction,
			"delta": delta
		}
	)

	var input_data: Dictionary = {
		"player_id": "B",
		"sequence": input_sequence,
		"direction": direction,
		"delta": delta,
		"door_open": client_b_door_open,
		"door_version": client_b_door_version
	}

	pending_inputs.append(input_data.duplicate(true))

	right_player.position = Movement.simulate_with_collision(
		right_player.position,
		direction,
		delta,
		server.wall_b_x,
		client_b_door_open
	)

	network.send_message(receive_server_input, input_data)

	debug_timer += delta

	if debug_timer >= 0.1:
		debug_timer = 0.0
		update_debug_dashboard()


func _process(delta: float) -> void:
	if not initialized:
		return

	if visual_offset.length() > 0.1:
		var alpha: float = 1.0 - exp(-SMOOTH_SPEED * delta)
		visual_offset = visual_offset.lerp(Vector2.ZERO, alpha)
	else:
		visual_offset = Vector2.ZERO

	right_sprite.position = visual_offset


func receive_server_input(data: Dictionary) -> void:
	var response: Dictionary = server.process_input(data)
	network.send_message(receive_server_response, response)


func receive_server_response(data: Dictionary) -> void:
	var player_id: String = data["player_id"]
	var position: Vector2 = data["position"]
	var sequence: int = data["last_processed_sequence"]

	if player_id == "A":
		if sequence <= last_ack_a:
			return

		last_ack_a = sequence
		left_player.position = position

	elif player_id == "B":
		if sequence <= last_ack_b:
			return

		last_ack_b = sequence
		last_server_position = position

		reconcile_player_b(position, sequence)
		update_server_marker()


func reconcile_player_b(
	authoritative_position: Vector2,
	acknowledged_sequence: int
) -> void:
	var old_position: Vector2 = right_player.position

	while not pending_inputs.is_empty():
		if pending_inputs[0]["sequence"] > acknowledged_sequence:
			break

		pending_inputs.remove_at(0)

	right_player.position = authoritative_position

	for input_data in pending_inputs:
		right_player.position = Movement.simulate_with_collision(
			right_player.position,
			input_data["direction"],
			input_data["delta"],
			server.wall_b_x,
			input_data["door_open"]
		)

	var correction_vector: Vector2 = (
		old_position - right_player.position
	)

	last_correction = correction_vector.length()
	maximum_correction = max(maximum_correction, last_correction)
	reconciliation_count += 1

	apply_visual_correction(correction_vector)


func apply_visual_correction(correction_vector: Vector2) -> void:
	var error: float = correction_vector.length()

	if error <= SMALL_ERROR:
		correction_mode = "NONE"

	elif error <= SNAP_THRESHOLD:
		visual_offset += correction_vector
		correction_mode = "SMOOTH"

	else:
		visual_offset = Vector2.ZERO
		right_sprite.position = Vector2.ZERO
		correction_mode = "SNAP"

	if error > SMALL_ERROR:
		print(
			"Correction: %.2f px | Mode: %s" %
			[error, correction_mode]
		)


func _unhandled_key_input(event: InputEvent) -> void:
	if not initialized:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_SPACE:
				toggle_server_door()


func toggle_server_door() -> void:
	server.set_door_open(not server.door_open)

	var snapshot: Dictionary = server.get_door_snapshot()

	network.send_message(
		receive_client_a_door_update,
		snapshot
	)

	network.send_message(
		receive_client_b_door_update,
		snapshot
	)

	update_door_visuals()
	update_debug_dashboard()


func receive_client_a_door_update(data: Dictionary) -> void:
	var version: int = data["door_version"]

	if version <= client_a_door_version:
		return

	client_a_door_version = version
	client_a_door_open = data["door_open"]

	update_door_visuals()
	update_debug_dashboard()


func receive_client_b_door_update(data: Dictionary) -> void:
	var version: int = data["door_version"]

	if version <= client_b_door_version:
		return

	client_b_door_version = version
	client_b_door_open = data["door_open"]

	update_door_visuals()
	update_debug_dashboard()


func create_wall(area: Control, wall_x: float) -> ColorRect:
	var wall: ColorRect = ColorRect.new()

	wall.position = Vector2(wall_x, 0.0)
	wall.size = Vector2(6.0, area.size.y)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE

	area.add_child(wall)

	return wall


func create_server_walls() -> void:
	door_a = create_wall(left_area, server.wall_a_x)
	door_b = create_wall(right_area, server.wall_b_x)


func update_door_visuals() -> void:
	if client_a_door_open:
		door_a.color = Color(0.2, 0.8, 0.3, 0.3)
	else:
		door_a.color = Color.RED

	if client_b_door_open:
		door_b.color = Color(0.2, 0.8, 0.3, 0.3)
	else:
		door_b.color = Color.RED


func create_debug_dashboard() -> void:
	var left_container: VBoxContainer = $ComparisonUI/HBoxContainer/WithoutPrediction/VBoxContainer
	var right_container: VBoxContainer = $ComparisonUI/HBoxContainer/WithPrediction/VBoxContainer

	debug_label_a = Label.new()
	debug_label_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_container.add_child(debug_label_a)

	debug_label_b = Label.new()
	debug_label_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_container.add_child(debug_label_b)

	server_marker = ColorRect.new()
	server_marker.color = Color(1.0, 0.55, 0.0, 0.5)
	server_marker.size = Vector2(36, 36)
	server_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE

	right_area.add_child(server_marker)
	server_marker.z_index = -1


func create_server_status() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ServerStatusLayer"
	layer.layer = 10
	add_child(layer)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ServerStatusPanel"

	layer.add_child(panel)

	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -245.0
	panel.offset_top = 10.0
	panel.offset_right = -10.0
	panel.offset_bottom = 105.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	server_status = Label.new()
	server_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	server_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	panel.add_child(server_status)


func update_server_marker() -> void:
	server_marker.position = (
		last_server_position - server_marker.size / 2.0
	)


func update_debug_dashboard() -> void:
	if not initialized:
		return

	var rtt: float = network.one_way_latency_ms * 2.0

	var server_door: String = "CLOSED"
	var door_a_state: String = "CLOSED"
	var door_b_state: String = "CLOSED"

	if server.door_open:
		server_door = "OPEN"

	if client_a_door_open:
		door_a_state = "OPEN"

	if client_b_door_open:
		door_b_state = "OPEN"

	server_status.text = (
        "AUTHORITATIVE SERVER\n"
		+ "Door: %s\n" % server_door
		+ "Version: %d" % server.door_version
	)

	debug_label_a.text = (
		"RTT: %.0f ms\n" % rtt
		+ "Client door: %s\n" % door_a_state
		+ "Door version: %d\n" % client_a_door_version
		+ "ACK: %d\n" % last_ack_a
		+ "Position: (%.1f, %.1f)" % [
			left_player.position.x,
			left_player.position.y
		]
	)

	debug_label_b.text = (
		"Client door: %s\n" % door_b_state
		+ "Door version: %d\n" % client_b_door_version
		+ "ACK: %d\n" % last_ack_b
		+ "Pending: %d\n" % pending_inputs.size()
		+ "Predicted: (%.1f, %.1f)\n" % [
			right_player.position.x,
			right_player.position.y
		]
		+ "Server ACK: (%.1f, %.1f)\n" % [
			last_server_position.x,
			last_server_position.y
		]
		+ "Correction: %.3f px\n" % last_correction
		+ "Max correction: %.3f px\n" % maximum_correction
		+ "Mode: %s\n" % correction_mode
		+ "Visual offset: %.2f px" % visual_offset.length()
	)
