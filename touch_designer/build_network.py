import td

def build_minimal_mapper():
    """
    Programmatically builds a minimal projection mapping network:
    Serial Input -> Generative Visual -> Corner Pin -> Window Output
    """
    
    # 1. Create a Base COMP to contain our network
    root = ui.panes[0].owner # Current network location
    container = root.create(baseCOMP, 'text_built_mapper')
    container.nodeX = 0
    container.nodeY = 0

    # --- INPUT SECTION ---
    # 2. Create Serial CHOP (for Arduino)
    serial = container.create(serialCHOP, 'arduino_in')
    serial.par.port = 'COM3' # User should change this
    serial.par.baud = 9600
    serial.par.active = True
    serial.nodeX = -400
    serial.nodeY = 0

    # --- VISUAL SECTION ---
    # 3. Create Noise TOP (Generative Visual)
    noise = container.create(noiseTOP, 'gen_visual')
    noise.par.resolutionw = 1280
    noise.par.resolutionh = 720
    noise.par.monochrome = False
    noise.nodeX = -200
    noise.nodeY = 100
    
    # Link Serial to Noise (Simulating the modulation from your Processing app)
    # We'll use a reference expression: the Noise 'Period' is modulated by the first channel of Serial
    noise.par.period.expr = "op('arduino_in')[0] * 10 if op('arduino_in').numChans > 0 else 1.0"

    # --- MAPPING SECTION ---
    # 4. Create Corner Pin TOP (The Mapper)
    corner_pin = container.create(cornerpinTOP, 'mapper')
    corner_pin.connect(noise)
    corner_pin.nodeX = 0
    corner_pin.nodeY = 100
    
    # Set default corner pinning values (pinned to screen corners)
    # botleft, botright, topleft, topright (0-1 range)
    corner_pin.par.llx, corner_pin.par.lly = 0.1, 0.1
    corner_pin.par.lrx, corner_pin.par.lry = 0.9, 0.1
    corner_pin.par.ulx, corner_pin.par.uly = 0.1, 0.9
    corner_pin.par.urx, corner_pin.par.ury = 0.9, 0.9

    # --- OUTPUT SECTION ---
    # 5. Create Window COMP (Projector Output)
    out_window = container.create(windowCOMP, 'projector_output')
    out_window.par.operator = corner_pin.path
    out_window.par.monitor = 1 # Set to 2 for external projector
    out_window.par.borders = False
    out_window.par.fullscreen = True
    out_window.nodeX = 200
    out_window.nodeY = 100

    print(f"Successfully built mapping network in {container.path}")

# Run the builder
if __name__ == "__main__":
    build_minimal_mapper()
