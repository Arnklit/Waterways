tool
extends Spatial


export var check_alt = false setget set_check_alt

func set_check_alt(value : bool) -> void:
	var water_sys = get_parent().get_node("WaterSystem")
	var alt = water_sys.get_water_altitude(translation)
	var flow = water_sys.get_water_flow(translation)
	print("alt is: ", alt)
	print("flow is: ", flow)
