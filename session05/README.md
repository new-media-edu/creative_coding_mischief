# Session 05: Sensors, Motors, and Introduction to Processing

In this session, we move beyond knobs and buttons into moving things in the world. We'll learn to control servo motors and DC motors to build a funky robot arm. In the second half, we'll switch gears and meet Processing, a creative coding environment that will let us connect the Arduino to visuals on a computer screen in Session 06.

## Agenda

+ Introduction to servo motors and the `Servo` library
+ Controlling a servo with a potentiometer
+ Project: Building a 2-DOF robot arm
+ Introduction to Processing: installation and first sketch


## Part 1: Servo Motors

A servo motor is a special kind of motor that can be told to move to a specific angle (usually between 0° and 180°). Inside, it has a small DC motor, a set of gears, and a position sensor. You send it a signal, and it moves to that position and holds there. This makes servos perfect for things like robot arms, steering mechanisms, and animatronics.

<p>
  <img src="servo-internals.png" alt="Servo motor internals" width="400">
  <br>
  <em>Inside a servo motor: DC motor, gears, and a position feedback sensor</em>
</p>

### Wiring a Servo

Servo motors have three wires:
*   Red: Power (5V)
*   Brown or Black: Ground (GND)
*   Orange or Yellow: Signal (connects to a digital pin on the Arduino)

> Important: Small hobby servos (like the SG90) can be powered directly from the Arduino's 5V pin for simple experiments. If your servo jitters or the Arduino resets, it means the servo is drawing too much current. In that case, you'll need an external power supply for the servo (just make sure to connect the grounds together).

### The Servo Library

Arduino has a built-in library for controlling servos. To use it, we add `#include <Servo.h>` at the top of our code. This gives us a `Servo` object with two key functions:

*   `myServo.attach(pin)`: Tells the library which pin the servo's signal wire is connected to.
*   `myServo.write(angle)`: Moves the servo to a specific angle (0–180).


### Example 1: Servo Sweep

The simplest servo example: sweep back and forth from 0° to 180° using a `for` loop. This is the "Hello World" of servo motors.

#### Circuit

1.  Servo:
    *   Red wire → 5V
    *   Brown/Black wire → GND
    *   Orange/Yellow wire → Pin 9

<p>
  <img src="simple-servo.png" alt="Simple servo circuit" width="600">
  <br>
  <em><a href="https://www.tinkercad.com/things/5eqLU8GqwsP-servo-basic">Tinkercad Circuit</a></em>
</p>

#### Code

```cpp
#include <Servo.h>

// Create a Servo object to control our servo motor.
Servo myServo;

void setup() {
  // Attach the servo to pin 9.
  myServo.attach(9);
}

void loop() {
  // --- Sweep from 0 to 180 degrees ---
  int angle = 0;
  while (angle <= 180) {
    myServo.write(angle);  // Move to the current angle
    delay(15);             // Wait for the servo to reach the position
    angle = angle + 1;
  }

  // --- Sweep from 180 back to 0 degrees ---
  angle = 180;
  while (angle >= 0) {
    myServo.write(angle);
    delay(15);
    angle = angle - 1;
  }
}
```

*Upload this and watch the servo arm sweep back and forth. Try changing the delay to make it faster or slower.*


### Example 2: Potentiometer-Controlled Servo

Now let's add a potentiometer so you can control the servo's position with a knob. This is exactly the same `analogRead()` → `map()` pattern from Session 04, but instead of controlling pitch, we're controlling an angle.

#### Circuit

1.  Servo: Red → 5V, Brown → GND, Signal → Pin 9
2.  Potentiometer: Outer pins → 5V and GND, Middle pin → A0

#### Code

```cpp
#include <Servo.h>

Servo myServo;

int POT_PIN = A0;

void setup() {
  myServo.attach(9);
  Serial.begin(9600);
}

void loop() {
  // 1. Read the potentiometer value (0–1023)
  int potValue = analogRead(POT_PIN);

  // 2. Map it to the servo's range (0–180 degrees)
  int angle = map(potValue, 0, 1023, 0, 180);

  // 3. Move the servo to that angle
  myServo.write(angle);

  // 4. Print the angle to the Serial Monitor so we can see it
  Serial.print("Angle: ");
  Serial.println(angle);

  delay(15); // Small delay for the servo to catch up
}
```

*Turn the knob slowly and watch the servo follow your hand. This is essentially a manual remote control!*


## Part 2: 2-DOF Robot Arm

Now for the fun part. We'll combine two servos and two potentiometers to build a simple 2 Degrees of Freedom (DOF) robot arm. One servo controls the base rotation, and the other controls the arm's elevation. Each potentiometer controls one servo, so you have full manual control of the arm with your hands.

This is the same principle behind the joystick-controlled arms used in everything from toy cranes to surgical robots.

### Circuit

1.  Servo 1 (Base): Signal → Pin 9, Red → 5V, Brown → GND
2.  Servo 2 (Arm): Signal → Pin 10, Red → 5V, Brown → GND
3.  Potentiometer 1 (Base control): Middle pin → A0, Outer pins → 5V and GND
4.  Potentiometer 2 (Arm control): Middle pin → A1, Outer pins → 5V and GND

