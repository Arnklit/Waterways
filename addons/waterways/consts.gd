const MATERIAL_CATEGORIES = {
	albedo_ = "Albedo",
	emission_ = "Emission",
	transparency_ = "Transparency",
	flow_ = "Flow",
	foam_ = "Foam",
	custom_ = "Custom",
}

const FILTER_RENDERER_PATH = "res://addons/waterways/filter_renderer.tscn"
const FLOW_OFFSET_NOISE_TEXTURE_PATH = "res://addons/waterways/textures/flow_offset_noise.png"
const FOAM_NOISE_PATH = "res://addons/waterways/textures/foam_noise.png"

enum SHADER_TYPES { WATER, LAVA, CUSTOM }

const BUILTIN_SHADERS = [
	{
		name = "Water",
		shader_path = "res://addons/waterways/shaders/river.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/water1_normal_bump.png",
			},
		],
	},
	{
		name = "Lava",
		shader_path = "res://addons/waterways/shaders/lava.gdshader",
		texture_paths = [
			{
				name = "normal_bump_texture",
				path = "res://addons/waterways/textures/lava_normal_bump.png",
			},
			{
				name = "emission_texture",
				path = "res://addons/waterways/textures/lava_emission.png",
			},
		],
	},
]

const DEBUG_SHADER = {
	name = "Debug",
	shader_path = "res://addons/waterways/shaders/river_debug.gdshader",
	texture_paths = [
		{
			name = "debug_pattern",
			path = "res://addons/waterways/textures/debug_pattern.png",
		},
		{
			name = "debug_arrow",
			path = "res://addons/waterways/textures/debug_arrow.svg",
		},
	],
}
