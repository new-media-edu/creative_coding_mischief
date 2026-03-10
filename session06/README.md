# Session 06: Arduino ↔ Processing

Last session, you met Processing and drew shapes on screen with code. Today, we connect the two worlds: Arduino talks to Processing, and Processing talks back to Arduino. By the end of this session, your physical sensors will control on-screen visuals, and your mouse will move a servo motor, all over a single USB cable.

## Agenda

+ Sending data from Arduino to Processing (potentiometer → circle size)
+ Sending data from Processing to Arduino (mouse position → servo angle)
+ Combining both directions: full two-way communication


## Part 1: Arduino → Processing (Potentiometer Controls Circle Size)

In this first example, we'll read a potentiometer on the Arduino and send its value to Processing over the serial port. Processing will use that value to control the size of a circle on screen.

### The Plan

```
[ Potentiometer ] → analogRead() → Serial.println() → USB cable → Processing serial.read() → circle size
```

### Step 1: The Arduino Code

This is straightforward. We've done this before. Read the pot, and print the value to Serial. The only thing that's new is that we're being more deliberate about the format: we send one number per line with `Serial.println()`, because Processing will read one line at a time.

#### Circuit

1.  Potentiometer: Outer pins → 5V and GND, Middle pin → A0

#### Arduino Code

```cpp
int POT_PIN = A0;

void setup() {
  Serial.begin(9600);
}

void loop() {
  int potValue = analogRead(POT_PIN);

  // Send the value as a line of text.
  // println() adds a newline character at the end,
  // which Processing will use to know when a complete value has arrived.
  Serial.println(potValue);

  delay(50); // Send ~20 values per second. Don't flood the serial port!
}
```

Upload this to your Arduino. You can verify it works by opening the Serial Monitor. You should see numbers from 0 to 1023 streaming by.

> Important: Close the Serial Monitor before running Processing! Only one program can use the serial port at a time. If the Serial Monitor is open, Processing won't be able to connect.

### Step 2: The Processing Code

Now open Processing (not the Arduino IDE) and paste the following code into a new sketch.

Processing has a built-in Serial library. We import it, open the same serial port the Arduino is connected to, and read incoming lines of text.

#### Processing Code

```java
import processing.serial.*;

Serial myPort;      // The serial port object
int circleSize = 0; // This will be controlled by the Arduino

void setup() {
  size(600, 600);  // Create a 600×600 pixel window

  // Print available serial ports to the console.
  // Look for the one that matches your Arduino (e.g., /dev/ttyUSB0, /dev/ttyACM0, COM3).
  printArray(Serial.list());

  // Open the serial port. Change the index [0] to match your Arduino's port.
  // On Linux it's often /dev/ttyUSB0 or /dev/ttyACM0.
  // On Mac it's often /dev/cu.usbmodem... 
  // On Windows it's often COM3 or COM4.
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 9600);

  // Tell Processing to buffer incoming data until it sees a newline character.
  // This way, serialEvent() will only fire when a complete line has arrived.
  myPort.bufferUntil('\n');
}

void draw() {
  background(30);  // Dark background, redrawn every frame

  // Draw a circle in the center of the window.
  // The size is controlled by the Arduino's potentiometer.
  fill(255, 150, 0);  // Orange
  noStroke();
  ellipse(width / 2, height / 2, circleSize, circleSize);

  // Display the current value as text
  fill(255);
  textSize(16);
  text("Value: " + circleSize, 10, 30);
}

// This function is called automatically whenever a complete line arrives on the serial port.
void serialEvent(Serial myPort) {
  // Read the incoming line and trim any whitespace/newline characters.
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    inString = trim(inString);

    // Convert the string to an integer.
    int value = int(inString);

    // Map the Arduino's 0–1023 range to a circle diameter (10–500 pixels).
    circleSize = (int) map(value, 0, 1023, 10, 500);
  }
}
```

### Running It

1.  Upload the Arduino code to your board.
2.  Close the Arduino Serial Monitor.
3.  Run the Processing sketch (click the Play button).
4.  Turn the potentiometer. The circle on screen should grow and shrink.

