# 3D Printer Setup Guide

This guide covers how to set up and use the 3D printers available in the lab: the **Prusa i3 mk3** and the **Ender-3**.

## Software: PrusaSlicer

We recommend using **PrusaSlicer** for both printers. It is powerful, open-source, and has excellent built-in profiles for many printers, including the Ender-3.

**Download Link:** [Download PrusaSlicer](https://www.prusa3d.com/page/prusaslicer_424/)

---

## Important: File Naming Convention

The G-code files generated for one printer are **not compatible** with the other. To avoid confusion and potential damage to the machines, please prefix your exported G-code files according to the printer you sliced them for:

- **`P_`** for Prusa i3 mk3 (e.g., `P_knob_v1.gcode`)
- **`E_`** for Ender-3 (e.g., `E_knob_v1.gcode`)

---

## Printer Setup Instructions

### 1. Prusa i3 mk3

The Prusa is a reliable "workhorse" printer with automatic bed leveling.

1.  **Open PrusaSlicer.**
2.  Go to **Configuration Assistant** (Configuration -> Configuration Assistant).
3.  Select **Prusa FFF** -> **Original Prusa i3 MK3**.
4.  Note: The nozzle size is typically 0.4mm by default and may not be explicitly listed in the dropdown name.
5.  Finish the wizard.
6.  **Slicing:**
    *   **Print Settings:** 0.20mm QUALITY (or SPEED).
    *   **Filament:** Select the filament that is currently loaded on the machine (usually **Generic PLA**).
    *   **Printer:** Original Prusa i3 MK3.
7.  Click **Slice now**, then **Export G-code**. Remember to prefix with `P_`.

### 2. Creality Ender-3

The Ender-3 is a popular, capable printer but requires manual selection of its profile in PrusaSlicer.

1.  **Open PrusaSlicer.**
2.  Go to **Configuration Assistant**.
3.  Select **Other Vendors** -> **Creality**.
4.  Check **Creality Ender-3** (ensure the 0.4mm nozzle is selected).
5.  Finish the wizard.
6.  **Slicing:**
    *   **Print Settings:** 0.20mm NORMAL (Creality profile).
    *   **Filament:** Select the filament that is currently loaded on the machine (usually **Generic PLA**).
    *   **Printer:** Creality Ender-3.
7.  Click **Slice now**, then **Export G-code**. Remember to prefix with `E_`.

---

## Filament Advice

- **PLA is the way to go.** Unless you have a specific mechanical or aesthetic need, always use PLA. It is the easiest to print, has the best detail, and is biodegradable.
- **Match the machine:** Always check what is physically loaded on the printer before slicing. If the machine has Blue PLA, select "Generic PLA" or a matching brand preset.
- **Switching Filament:** If you want to switch colors or materials, ask for help if you haven't done it before.
- **Advanced Presets:** If you want to get more into 3D printing, you can look up the specific filament configurations (temperatures, retraction, etc.) for different brands and apply those as new presets in PrusaSlicer. Note that the **Configuration Assistant** can help you add many of these printer and filament presets (such as **Elegoo PLA+**) automatically.

---

## Printing Basics

1.  **Export your STL** from TinkerCAD (or your CAD tool of choice).
2.  **Import the STL** into PrusaSlicer.
3.  **Check Orientation:** Ensure the flattest part of your model is touching the heatbed. Use the "Place on Face" tool (shortcut `F`) if needed.
4.  **Supports:** If your model has overhangs greater than 45 degrees, change "Supports" from "None" to "Everywhere" or "Support on build plate only".
5.  **Infill:** 15-20% is standard for most decorative parts. Use 40% or more for mechanical parts like knobs.
6.  **Slice and Save:** Save the G-code to your SD card (Ender) or USB drive/SD card (Prusa).