> Tip: If two servos are drawing too much current from the Arduino's 5V pin (you'll notice jittering or the Arduino resetting), use an external 5V power source for the servos and connect the grounds together.

### Physical Assembly

You can build the arm structure from:
*   Popsicle sticks or craft sticks. Hot-glue them to the servo horns.
*   Cardboard. Cut simple arm segments and attach with hot glue.
*   3D printed parts, if you're feeling ambitious (we'll cover this in Session 07!).

Mount one servo flat on the table (base rotation). Attach the second servo to the horn of the first (so it tilts up and down as the base rotates), and glue a stick or gripper to the second servo's horn.

### Code

```cpp
#include <Servo.h>

// Create two Servo objects, one for each joint.
Servo baseServo;
Servo armServo;

// Potentiometer pins
int BASE_POT_PIN = A0;
int ARM_POT_PIN  = A1;

void setup() {
  // Attach each servo to its corresponding pin.
  baseServo.attach(9);
  armServo.attach(10);

  Serial.begin(9600);
}

void loop() {
  // --- Read both potentiometers ---
  int basePotValue = analogRead(BASE_POT_PIN);
  int armPotValue  = analogRead(ARM_POT_PIN);

  // --- Map each pot value to an angle (0–180) ---
  int baseAngle = map(basePotValue, 0, 1023, 0, 180);
  int armAngle  = map(armPotValue,  0, 1023, 0, 180);

  // --- Move the servos ---
  baseServo.write(baseAngle);
  armServo.write(armAngle);

  // --- Print the angles for debugging ---
  Serial.print("Base: ");
  Serial.print(baseAngle);
  Serial.print("°  Arm: ");
  Serial.print(armAngle);
  Serial.println("°");

  delay(15);
}
```

*Build the arm, upload the code, and try to pick up a small object (like a crumpled piece of paper) by coordinating both knobs. It's surprisingly tricky, and surprisingly fun.*


## More Project Ideas

Here are some other motor projects to try on your own or for inspiration:

| Project | Description |
|---|---|
| Useless Machine | A box with a switch. Flip it on, and a servo arm reaches out and flips it back off. [Classic example →](https://www.youtube.com/results?search_query=useless+machine+arduino) |
| Animatronic Eyes | Mount two servos for X/Y eyeball movement. Build a goofy face around them with craft supplies. Control with pots or a joystick. |
| Laser Cat Toy | Mount a laser pointer on a servo and sweep it across the floor in random patterns. Add a second servo for 2D movement. |


## Part 3: Introduction to Processing

Now that we have sensors reading the world and motors acting on it, there's one more piece of the puzzle: what if the Arduino could talk to software on your computer? Imagine your potentiometer controlling a visual on screen, or a mouse click triggering a motor. That's exactly what we'll build in Session 06. But first, let's get familiar with the tool we'll use: Processing.

### What is Processing?

[Processing](https://processing.org/) is a free, open-source programming environment designed for artists and designers. It creates a window on your computer where you can draw shapes, images, and animations with code.

If you've used the Arduino IDE, Processing will feel immediately familiar. The structure is almost identical:

| Arduino | Processing |
|---|---|
| `setup()` runs once | `setup()` runs once |
| `loop()` runs forever | `draw()` runs forever (~60 times/sec) |
| `Serial.println()` sends data out | Can receive serial data |
| Talks to hardware | Draws to a screen |

Download and install Processing now: [processing.org/download](https://processing.org/download/)

### Your First Sketch: Drawing Shapes

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

### Making It Interactive: Mouse Input

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

### The `map()` Function

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

### 🏠 Homework: Install Processing and Experiment

Before Session 06, make sure Processing is installed and working on your laptop. Try modifying the examples above:
- Change the colors or shapes.
- Add more shapes that respond to the mouse.
- What happens if you remove the `background(30)` line from `draw()`?

In Session 06, Sarah will show you how to connect Arduino to Processing over serial, so your physical sensors will control on-screen visuals, and your mouse will control motors and LEDs. Bring your Arduino and a USB cable!


## Key Concepts Summary

| Concept | What It Does |
|---|---|
| `pulseIn(pin, HIGH)` | Measures how long a pin stays HIGH (in µs) |
| HC-SR04 | Ultrasonic distance sensor (2–400 cm range) |
| `constrain(val, min, max)` | Clamps a value to a range |
| `#include <Servo.h>` | Loads the Servo library |
| `Servo myServo` | Creates a Servo object |
| `myServo.attach(pin)` | Assigns a pin to the servo |
| `myServo.write(angle)` | Moves servo to an angle (0–180°) |
| Processing | Creative coding environment for drawing visuals with code |
| `setup()` / `draw()` | Processing equivalents of Arduino's `setup()` / `loop()` |
| `mouseX` / `mouseY` | Built-in variables tracking mouse position in Processing |

## Supplemental Videos

These videos from [Rachel de Barros](https://www.youtube.com/@racheldebarroslive) cover topics from this session.

* [Get Started with Ultrasonic Sensors and Arduino](https://www.youtube.com/watch?v=ZqQgxgnH9wg)
* [How to Control a Servo with an Ultrasonic Sensor and Arduino](https://www.youtube.com/watch?v=ybhMIy9LWFg)
* [Control 2 Servos with a Joystick and Arduino](https://www.youtube.com/watch?v=fHxZaHJgW34)
