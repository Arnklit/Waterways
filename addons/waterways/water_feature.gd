@tool
extends Node3D

const WaterHelperMethods = preload("./water_helper_methods.gd")
const Constants = preload("./consts.gd")

# Bake Properties
var baking_resolution: int = 2
var baking_raycast_distance: float = 10.0
var baking_raycast_layers: int = 1
var baking_dilate: float = 0.6
var baking_flowmap_blur: float = 0.04
var baking_foam_cutoff: float = 0.9
var baking_foam_offset: float = 0.1
var baking_foam_blur: float = 0.02

# Flowmap state
var valid_flowmap := false
var flow_foam_noise: Texture2D
var dist_pressure: Texture2D

# Internal
var _material: ShaderMaterial
var _debug_material: ShaderMaterial
var _filter_renderer: PackedScene
var _steps := 2
var _first_enter_tree := true
var _uv2_sides: int

signal feature_changed
signal progress_notified
