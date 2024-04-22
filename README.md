# Resizable-Selectable-Components for Godot 4
This repository contains simple dynamic components to allow selection, resizing and moving of nodes at runtime in Godot applications/games.

Nodes can be resized/moved by clicking and dragging them or their handles. They also have an Edit mode to allow precice placements (using magnetism and helper dotted lines).

A lot of options are provided, and the node can be selected and moved together if desired as well.

There is a demo project with the components inside so you can test them without impacting your own project.

[Demo 1.webm](https://github.com/TheRealSlander/Resizable-Selectable-Components/assets/102065761/98edee20-9223-4ed7-9326-e3898c8b995d)

A simple panel is available to edit the position/size of the nodes but you can provide your own if desired. The default panel is also smartly placed according to the available space around the edited node.

[Demo 2.webm](https://github.com/TheRealSlander/Resizable-Selectable-Components/assets/102065761/e6b946e0-4d4f-4a7a-ba31-e6efd35d6c0d)


## How to install the components
- Create a new project or have an already working Godot project, then add the Resizable and Selectable nodes folders to your project.
- Add the "Utils.gd" and "Signals.gd" scripts in your project structure as well. These 2 scripts have to be loaded as autoloads. If you already use these 2 scripts names, simply copy/paste the content inside your files.

## How to use the components
- In your scene, instantiate a ResizableNode wherever you want (you can use Ctrl + Shit + A to do so).
- You can configure its behavior in the inspector. There is a lot of options and each of them has a simple hint documentation (see video below).
- If you want the node to also be selectable, simply add a SelectableNode instance as a child of the ResizableNode. You don't need to code anything, all is done under the hood for you.

In order to make the node movable, you need to make it a child of a non-container node (like Control for example). If you want to be able to use the Selectable feature, you have to make the nodes children of a SelectionContainer.

[Helper Hints.webm](https://github.com/TheRealSlander/Resizable-Selectable-Components/assets/102065761/24c2e9ae-729f-4342-a820-b67e2d1edd20)

## Dedicated Edit Controls Panel
By default, a Controls Panel is available somewhere around the ResizableNode (where there is space, or inside the node). But you can create your own following these rules:
- 4 LineEdits with names %"Left Edit", %"Top Edit", %"Width Edit" and %"Height Edit"
- 2 Buttons with names %"Snapping Button" and %"Free Button"
- All the nodes above must use the Unique Name feature of Godot
- You must attach the "Resizable Node Basic Control.gd" script to the panel for it to work
- Finally, hide the snapping button to keep things consistent

Then you can design your Panel as you wish, all the work is done in the background by the component's script.

![image](https://github.com/TheRealSlander/Resizable-Selectable-Components/assets/102065761/7c080620-74b1-4581-8194-82504d99f618)

## What's next
These components will probably receive updates if new features are needed or if bugs are found.

## Known issues
Actually none. Don't hesitate to contact me if you find some.

The components are not working with the Godot version 4.3.devx as there is a bug with the reparent() method in the current version. So stick to Godot 4.2 if you want to use them.
