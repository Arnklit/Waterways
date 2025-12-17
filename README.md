# Waterways Add-on for Godot Engine

[![Waterways Add-on for Godot v0.1.0 Released - Feature Overview](https://raw.githubusercontent.com/Arnklit/media/main/WaterWaysAdd-on/screenshot01.jpg)](https://youtu.be/t54jUPFtRO8 "Waterways Add-on for Godot v0.1.0 Released - Feature Overview")

A tool to generate river meshes with flow and foam maps based on bezier curves. Try out the [demo project](https://github.com/Arnklit/WaterGenGodotDemo) for an example.

[Discord Server](https://discord.gg/mjGvWwQwv2)

[Patreon](https://www.patreon.com/arnklit)

Installation
-----------
Copy the folder addons/waterways into your project and activate the add-on from the Project -> Project Settings... -> Plugins menu.

Purpose
-------
I've been very impressed with examples of using flowmaps to imitate water simulations in games for a while, but most of the implementations I've seen were using either manually painted flowmaps, or flowmaps generated in an external program. I wanted to see if it was possible to have good flowmap results purely generated within Godot. Both the generation of the flowmaps and the generation of the mesh for the river was of interest to me and I've learned a lot implementing my solution.

Usage
-----
Once the addon is active, you can simply add a River node to the scene.
![ZlC0D3OKaq](https://user-images.githubusercontent.com/4955051/105901753-b60fca80-6015-11eb-8ee5-4ac10b815ca0.gif)

**Shaping**

You can then use the Path controls to shape the river to your liking. 
![FOa6ZrcTXA](https://user-images.githubusercontent.com/4955051/105954879-4af1e280-606d-11eb-9f53-bf60f701395e.gif)

The "Snap to Colliders" constraint can be used to easily place the path of the river along a terrain.
![Uo0Yts7nj6](https://user-images.githubusercontent.com/4955051/105904985-cd50b700-6019-11eb-9fa0-f0b08c1f5160.gif)

The Axis and Plane constraints can be used for better control in moving and adding points. The implementation is similar to Blender's. You can also use the shortcuts X, Y and Z to lock movement to a given axis and shortcuts Shift + X, Y and Z to lock to planes YZ, XZ and XY. The Local mode option, switches the axis to be local to the point rather than the world and can be toggled with shortcut T.
![qK2oHGFXFO](https://user-images.githubusercontent.com/4955051/105904382-fa509a00-6018-11eb-8cab-417d0a364ff5.gif)

**Texture Baking**

Once you are happy with the shape of your river, you can use the *River -> Generate Flow & Foam Map* option to bake out the textures that activate flow map and foam. The settings for the baking are located in the river's inspector, see section below.
![GU7fDHXmmJ](https://user-images.githubusercontent.com/4955051/102623078-de182e00-4139-11eb-8e65-d95bad4ed310.gif)

**Generating a Mesh Copy**

In case you want to access the river mesh directly to use it for other purposes such as generating a collision shape. You can use the *River -> Generate MeshInstance Sibling* option.
![b5qdG0oYbV](https://user-images.githubusercontent.com/4955051/102623733-e1f88000-413a-11eb-8c79-99a1977fbca9.gif)

**Using a WaterSystem Node**

To generate a global height and flowmap of a river. You can add a *WaterSystem* node and generate a texture based on any *River* child nodes with the *WaterSystem -> Generate System Maps* option.
![bnhOeLjP8H](https://user-images.githubusercontent.com/4955051/104091192-c6812080-5273-11eb-87a9-0684b306033e.gif)

**Using a Buoyant Node**

Adding a *Buoyant* node as a child to a *RigidBody* will allow the object to float on the river if a *WaterSystem* with valid maps is available.
![image](https://user-images.githubusercontent.com/4955051/104091388-085e9680-5275-11eb-8564-84d196140da6.png)

**Using flow and height maps in shaders**

You can automatically assign the global textures from the *WaterSystem* node to *MeshInstances* to use them in shaders. See the *WaterSystem* parameters for details. Once the textures and coordinates are assigned you can use them in a shader like this:

```glsl
shader_type spatial;

uniform sampler2D water_systemmap;
uniform mat4 water_systemmap_coords;
varying vec3 world_vertex;

float water_altitude(vec3 pos) {
	vec3 pos_in_aabb = pos - water_systemmap_coords[0].xyz;
	vec2 pos_2d = vec2(pos_in_aabb.x, pos_in_aabb.z);
	float longest_side = water_systemmap_coords[1].x > water_systemmap_coords[1].z ? water_systemmap_coords[1].x : water_systemmap_coords[1].z;
	pos_2d = pos_2d / longest_side;
	float value = texture(water_systemmap, pos_2d).b;
	float height = value * water_systemmap_coords[1].y + water_systemmap_coords[0].y;
	return pos.y - height;
}

void vertex() {
	world_vertex = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float altitude = clamp(water_altitude(world_vertex), 0.0, 1.0);
	ALBEDO = vec3(altitude);
}
```

For effects such as this:

![UtzIm3ohmc](https://user-images.githubusercontent.com/4955051/104092678-75762a00-527d-11eb-9eff-18851b84a429.gif)


River Parameters
----------------
The river's parameters are split into 4 sections.

**Shape**

- *Step Length Divs* - How many subdivision the river will have per step along its length.
- *Step Width Divs* - How many subdivision the river will have along its width.
- *Smoothing* - How much the shape of the river is relaxed to even out corners.

**Material**

*The Material section has two hardcoded parameters*

- *Shader Type* - This option allows you to select between the two built-in shaders *Water* and *Lava*.
- *Custom Shader* - This option allows you to easily make a copy of the selected shader and edit it.

*The remaining parameters in the Material section are parsed from the currect shader*

*Parameters shared by Water and Lava shader*

- *Normal Scale* - The strength of the normal mapping.
- *Normal Bump Texture* - The pattern used for the water. RG channels hold the normal map and B holds a bump or height map used for the foam.
- *UV Scale* - The UV scaling used for textures on the river.
- *Roughness* - The roughness of the river surface, also affects the blurring that occurs in the refractions.
- *Edge Fade* - The distance the river fades out when it intesects other objects to give the shore line a softer look.
- *Flow* - Subcategory for flow options.
    - *Speed* - How fast the river flows.
    - *Base Strength* - Base multiplier of the flow vectors.
    - *Steepness Strength* - Flow vectors multiplied by the steepness of the river.
    - *Distance Strength* - Flow vectors multiplied by the distance field for faster flows further away from shore.
    - *Pressure Strength* - Flow vectors multiplied by a pressure map, to imitate the flow increasing when there is less available space in the river.
    - *Max Strength* - Clamps the maximum multiplier of the flow vectors.

*Parameters specific to Water shader*

- *Albedo* - Subcategory for the albedo parameters.
    - *Color* - The two colours of the water mixed based on the depth set in *Depth*.
    - *Depth* - The water depth at which the far colour of the gradient is returned.
    - *Depth Curve* - The interpolation curve used for the depth gradient.

- *Transparency* - Subcategory for the transparency parameters.
    - *Clarity* - How far light can travel in the water before only returning the albedo colour.
    - *Depth Curve* - The interpolation curve used for the clarity depth.
    - *Refraction* - How much the background gets bent by the water shape.
    
- *Foam* - Subcategory for the foam options.
    - *Color* - The colour of the foam.
    - *Ammount* - Controls the foam cutoff in the shader, you may have to use the foam baking setting to change the amount of foam further. See below.
    - *Steepness* - Gives the option to add in foam where the river is steep.
    - *Smoothness* - Controls how the foam layers are combined to give a sharper or softer look.

*Parameters specific to the Lava shader*

- *Emission* - Subcategory for the emission options.
    - *Color* - The two colours multiplied by the emission texture of the lava mixed based on the depth set in *Depth*.
    - *Depth* - The lava depth at which the far colour of the gradient is returned.
    - *Depth Curve* - The interpolation curve used for the depth gradient.
    - *Texture* - The emission texture.

**Lod**

- *Lod0 Distance* - Controls the cutoff point for whether the shader samples textures twice to create an FBM effect for the waves and foam.

**Baking**

- *Resolution* - Controls the resolution of the baked flow and foam map. This texture does not need to be very large to look decent, so only increse it if needed as the baking time can increase a lot.
- *Raycast Distance* - The collision map is calculated using raycasts from the river surface to detect colliders, adjust the length as needed.
- *Raycast Layers* - The physics layers to use for the raycast.
- *Dilate* - The amount of dilation happening to convert the collision map to an Distance Field. This value should generally not be adjusted.
- *Flowmap Blur* - How much the flowmap is blurred to clear up seams or artifacts.
- *Foam Cutoff* - How much of the Distance Field is cut off to generate the foam mask. Increasing this calue will make the foam mask tighter around the collisions.
- *Foam Offset* - How far the foam strethes along the flow direction.
- *Foam Blur* - How much the foam mask is blurred.

Writing Custom Shaders
----------------------
When writing custom shaders for the tool there are a few things to keep in mind.

The tool uses certain uniforms that should not be customized as that will break the tool. These uniforms are prefixed with "i_" and are:

|Uniform name        |Description                                                  |
|:-------------------|:------------------------------------------------------------|
|i_lod0_distance     |used by the LOD system                                       |
|i_texture_foam_noise|a noise texture used to display foam on steep angles         |
|i_flowmap           |the generated flowmap(RG) and foam map(B)                    |
|i_distmap           |the generated distance field(R) and pressure map(B)          |
|i_valid_flowmap     |a bool that is set if the generated maps are valid           |
|i_uv2_sides         |an int value that tells the shader how to read the UV2 layout|

Uniforms that do not start with "i_" will be parsed by the river's material inspector so they can easily be used in the tool. If the uniforms start with any of the below prefixes they will automatically be sorted into subcategories in the material section.

|Prefix name  |Subcatergory name|
|:------------|:----------------|
|albedo_      |Albedo           |
|emission_    |Emission         |
|transparency_|Transparency     |
|flow_        |Flow             |
|foam_        |Foam             |
|custom_      |Custom           |

Additionally the river inspector will handle these uniform types specially:

float uniforms containing "curve" in their name will be displayed as an easing curve in the inspector.

```uniform float albedo_depth_curve = 0.25;```

![image](https://user-images.githubusercontent.com/4955051/105959013-43353c80-6073-11eb-9f1c-b93d66c06ef6.png)

mat4 uniforms containing "color" in their name will be displayed as a gradient field with two colour selectors. Here is the code setting up the water shader's albedo gradient with the two colors (0.0, 0.8, 1.0) and (0.15, 0.2, 0.5).

```uniform mat4 albedo_color = mat4(vec4(0.0, 0.15, 0.0, 0.0), vec4(0.8, 0.2, 0.0, 0.0), vec4(1.0, 0.5, 0.0, 0.0), vec4(0.0));```

![image](https://user-images.githubusercontent.com/4955051/105959179-7d9ed980-6073-11eb-94af-64af97e195bf.png)

WaterSystem Parameters
----------------------
- *System Map* - The baked system maps texture
- *System Bake Resolution* - The resolution of the system maps
- *System Group Name* - This group name is assigned at runtime, it is used by the *Buoyant* node to find the WaterSystem. If you only have one *WaterSystem*, you can just leave this be.
- *Minimum Water Level* - This is the value returned when an object queries the Water System heightmap, but hits outside the baked height data.
- *Auto Assign Texture & Coordinates On Generate* - Subcategory for auto assign setting, used to send the system map and coordinates to materials to be used in shaders
    - *Wet Group Name* - This name will be used to find any *MeshInstances* that should have the maps assigned
    - *Surface Index* - The surface index the material you want to send the maps to is set on the *MeshInstance*, -1 means disabled.
    - *Material Override* - If the material is instead set as a Material Override, check this box for the maps to be assigned there.

Buoyant Parameters
------------------
- *Water System Group Name* - This is used to find the *WaterSystem* to get height and flow data from, this should match the value in your *WaterSystem*.
- *Buoyancy Force* - The amount of upwards force applied to the *RigidBody* when the *Buoyant* is under the water level.
- *Up Correcting Force* - The amount of torque force being added to the *RigidBody* to try and keep the object upright in the water.
- *Flow Force* The amount the flow vectors from the *WaterSystem* get's applied to the *RigidBody*.
- *Water Resistance* This sets the *RigidBody's* damping parameter when under the water level.

Current Limitations
-------------------
* There is only a river node so far, so no solution for lakes or oceans.
* There are no real time reflections on the water. Since godot does not allow Screen Space Reflections with transparent objects, the built-in SSR effect cannot be used. I will probably implement my own eventually.
* There is no mesh displacement. Since Godot does not have tesselation, mesh displacement is not feasible.
* Rivers do not interact with each other. At the moment there is no way to elegantly merge multiple rivers into one or splitting one into multiple. I plan to implement a solution for this eventually.

Acknowledgements
---------------
* Thanks to my patrons *Marcus Richter, Dmitriy Keane, spacechace0, Johannes Wuesnch, Winston and Little Mouse Games* for all their support.

Several people in the Godot community have helped me out with this.
* *Winston* has contributed code to the project with the great axis constraint system.
* *Zylann* has been really helpful, both with any issues I've had working on terrains, but also in that whenever I don't know how to do something in a plugin I generally find the answer somewhere in his code.
* *HungryProton* has given me a ton of help setting up the Gizmo's to make custom editing tools for the river.
* *Rodzilla* helped me figure out how to generate the various textures for the flow and foam and a lot of the code for rendering the maps are directly inspired by his incredible [Material Maker](https://rodzilla.itch.io/material-maker) tool.

Beyond the Godot community, I should also mention these resources.
* The flowmap shader implementation was heavily inspired by CatLikeCoding's excellent article on the subject. https://catlikecoding.com/unity/tutorials/flow/texture-distortion/

Contributing
------------
If you want to contribute to the project or just work on your own version, clone the repository and add [Zylann's terrain addon](https://github.com/Zylann/godot_heightmap_plugin) into the project as I don't include it in this repository, but use it in the test scene.
