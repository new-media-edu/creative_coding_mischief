# Session 07: Processing → Arduino

Last session we sent data from the Arduino to Processing. Today we go the other direction: Processing sends data to the Arduino. We'll use mouseX and mouseY to control the 2-DOF robot arms you built in Session 05. At the end of class, everyone will share what they're thinking about for their final projects.

## Agenda

+ Processing → Arduino: controlling servos from the screen
+ Mouse-controlled robot arm
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

Same robot arm circuit from Session 05:

1.  Servo 1 (Base): Signal → Pin 9, Red → 5V, Brown → GND
2.  Servo 2 (Arm): Signal → Pin 10, Red → 5V, Brown → GND

#### Arduino Code

```cpp
#include <Servo.h>

Servo baseServo;
Servo armServo;

void setup() {
  baseServo.attach(9);
  armServo.attach(10);
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

Serial port;

void setup() {
  size(600, 600);

  printArray(Serial.list());
  port = new Serial(this, Serial.list()[3], 9600);
}

void draw() {
  background(30);

  // Map mouse position to servo angles (0–180)
  int baseAngle = (int) map(mouseX, 0, width, 0, 180);
  int armAngle = (int) map(mouseY, 0, height, 0, 180);

  baseAngle = constrain(baseAngle, 0, 180);
  armAngle = constrain(armAngle, 0, 180);

  // Send both angles to the Arduino
  port.write(baseAngle);
  port.write(armAngle);

  // Draw a crosshair to show the mouse position
  stroke(255, 150, 0);
  strokeWeight(2);
  line(mouseX, 0, mouseX, height);
  line(0, mouseY, width, mouseY);

  // Display angles
  fill(255);
  noStroke();
  textSize(16);
  text("Base: " + baseAngle + "°", 10, 30);
  text("Arm: " + armAngle + "°", 10, 55);
}
```

### Running It

1.  Upload the Arduino code.
2.  Close the Serial Monitor.
3.  Run the Processing sketch.
4.  Move your mouse around the window. The robot arm should follow: left/right controls the base, up/down controls the arm.

---

## Part 2: Final Project Brainstorm

Take a few minutes to think about what you'd like to build for your final project. It can use anything we've covered so far: LEDs, buttons, sensors, sound, motors, serial communication, Processing, or anything else you want to learn. It doesn't have to be fully formed yet, just a direction.

We'll go around the room and everyone will share:

- What are you thinking about building?
- What parts of the course are you most excited to use?
- Is there anything you'd need to learn that we haven't covered yet?

This is informal. Half-baked ideas are welcome. The point is to start thinking out loud so we can help each other figure things out.