> Troubleshooting: "Port busy" or no data?
> - Make sure the Arduino Serial Monitor is closed.
> - Check the console output from `printArray(Serial.list())` and adjust the index in `Serial.list()[0]` if your Arduino isn't the first port listed.
> - Make sure the baud rate matches (9600 on both sides).


## Part 2: Processing → Arduino (Mouse Position Controls Servo)

Now let's go the other direction. Processing will read the mouse's X position and send it to the Arduino, which will use it to rotate a servo motor. Move the mouse left → servo goes to 0°. Move right → servo goes to 180°.

### The Plan

```
[ Mouse X ] → map() → myPort.write() → USB cable → Serial.read() → Servo.write()
```

### Step 1: The Arduino Code

The Arduino listens for incoming bytes on the serial port. Each byte is a number from 0–180 representing the desired angle.

#### Circuit

1.  Servo: Red → 5V, Brown → GND, Signal → Pin 9

#### Arduino Code

```cpp
#include <Servo.h>

Servo myServo;

void setup() {
  myServo.attach(9);
  Serial.begin(9600);
}

void loop() {
  // Check if data is available on the serial port
  if (Serial.available() > 0) {
    // Read one byte. This will be a number 0–180.
    int angle = Serial.read();

    // Move the servo to that angle
    myServo.write(angle);
  }
}
```

### Step 2: The Processing Code

Processing reads the mouse X position, maps it to 0–180, and sends it to the Arduino as a single byte.

#### Processing Code

```java
import processing.serial.*;

Serial myPort;

void setup() {
  size(600, 600);

  printArray(Serial.list());
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 9600);
}

void draw() {
  background(30);

  // Map the mouse X position (0 to window width) to a servo angle (0–180)
  int angle = (int) map(mouseX, 0, width, 0, 180);

  // Constrain to make sure we stay in the valid range
  angle = constrain(angle, 0, 180);

  // Send the angle to the Arduino as a single byte
  myPort.write(angle);

  // Draw a visual indicator on screen
  // A line that rotates to match the servo angle
  stroke(255, 150, 0);
  strokeWeight(4);
  float radians = radians(angle - 90); // Offset so 90° points up
  float lineX = width / 2 + cos(radians) * 150;
  float lineY = height / 2 + sin(radians) * 150;
  line(width / 2, height / 2, lineX, lineY);

  // Display the angle
  fill(255);
  noStroke();
  textSize(16);
  text("Angle: " + angle + "°", 10, 30);
  text("Move mouse left/right", 10, 55);
}
```

### Running It

1.  Upload the Arduino code.
2.  Close the Serial Monitor.
3.  Run the Processing sketch.
4.  Move your mouse left and right across the Processing window. The servo should follow.


## Part 3: Two-Way Communication

Now let's put it all together. The Arduino sends potentiometer data to Processing and receives servo commands from Processing, all over the same serial connection.

This requires a simple rule so both sides know what's a message and what's a response. We'll use a call-and-response (handshake) protocol:

1.  Arduino sends its sensor data as a line of text.
2.  Processing receives it, updates the visuals, and sends back a servo angle byte.
3.  Arduino receives the byte, moves the servo, and sends the next sensor reading.

This way the two programs stay in sync and don't flood each other.

### Arduino Code (Two-Way)

#### Circuit

1.  Potentiometer: Middle pin → A0, Outer pins → 5V and GND
2.  Servo: Signal → Pin 9, Red → 5V, Brown → GND

```cpp
#include <Servo.h>

Servo myServo;
int POT_PIN = A0;

void setup() {
  myServo.attach(9);
  Serial.begin(9600);

  // Send a starting value so Processing knows we're ready
  Serial.println(analogRead(POT_PIN));
}

void loop() {
  // Check if Processing has sent us a servo angle
  if (Serial.available() > 0) {
    // Read the angle byte from Processing
    int angle = Serial.read();
    myServo.write(angle);

    // Now send back the current potentiometer reading
    int potValue = analogRead(POT_PIN);
    Serial.println(potValue);
  }
}
```

