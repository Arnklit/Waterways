@tool
extends Resource

@export var width: float = 3.0:
	set(value): 
		width = value
		emit_changed()
		print("width set in resource, right after emit changed is called")
@export var step_length_divs: int = 1:
	set(value):
		step_length_divs = value
		emit_changed()
@export var step_width_divs: int = 1:
	set(value):
		step_width_divs = value
		emit_changed()

#signal width_changed
#signal step_length_divs_changed
#signal step_width_divs_changed

func _init(p_width: float = 3.0, p_step_length_divs: int = 1, p_step_width_divs: int = 1) -> void:
	# TODO - These don't seem to be filled in as expected?!? I had to fill the default values above instead
	width = p_width
	step_length_divs = p_step_length_divs
	step_width_divs = p_step_width_divs
