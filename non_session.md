# Sensor Showcase

So far, we've read inputs from buttons (digital, on/off) and potentiometers (analog, a range of values). But these require someone to physically touch them. What if we want the Arduino to sense the world on its own, detecting objects, light, temperature, or motion?

That's what sensors are for. A sensor converts some physical phenomenon into an electrical signal the Arduino can read. Most sensors work with the same `digitalRead()` and `analogRead()` functions we already know. The only difference is what's being measured.


## Ultrasonic Distance Sensor (HC-SR04)

The HC-SR04 is an ultrasonic rangefinder. It works like a bat's echolocation. It sends out a burst of high-frequency sound (way above human hearing), waits for the echo to bounce back, and measures how long it took. From that time, we can calculate the distance to whatever object reflected the sound.

It can measure distances from about 2 cm to 400 cm (roughly 1 inch to 13 feet).

### How It Works

1.  Arduino sends a short pulse on the Trigger pin.
2.  The sensor emits an ultrasonic burst.
3.  The sound bounces off an object and returns.
4.  The sensor sets the Echo pin HIGH for the duration of the round trip.
5.  We measure that duration with `pulseIn()` and convert it to centimeters.

### Circuit

The HC-SR04 has four pins:

1.  VCC → 5V
2.  GND → GND
3.  Trig → Pin 7
4.  Echo → Pin 8

### Code: Distance Measurement

```cpp
int TRIG_PIN = 7;
int ECHO_PIN = 8;

void setup() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  Serial.begin(9600);
}

void loop() {
  // 1. Send a 10-microsecond pulse to trigger the sensor
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  // 2. Measure how long the echo pin stays HIGH (in microseconds)
  long duration = pulseIn(ECHO_PIN, HIGH);

  // 3. Convert the duration to distance in centimeters.
  // Speed of sound ≈ 343 m/s = 0.0343 cm/µs
  // Distance = (time × speed) / 2   (divided by 2 because it's a round trip)
  float distanceCm = (duration * 0.0343) / 2.0;

  // 4. Print the result
  Serial.print("Distance: ");
  Serial.print(distanceCm);
  Serial.println(" cm");

  delay(100);
}
```

*Point the sensor at a wall or your hand and watch the distance change in the Serial Monitor. Move your hand closer and farther away.*


## Example: Distance-Controlled LED Brightness

Let's combine the distance sensor with an LED to make something interactive. The closer your hand gets, the brighter the LED glows, like a proximity lamp.

Circuit: Same HC-SR04 as above, plus an LED (with 220Ω resistor) on Pin 9 (PWM).

```cpp
int TRIG_PIN = 7;
int ECHO_PIN = 8;
int LED_PIN  = 9;  // PWM pin

void setup() {
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  // --- Measure distance ---
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH);
  float distanceCm = (duration * 0.0343) / 2.0;

  // --- Map distance to LED brightness ---
  // Clamp the range: 5 cm (very close) to 50 cm (arm's length)
  // Close = bright (255), far = dim (0)
  int brightness = map(constrain(distanceCm, 5, 50), 5, 50, 255, 0);

  analogWrite(LED_PIN, brightness);

  Serial.print(distanceCm);
  Serial.print(" cm → brightness: ");
  Serial.println(brightness);

  delay(50);
}
```

*Hold your hand over the sensor and move it up and down. The LED responds to your gesture, no touching required. This is the basis of many interactive art installations.*

> Note: We use `constrain(distanceCm, 5, 50)` to clamp the distance value before mapping. Without it, readings outside the 5–50 range would produce brightness values outside 0–255, which `analogWrite()` can't handle properly.


---

# Introduction to Processing

