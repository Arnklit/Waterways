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
![2kXOoGLFRm](https://user-images.githubusercontent.com/4955051/102621243-3437a200-4137-11eb-9912-c91cadc0dd1e.gif)

**Shaping**

You can then use the Path controls to shape the river to your liking. 
![fGj5m244JK](https://user-images.githubusercontent.com/4955051/102622232-a1980280-4138-11eb-9a82-4d168055d10b.gif)

The "Snap to colliders" option can be used to easily place the path of the river along a terrain.
![lrQNRdVzCU](https://user-images.githubusercontent.com/4955051/102622600-271bb280-4139-11eb-9b4a-c53ea4a4d004.gif)

**Texture Baking**

Once you are happy with the shape of your river, you can use the *River -> Generate Flow & Foam Map* option to bake out the textures that activate flow map and foam. The settings for the baking are located in the river's inspector, see section below.
![GU7fDHXmmJ](https://user-images.githubusercontent.com/4955051/102623078-de182e00-4139-11eb-8e65-d95bad4ed310.gif)

**Generating a Mesh Copy**

In case you want to access the river mesh directly to use it for other purposes such as generating a collision shape. You can use the *River -> Generate MeshInstance Sibling* option.
![b5qdG0oYbV](https://user-images.githubusercontent.com/4955051/102623733-e1f88000-413a-11eb-8c79-99a1977fbca9.gif)

River Parameters
----------------
The river's parameters are split into 4 sections.

**Shape**

- *Step Length Divs* - How many subdivision the river with lef per step along it's length.
- *Step Width Divs* - How many subdivision the river with lef per step along it's width.
- *Smoothing* - How much the shape of the river is relaxed to even out corners.

**Material**

- *Flow Speed* - How fast the river flows.
- *Texture* - The pattern used for the water. RG channels hold the normal map and B holds the foam pattern.
- *Tiling* - The UV tiling used on the above texture.
- *Normal Scale* - The strength of the normal mapping.
- *Albedo* - The colour of the water will display beyond the clarity threshold.
- *Clarity* - How far light can travel in the water before only returning the albedo colour.
- *Roughness* - The roughness of the water surface, also affects the blurring that occurs in the refraction.
- *Refraction* - How much the background get's bent by the water shape.
- *Foam Albedo* - The colour of the foam.
- *Foam Ammount* - Controls the foam cutoff in the shader, you may have to use the foam baking setting to change the amount of foam further. See below.
- *Foam Smoothness* - Controls how the foam layers are combined to give a sharper or softer look.

**Lod**

- *Lod0 Distance* - Controls the cutoff point for whether the shader samples textures twice to create an FBM effect for the waves and foam.

**Baking**

- *Resolution* - Controls the resolution of the baked flow and foam map. This texture does not need to be very large to look decent, so only increse it if needed as the baking time can increase a lot.
- *Dilate* - The amount of dilation happening to convert the collision map to an Distance Field. This value should generally not be adjusted.
- *Flowmap Blur* - How much the flowmap is blurred to clear up seams or artifacts.
- *Foam Cutoff* - How much of the Distance Field is cut off to generate the foam mask. Increasing this calue will make the foam mask tighter around the collisions.
- *Foam Offset* - How far the foam strethes along the flow direction.
- *Foam Blur* - How much the foam mask is blurred.

Current Limitations
-------------------
* There is only a river node so far, so no solution for lakes or oceans.
* There is no system for detecting whether you are under the water and no effects to imitate the under water view.
* There are no real time reflections on the water. Since godot does not allow Screen Space Reflections with transparent objects, the built-in SSR effect cannot be used. I will probably implement my own eventually.
* There is no mesh displacement. Since Godot does not have tesselation, mesh displacement is not feasible.
* Rivers do not interact with each other. At the moment there is no way to elegantly merge multiple rivers into one or splitting one into multiple. I plan to implement a solution for this eventually.

Acknowledgements
---------------
* Thanks to my patrons *Marcus Richter, Dmitriy Keane, spacechace0 and Johannes Wuesnch* for all their support.

Several people in the Godot community have helped me out with this.
* *Zylann* has been really helpful, both with any issues I've had working on terrains, but also in that whenever I don't know how to do something in a plugin I generally find the answer somewhere in his code.
* *HungryProton* has given me a ton of help setting up the Gizmo's to make custom editing tools for the river.
* *Rodzilla* helped me figure out how to generate the various textures for the flow and foam and a lot of the code for rendering the maps are directly inspired by his incredible [Material Maker](https://rodzilla.itch.io/material-maker) tool.

Beyond the Godot community, I should also mention these resources.
* The flowmap shader implementation was heavily inspired by CatLikeCoding's excellent article on the subject. https://catlikecoding.com/unity/tutorials/flow/texture-distortion/

Contributing
------------
If you want to contribute to the project or just work on your own version, clone the repository and add [Zylann's terrain addon](https://github.com/Zylann/godot_heightmap_plugin) into the project as I don't include it in this repository, but use it in the test scene.
