import td


def build_minimal_mapper():
    """
    Programmatically builds a minimal projection mapping network:
    Serial Input -> Generative Visual -> Corner Pin -> Window Output
    """

    # 1. Create a Base COMP to contain our network
    root = ui.panes[0].owner  # Current network location
    container = root.create(baseCOMP, "text_built_mapper")
    container.nodeX = 0
    container.nodeY = 0

    # --- INPUT SECTION ---
    # 2. Create Serial CHOP (for Arduino)
    serial = container.create(serialCHOP, "arduino_in")
    # On macOS, serial ports look like /dev/cu.usbmodem* or /dev/cu.usbserial*
    # On Windows, they look like COM3, COM4, etc.
    serial.par.port = "/dev/cu.usbmodem1101"
    serial.par.baudrate = 9600
    serial.par.active = True
    serial.nodeX = -400
    serial.nodeY = 0

    # --- VISUAL SECTION ---
    # 3. Create Noise TOP (Generative Visual)
    noise = container.create(noiseTOP, "gen_visual")
    noise.par.resolutionw = 1280
    noise.par.resolutionh = 720
    noise.par.mono = False
    noise.nodeX = -200
    noise.nodeY = 100

    # Link Serial to Noise (Simulating the modulation from your Processing app)
    # We'll use a reference expression: the Noise 'Period' is modulated by the first channel of Serial
    noise.par.period.expr = (
        "op('arduino_in')[0] * 10 if op('arduino_in').numChans > 0 else 1.0"
    )

    # --- MAPPING SECTION ---
    # 4. Create Corner Pin TOP (The Mapper)
    corner_pin = container.create(cornerpinTOP, "mapper")
    corner_pin.inputConnectors[0].connect(noise)
    corner_pin.nodeX = 0
    corner_pin.nodeY = 100

    # Set default corner pinning values (Pin page)
    # pinp3 = bottom left, pinp4 = bottom right, pinp1 = top left, pinp2 = top right
    corner_pin.par.pinp3x, corner_pin.par.pinp3y = 0.1, 0.1
    corner_pin.par.pinp4x, corner_pin.par.pinp4y = 0.9, 0.1
    corner_pin.par.pinp1x, corner_pin.par.pinp1y = 0.1, 0.9
    corner_pin.par.pinp2x, corner_pin.par.pinp2y = 0.9, 0.9

    # --- OUTPUT SECTION ---
    # 5. Create Window COMP (Projector Output)
    out_window = container.create(windowCOMP, "projector_output")
    out_window.par.winop = corner_pin.path
    # Set the monitor/display index in the Window COMP parameters panel manually
    out_window.par.borders = False
    out_window.nodeX = 200
    out_window.nodeY = 100

    print(f"Successfully built mapping network in {container.path}")


# Run the builder
build_minimal_mapper()
