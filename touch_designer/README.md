# TouchDesigner Plain Text Workflow

While TouchDesigner projects are primarily node-based and binary (`.toe`), this directory demonstrates how to bridge the gap using plain-text scripts and configuration files.

## Files
- `build_network.py`: A Python script to programmatically build a projection mapping network.
- `mapper_config.json` (planned): A JSON file to store surface and corner-pinning coordinates.

## How to use `build_network.py`

1.  Open TouchDesigner.
2.  In the main canvas, press **Tab** to open the OP Create dialog. Navigate to **DAT > Text** and click to place a **Text DAT** (green node). Do **not** use a Text TOP (purple node) — that is for rendering visual text, not running scripts.
3.  Click the Text DAT to select it. In the **Parameters** panel on the right, under the **File** page, click the **Edit..** button to open a text editor where you can paste the contents of `build_network.py`. Alternatively, set the **File** field to the full path of the script (e.g. `/Users/you/path/to/build_network.py`) and click **Load File** to pull it in.
4.  Right-click the Text DAT and select **Run Script**.

### Viewing errors and script output

If nothing happens after running a script, check the **Textport** for error messages:
- Open it via **Dialogs > Textport**, or press **Alt+Shift+T**, or press **F4** (opens as a floating window).
- Make sure the toggle in the upper-left corner of the Textport is set to **Py** (Python mode).
- All `print()` output and script errors from DATs appear here.
- You can also drag a Text DAT onto the Textport and choose **Run DAT** to execute it directly there.

### What it builds:
- A `Serial CHOP` to receive Arduino data (defaulting to COM3/9600).
- A `Noise TOP` that modulates its 'Period' based on the incoming Serial value.
- A `Corner Pin TOP` connected to the Noise for surface mapping.
- A `Window COMP` configured for fullscreen output on monitor 1 (projector).

## Version Control Tips for TouchDesigner
- **Exporting to Text**: Use the `TDJSON` module (`import TDJSON`) to save your custom parameters and mapping states to `.json` files for Git tracking.
- **External .py files**: You can point a **Text DAT** to an external `.py` file on your disk. This allows you to edit your TouchDesigner logic using a standard text editor (like VS Code) and have the changes reflect inside TD immediately.
