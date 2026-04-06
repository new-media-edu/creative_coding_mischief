# TouchDesigner Plain Text Workflow

While TouchDesigner projects are primarily node-based and binary (`.toe`), this directory demonstrates how to bridge the gap using plain-text scripts and configuration files.

## Files
- `build_network.py`: A Python script to programmatically build a projection mapping network.
- `mapper_config.json` (planned): A JSON file to store surface and corner-pinning coordinates.

## How to use `build_network.py`

1.  Open TouchDesigner.
2.  In the network editor, create a **Text DAT** (shortcut: `Alt + Shift + t`).
3.  Right-click the Text DAT and select **Edit in External Editor** or simply paste the contents of `build_network.py` into it.
4.  Right-click the Text DAT again and select **Run Script**.

### What it builds:
- A `Serial CHOP` to receive Arduino data (defaulting to COM3/9600).
- A `Noise TOP` that modulates its 'Period' based on the incoming Serial value.
- A `Corner Pin TOP` connected to the Noise for surface mapping.
- A `Window COMP` configured for fullscreen output on monitor 1 (projector).

## Version Control Tips for TouchDesigner
- **Exporting to Text**: Use the `TDJSON` module (`import TDJSON`) to save your custom parameters and mapping states to `.json` files for Git tracking.
- **External .py files**: You can point a **Text DAT** to an external `.py` file on your disk. This allows you to edit your TouchDesigner logic using a standard text editor (like VS Code) and have the changes reflect inside TD immediately.
