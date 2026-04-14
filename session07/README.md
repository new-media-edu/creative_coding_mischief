# Session 07: Processing → Arduino

Last session we sent data from the Arduino to Processing. Today we go the other direction: Processing sends data to the Arduino. We'll use mouseX and mouseY to control the 2-DOF robot arms you built in Session 05. We'll also look at Hydra as a web-based alternative for visuals. At the end of class, everyone will share what they're thinking about for their final projects.

## Agenda

+ Processing → Arduino: controlling servos from the screen
+ Mouse-controlled robot arm
+ Alternative: Hydra + Web Serial
+ Final project brainstorm and share

---

## Part 1: Processing → Arduino (Mouse Controls Robot Arm)

In Session 05 you built a robot arm with two servos and two potentiometers. Today we swap out the potentiometers for your mouse. mouseX controls the base servo, mouseY controls the arm servo.

### The Plan

```
[ mouseX ] → map(0–180) ─┐
                          ├→ myPort.write(baseAngle, armAngle) → USB → Arduino → Servo.write()
[ mouseY ] → map(0–180) ─┘
```

### The Arduino Code

The Arduino waits for two bytes to arrive on the serial port: the first is the base angle, the second is the arm angle.

#### Circuit

Same robot arm circuit from Session 05. You only need the two servos wired up today — the potentiometers can stay connected but we won't be reading them.

1.  Servo 1 (Base): Signal → Pin 7, Red → 5V, Brown → GND
2.  Servo 2 (Arm): Signal → Pin 9, Red → 5V, Brown → GND

<p>
  <img src="../session05/2pot-2servo.png" alt="2 potentiometer 2 servo circuit" width="600">
  <br>
  <em><a href="https://www.tinkercad.com/things/3q7nDz11QsR-2-potentiometer-2-servo">Tinkercad Circuit</a></em>
</p>

#### Arduino Code

```cpp
#include <Servo.h>

Servo baseServo;
Servo armServo;

void setup() {
  baseServo.attach(7);
  armServo.attach(9);
  Serial.begin(9600);
}

void loop() {
  // Wait until we have at least 2 bytes available
  if (Serial.available() >= 2) {
    int baseAngle = Serial.read();
    int armAngle = Serial.read();

    baseServo.write(baseAngle);
    armServo.write(armAngle);
  }
}
```

### The Processing Code

Processing maps the mouse position to two servo angles and sends them as two bytes each frame.

```java
import processing.serial.*;

// A variable to hold our serial connection to the Arduino.
Serial port;

void setup() {
  // Create a 600x600 pixel window.
  size(600, 600);

  // Print available serial ports to the console so you can find your Arduino.
  printArray(Serial.list());

  // Open the serial port. Change the [3] to match your Arduino's
  // position in the list printed above.
  port = new Serial(this, Serial.list()[3], 9600);
}

void draw() {
  // Redraw the background each frame.
  background(30);

  int baseAngle = (int) map(mouseX, 0, width, 0, 180);
  int armAngle = (int) map(mouseY, 0, height, 0, 180);

  baseAngle = constrain(baseAngle, 0, 180);
  armAngle = constrain(armAngle, 0, 180);

  // Send both angles to the Arduino as raw bytes.
  port.write(baseAngle);
  port.write(armAngle);

  // --- Visual feedback on screen ---
  stroke(255, 150, 0);  // Orange lines
  strokeWeight(2);
  line(mouseX, 0, mouseX, height);
  line(0, mouseY, width, mouseY);

  fill(255);
  noStroke();
  textSize(16);
  text("Base: " + baseAngle + "°", 10, 30);
  text("Arm: " + armAngle + "°", 10, 55);
}
```

---

## Part 2: Alternative — Hydra + Web Serial

[Hydra](https://hydra.ojack.xyz/) is a live-coding video synthesizer that runs in your browser. It's inspired by analog modular synthesizers.

You can connect your Arduino to Hydra using the **Web Serial API**. This allows your physical knobs to control visual parameters in real-time without installing any software.

### The Hydra Setup

We've included a standalone example in the `hydra/` folder:
- **`hydra_serial.html`**: Open this file in Chrome or Edge. Click "Connect Arduino" and use your potentiometers to control kaleidoscope patterns, feedback loops, and noise melts.

The example uses the same "comma-separated" values we learned in Session 06:
```javascript
// Example Hydra snippet controlled by Arduino
osc(() => knob1 * 60, 0.1, () => knob2 * 2)
  .color(0.9, 0.3, () => knob2)
  .rotate(() => knob1 * Math.PI)
  .out();
```

---

## Part 3: Final Project Brainstorm

We spent a significant portion of this session discussing final project ideas. Students shared their inspirations and technical hurdles.

### Sharing Session
Everyone shared what they're building, which tools from the course they want to use, and what they still need to figure out.

### Common Themes
- Interactive installations using servos and ultrasonic sensors.
- Generative art controlled by physical interfaces (buttons/pots).
- Wearable tech and musical instruments.

The rest of the term will focus on refining these ideas and building the prototypes.