[Processing](https://processing.org/) is a free, open-source programming environment designed for artists and designers. It creates a window on your computer where you can draw shapes, images, and animations with code.

If you've used the Arduino IDE, Processing will feel immediately familiar. The structure is almost identical:

| Arduino | Processing |
|---|---|
| `setup()` runs once | `setup()` runs once |
| `loop()` runs forever | `draw()` runs forever (~60 times/sec) |
| `Serial.println()` sends data out | Can receive serial data |
| Talks to hardware | Draws to a screen |

Download and install Processing now: [processing.org/download](https://processing.org/download/)

## Your First Sketch: Drawing Shapes

Open Processing (not the Arduino IDE!) and paste this code into a new sketch. Press the Play button to run it.

```java
void setup() {
  size(600, 600);  // Create a 600×600 pixel window
}

void draw() {
  background(30);  // Dark gray background, redrawn every frame

  // Draw an orange circle in the center
  fill(255, 150, 0);  // RGB color: orange
  noStroke();          // No outline
  ellipse(300, 300, 200, 200);  // x, y, width, height

  // Draw a blue rectangle
  fill(100, 200, 255);
  rect(50, 50, 100, 80);  // x, y, width, height
}
```

*You should see a window with an orange circle and a blue rectangle on a dark background. Not very exciting yet, but notice how similar the code structure is to Arduino.*

## Making It Interactive: Mouse Input

Processing can read your mouse and keyboard. Let's make the circle follow the mouse:

```java
void setup() {
  size(600, 600);
}

void draw() {
  background(30);

  // mouseX and mouseY are built-in variables that track the mouse position.
  fill(255, 150, 0);
  noStroke();
  ellipse(mouseX, mouseY, 100, 100);

  // Display the coordinates
  fill(255);
  textSize(16);
  text("X: " + mouseX + "  Y: " + mouseY, 10, 30);
}
```

*Move your mouse around the window. The circle follows. `mouseX` and `mouseY` work like built-in sensor readings. Processing updates them for you every frame, just like `analogRead()` gives you a fresh value every time you call it.*

## The `map()` Function

Processing has a `map()` function that works exactly like Arduino's:

```java
void setup() {
  size(600, 600);
}

void draw() {
  background(30);

  // Map mouse X (0–600) to a circle size (10–400)
  float circleSize = map(mouseX, 0, width, 10, 400);

  // Map mouse Y (0–600) to a color component (0–255)
  float redness = map(mouseY, 0, height, 0, 255);

  fill(redness, 150, 0);
  noStroke();
  ellipse(width / 2, height / 2, circleSize, circleSize);

  fill(255);
  textSize(16);
  text("Size: " + (int) circleSize, 10, 30);
}
```

*Move the mouse left/right to change the size, up/down to change the color. Same `map()` function you've been using all semester, just a different context.*


---

# Processing → Arduino (Mouse Position Controls Servo)

Processing reads the mouse's X position and sends it to the Arduino, which uses it to rotate a servo motor. Move the mouse left → servo goes to 0°. Move right → servo goes to 180°.

## The Plan

```
[ Mouse X ] → map() → myPort.write() → USB cable → Serial.read() → Servo.write()
```

## Arduino Code

The Arduino listens for incoming bytes on the serial port. Each byte is a number from 0–180 representing the desired angle.

Circuit:

1.  Servo: Red → 5V, Brown → GND, Signal → Pin 9

```cpp
#include <Servo.h>

Servo myServo;

void setup() {
  myServo.attach(9);
  Serial.begin(9600);
}

void loop() {
  if (Serial.available() > 0) {
    int angle = Serial.read();
    myServo.write(angle);
  }
}
```

## Processing Code

Processing reads the mouse X position, maps it to 0–180, and sends it to the Arduino as a single byte.

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

  int angle = (int) map(mouseX, 0, width, 0, 180);
  angle = constrain(angle, 0, 180);
  myPort.write(angle);

  stroke(255, 150, 0);
  strokeWeight(4);
  float radians = radians(angle - 90);
  float lineX = width / 2 + cos(radians) * 150;
  float lineY = height / 2 + sin(radians) * 150;
  line(width / 2, height / 2, lineX, lineY);

  fill(255);
  noStroke();
  textSize(16);
  text("Angle: " + angle + "°", 10, 30);
  text("Move mouse left/right", 10, 55);
}
```


---

# Two-Way Communication (Arduino ↔ Processing)

The Arduino sends potentiometer data to Processing and receives servo commands from Processing, all over the same serial connection.

This uses a call-and-response (handshake) protocol:

1.  Arduino sends its sensor data as a line of text.
2.  Processing receives it, updates the visuals, and sends back a servo angle byte.
3.  Arduino receives the byte, moves the servo, and sends the next sensor reading.

## Arduino Code (Two-Way)

Circuit:

1.  Potentiometer: Middle pin → A0, Outer pins → 5V and GND
2.  Servo: Signal → Pin 9, Red → 5V, Brown → GND

```cpp
#include <Servo.h>

Servo myServo;
int POT_PIN = A0;

void setup() {
  myServo.attach(9);
  Serial.begin(9600);
  Serial.println(analogRead(POT_PIN));
}

void loop() {
  if (Serial.available() > 0) {
    int angle = Serial.read();
    myServo.write(angle);

    int potValue = analogRead(POT_PIN);
    Serial.println(potValue);
  }
}
```

## Processing Code (Two-Way)

```java
import processing.serial.*;

Serial myPort;
int circleSize = 0;

void setup() {
  size(600, 600);

  printArray(Serial.list());
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 9600);
  myPort.bufferUntil('\n');
}

