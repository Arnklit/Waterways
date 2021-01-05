extends Spatial


export(String, FILE) var spawn_object_path

var _spawn_object

func _ready() -> void:
	_spawn_object = load(spawn_object_path)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_select"):
		print("spawn object")
		var obj = _spawn_object.instance() as RigidBody
		owner.add_child(obj)
		obj.translation = global_transform.origin
		obj.apply_central_impulse(global_transform.basis.z * -10.0)
