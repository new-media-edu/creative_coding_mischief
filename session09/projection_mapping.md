This guide walks you through a simple projection mapping setup using the `kantanMapper` tool in TouchDesigner.

Before you start, download this VJ pack and use clips from the "mp4" folder:
https://drive.google.com/drive/folders/1cxOtitX3fUVFC7dv5_FeAjSED2p31LM4?usp=sharing
You can also browse https://www.reddit.com/r/VJloops/ for more loop content.

Add the `kantanMapper` component to your project:
- Press `Alt + L` to open the **Palette**.
- Navigate to **Mapping > kantanMapper**.
- Drag `kantanMapper` into the main Network Editor (the grid area).
- Close the Palette window.

Send output to your projector:
- Click the `kantanMapper` node.
- In the parameter panel, find **Open Kantan Window** and click **Pulse**.
- In the Kantan window, click **Window Options** (top-left).
- Set **Monitor** to `1` (usually projector), since `0` is usually your laptop display.
- Set **Opening Size** to **Fill**.
- Close options.
- In the Kantan window left menu, click **Toggle Output**.

Load media into TouchDesigner before assigning textures:
- Pick a video or image file (the VJ pack's "mp4" folder is a good starting point).
- Drag it into the main Network Editor.
- TouchDesigner will create a TOP node (usually purple), for example `moviefilein1`.

Create a quad and assign texture:
- Return to the **Kantan Window**.
- In **Tools**, click **Create Quad** (square icon).
- Click and drag on the canvas to draw the mapping shape.
- Select the new quad and find the **Texture** field on the right.
- Assign media by either dragging `moviefilein1` onto **Texture**, or typing `/project1/moviefilein1`.

If the quad stays solid blue, click the `X` next to the texture field and reassign the texture.

Align and clean the final output:
- Drag quad corners in the Kantan window to match your physical surface.
- Toggle **Show Guides** off to hide grid lines in the final projection.