void draw() {
  background(30);

  fill(255, 150, 0);
  noStroke();
  ellipse(width / 2, height / 2, circleSize, circleSize);

  int angle = (int) map(mouseX, 0, width, 0, 180);
  angle = constrain(angle, 0, 180);

  stroke(100, 200, 255);
  strokeWeight(3);
  float rad = radians(angle - 90);
  float lx = width / 2 + cos(rad) * 150;
  float ly = height / 2 + sin(rad) * 150;
  line(width / 2, height / 2, lx, ly);

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

    int angle = (int) map(mouseX, 0, width, 0, 180);
    angle = constrain(angle, 0, 180);
    myPort.write(angle);
  }
}
```

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

The Arduino only sends a new reading after it receives a byte from Processing. This keeps them in lockstep and prevents the serial buffer from overflowing.


---

# Arduino ↔ Processing Troubleshooting Guide

| Problem | Likely Cause | Fix |
|---|---|---|
| "Port busy" error in Processing | Arduino Serial Monitor is still open | Close the Serial Monitor |
| No data / circle doesn't move | Wrong serial port selected | Check `printArray(Serial.list())` output and adjust the index |
| Garbled numbers or weird values | Baud rate mismatch | Make sure both sides use `9600` |
| Servo jitters wildly | Processing sending data too fast | Use the handshake approach instead of sending every frame |
| Values are delayed / laggy | Serial buffer filling up | Reduce `delay()` in Arduino code, or use the handshake |
| Processing sketch is blank | Processing can't find the port | Run as administrator, or check USB cable |


---

# Mid-Semester Build Day Project Prompts

## 1. Electronic Instrument

Using the delay-based square wave technique or the `tone()` function, build a playable instrument.

Requirements:
- Uses at least 3 sensors or inputs in any combination
- Produces sound through a piezo buzzer or speaker
- Each input should have a clear, audible effect on the output

## 2. Cat Toy

Using motors (servo or DC) and possibly a laser pointer module, build an automated toy for your feline friend.

Requirements:
- Uses at least 1 motor (servo or DC) to create movement
- Has some element of unpredictability (use `random()`)
- Has an on/off switch or button

## 3. Reaction Time Game

Build a reflex-testing game: an LED lights up at a random time, and the player has to press a button as fast as possible.

Requirements:
- Uses at least 3 LEDs
- Uses at least 1 button for player input
- Measures and displays reaction time over Serial
- Uses a buzzer for audio feedback
