# Projection Mapping with TouchDesigner: A Beginner's Guide

This guide will walk you through a simple projection mapping setup using the `kantanMapper` tool in TouchDesigner.

## 1. Load the Mapper

First, you need to add the `kantanMapper` component to your project.

1.  Press `Alt + L` to open the **Palette**.
2.  Navigate to **Mapping > kantanMapper**.
3.  Drag the `kantanMapper` tool into your main Network Editor (the grid area).
4.  You can now close the Palette window.

## 2. Configure the Projector Output

Next, you need to send the output to your projector.

1.  Click on the `kantanMapper` node to select it.
2.  In the properties panel on the right, find the **Open Kantan Window** parameter and click the **Pulse** button next to it.
3.  A new "Kantan" window will appear. In the top-left corner, click **Window Options**.
4.  Set the **Monitor** to `1`. (Monitor `0` is typically your primary laptop screen, and `1` is the external projector).
5.  Set the **Opening Size** to **Fill**.
6.  Close the options panel.
7.  In the main Kantan window's left menu, click **Toggle Output** to activate the projection.

## 3. Load Your Media

It's more reliable to load your visual content (videos or images) into TouchDesigner first, before assigning it in the mapper.

1.  Find a video or image file on your computer.
2.  Drag and drop it directly into the main TouchDesigner Network Editor.
3.  This will create a new TOP operator (usually a purple node), for example, `moviefilein1`. Take note of this name.

## 4. Map and Assign Your Texture

Now you will create a mapping shape (a quad) and assign your media to it.

1.  Go back to the **Kantan Window**.
2.  In the "Tools" section, click **Create Quad** (it looks like a square icon).
3.  Click and drag your mouse on the canvas to draw a rectangular shape. You should see this shape appear on your projection surface.
4.  With the new quad selected, look at the sidebar on the right.
5.  Find the **Texture** parameter field.
6.  To assign your media, you can either:
    *   **Drag & Drop:** Drag the purple `moviefilein1` node from your Network Editor and drop it directly onto the **Texture** field.
    *   **Type Path:** Manually type the path to your media node, for example: `/project1/moviefilein1`.

**Important:** If the shape remains a solid blue color, click the "X" button next to the texture field to ensure the texture is active.

## 5. Final Adjustments

The last step is to align your projection with the physical object.

1.  Click and drag the corners of the quad in the Kantan window to match the shape of your physical object.
2.  To get a clean final output, click **Show Guides** in the top menu of the Kantan window to toggle them **OFF**. This will hide the grid lines from the final projection.