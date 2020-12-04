# WaterGenGodot
A tool for generating rivers in Godot

![nS5VdCT0xk](https://user-images.githubusercontent.com/4955051/101052950-20a90a80-357f-11eb-9735-68df07eb53ae.gif)

Instalation
-----------
Copy the addons folder into your godot project and activate the addon from *Project -> Project Settings -> Plugins*

If you want to open the entire project to view the test scene, you will need to also install a copy of [Zylann's terrain addon](https://github.com/Zylann/godot_heightmap_plugin) into the project as I don't include it in this repository, but use it in the test scene.

Usage
-----
Once the addon is active, you can simply create a River node to the scene.
![image](https://user-images.githubusercontent.com/4955051/101054612-f8baa680-3580-11eb-89ef-a406b248b0e3.png)

You can then use the Path controls to shape the river to your liking. The "Snap to colliders" option can be used to easily place the path of the river along a terrain.

Once you are happy with the shape of your river, you can use the *River -> Generate Flow & Foam Map* to bake out the textures that activate flow map and foam.



Acknowledgments
---------------
Several people in the Godot community have helped me out with this.
* HungryProton has given me a ton of help setting up the Gizmo's to make custom editing tools for the river.
* Rodzilla helped me figure out how to generate the various textures for the flow and foam and a lot of the code for rendering the maps are directly inspired by his incredible [Material Maker](https://rodzilla.itch.io/material-maker) tool.
* The flowmap shader implementation was heavily inspired by CatLikeCoding's excellent article on the subject. https://catlikecoding.com/unity/tutorials/flow/texture-distortion/
