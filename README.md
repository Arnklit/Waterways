# WaterGenGodot
A tool for generating rivers in Godot

![KjZyHryU2y](https://user-images.githubusercontent.com/4955051/101739852-08c21100-3ac0-11eb-82e1-86cefb0bd06b.gif)

[Discord Server](https://discord.gg/mjGvWwQwv2)

[Patreon](https://www.patreon.com/arnklit)

Instalation
-----------
Copy the addons folder into your godot project and activate the addon from *Project -> Project Settings -> Plugins*

If you want to open the entire project to view the test scene, you will need to also install a copy of [Zylann's terrain addon](https://github.com/Zylann/godot_heightmap_plugin) into the project as I don't include it in this repository, but use it in the test scene.

Purpose
-------
I've been very impressed with examples of using flowmaps to imitate water simulations in games for a while, but most of the implementations I've seen were using either manually painted flowmaps, or flowmaps generated in an external program. I wanted to see if it was possible to have good flowmap results purely generated within Godot. Both the generation of the flowmaps and the generation of the mesh for the river was of interest to me and I've learned a lot implementing my solution.

Usage
-----
Once the addon is active, you can simply add a River node to the scene.
![image](https://user-images.githubusercontent.com/4955051/101054612-f8baa680-3580-11eb-89ef-a406b248b0e3.png)

You can then use the Path controls to shape the river to your liking. The "Snap to colliders" option can be used to easily place the path of the river along a terrain.

Once you are happy with the shape of your river, you can use the *River -> Generate Flow & Foam Map* to bake out the textures that activate flow map and foam.

Current Limitations
-------------------
* There is only a river node so far, so no solution for lakes or oceans.
* There is no system for detecting whether you are under the water and no effects to imitate the under water view.
* There are no real time reflections on the water. Since godot does not allow Screen Space Reflections with transparent objects, the built-in SSR effect cannot be used. I will probably implement my own eventually.
* There is no mesh displacement. Since Godot does not have tesselation, mesh displacement is not feasible.
* Rivers do not interact with each other. At the moment there is no way to elegantly merge multiple rivers into one or splitting one into multiple. I plan to implement a solution for this eventually.

Acknowledgements
---------------
* A special thanks to my first ever patron *Marcus Richter* for his support.

Several people in the Godot community have helped me out with this.
* *HungryProton* has given me a ton of help setting up the Gizmo's to make custom editing tools for the river.
* *Rodzilla* helped me figure out how to generate the various textures for the flow and foam and a lot of the code for rendering the maps are directly inspired by his incredible [Material Maker](https://rodzilla.itch.io/material-maker) tool.

Beyond the Godot community, I should also mention these resources.
* The flowmap shader implementation was heavily inspired by CatLikeCoding's excellent article on the subject. https://catlikecoding.com/unity/tutorials/flow/texture-distortion/