### Processing Code (Two-Way)

```java
import processing.serial.*;

Serial myPort;
int circleSize = 0;  // Controlled by Arduino's pot

void setup() {
  size(600, 600);

  printArray(Serial.list());
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 9600);
  myPort.bufferUntil('\n');
}

void draw() {
  background(30);

  // --- Draw the pot-controlled circle ---
  fill(255, 150, 0);
  noStroke();
  ellipse(width / 2, height / 2, circleSize, circleSize);

  // --- Draw the servo angle indicator ---
  int angle = (int) map(mouseX, 0, width, 0, 180);
  angle = constrain(angle, 0, 180);

  stroke(100, 200, 255);
  strokeWeight(3);
  float rad = radians(angle - 90);
  float lx = width / 2 + cos(rad) * 150;
  float ly = height / 2 + sin(rad) * 150;
  line(width / 2, height / 2, lx, ly);

  // --- Display info ---
  fill(255);
  noStroke();
  textSize(16);
  text("Pot → Circle: " + circleSize, 10, 30);
  text("Mouse → Servo: " + angle + "°", 10, 55);
}

void serialEvent(Serial myPort) {
  String inString = myPort.readStringUntil('\n');

  if (inString != null) {
    inString = trim(inString);
    int value = int(inString);
    circleSize = (int) map(value, 0, 1023, 10, 500);

    // Now send the mouse-based servo angle back to Arduino.
    // This completes the "call and response" handshake.
    int angle = (int) map(mouseX, 0, width, 0, 180);
    angle = constrain(angle, 0, 180);
    myPort.write(angle);
  }
}
```

### Running It

1.  Upload the Arduino code.
2.  Close the Serial Monitor.
3.  Run the Processing sketch.
4.  Turn the potentiometer. The orange circle changes size.
5.  Move the mouse. The servo rotates and the blue indicator line follows.
6.  Both happen simultaneously over the same USB cable!


## How the Handshake Works

```
Arduino                          Processing
  │                                  │
  ├── println(potValue) ──────────►  │  serialEvent() fires
  │                                  │  updates circle size
  │  ◄──────────── write(angle) ────┤  sends servo command
  │  moves servo                     │
  ├── println(potValue) ──────────►  │  serialEvent() fires again
  │                                  │  ...
  ▼                                  ▼
```

The Arduino only sends a new reading after it receives a byte from Processing. This keeps them in lockstep and prevents the serial buffer from overflowing. Without this handshake, data can pile up and cause lag or garbled values.


## Troubleshooting Guide

| Problem | Likely Cause | Fix |
|---|---|---|
| "Port busy" error in Processing | Arduino Serial Monitor is still open | Close the Serial Monitor |
| No data / circle doesn't move | Wrong serial port selected | Check `printArray(Serial.list())` output and adjust the index |
| Garbled numbers or weird values | Baud rate mismatch | Make sure both sides use `9600` |
| Servo jitters wildly | Processing sending data too fast | Use the handshake approach (Part 3) instead of sending every frame |
| Values are delayed / laggy | Serial buffer filling up | Reduce `delay()` in Arduino code, or use the handshake |
| Processing sketch is blank | Processing can't find the port | Run as administrator, or check USB cable |


## Key Concepts Summary

| Concept | What It Does |
|---|---|
| `Serial.println(value)` | Arduino sends a value as a line of text |
| `Serial.read()` | Arduino reads one byte from the serial port |
| `Serial.available()` | Checks if data is waiting to be read |
| `import processing.serial.*` | Loads Processing's serial library |
| `new Serial(this, port, baud)` | Opens a serial connection in Processing |
| `myPort.bufferUntil('\n')` | Tells Processing to wait for a full line |
| `serialEvent()` | Called automatically when a line arrives |
| `myPort.write(value)` | Processing sends a byte to Arduino |
| Call-and-response handshake | Keeps Arduino and Processing in sync |
