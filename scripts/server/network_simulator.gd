
extends Node
class_name NetworkSimulator

@export var one_way_latency_ms: float = 100.0

var pending_messages: Array[Dictionary] = []


func send_message(callback: Callable, data: Dictionary) -> void:
	var delivery_time: int = (
		Time.get_ticks_msec() + int(one_way_latency_ms)
	)

	pending_messages.append({
		"delivery_time": delivery_time,
		"callback": callback,
		"data": data.duplicate(true)
	})


func _process(_delta: float) -> void:
	var current_time: int = Time.get_ticks_msec()
	var index: int = 0

	while index < pending_messages.size():
		var message: Dictionary = pending_messages[index]

		if current_time >= message["delivery_time"]:
			pending_messages.remove_at(index)
			message["callback"].call(message["data"])
		else:
			index += 1
