extends Area


func _ready() -> void:
	connect("body_entered", self, "on_body_entered")

func on_body_entered(body) -> void:
	if body is RigidBody:
		body.queue_free()
