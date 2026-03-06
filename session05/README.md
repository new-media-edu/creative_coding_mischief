# Session 05: Sensors, Motors, and Introduction to Processing

In this session, we move beyond knobs and buttons into sensing the world and moving things in it. We'll start with a showcase of sensors that feel like magic — detecting magnets and measuring distance through thin air — then we'll learn to control servo motors and DC motors to build a funky robot arm. In the second half, we'll switch gears and meet Processing, a creative coding environment that will let us connect the Arduino to visuals on a computer screen in Session 06.

## Agenda

+ Sensor showcase: Hall effect sensors and ultrasonic distance sensors
+ Introduction to servo motors and the `Servo` library
+ Controlling a servo with a potentiometer
+ Introduction to DC motors and transistor-based speed control
+ Project: Building a 2-DOF robot arm
+ Introduction to Processing: installation and first sketch

---

## Part 1: Sensor Showcase

So far, we've read inputs from buttons (digital — on/off) and potentiometers (analog — a range of values). But these require someone to physically touch them. What if we want the Arduino to sense the world on its own — detecting objects, magnets, light, temperature, or motion?

That's what sensors are for. A sensor converts some physical phenomenon into an electrical signal the Arduino can read. Most sensors work with the same `digitalRead()` and `analogRead()` functions we already know. The only difference is what's being measured.

Let's look at two fun ones.

---

### Hall Effect Sensor (Detecting Magnets)

A hall effect sensor detects the presence and strength of a magnetic field. Wave a magnet near it and the output changes. There are two common types:

*   Digital hall sensor (e.g., A3144, KY-003 module): Acts like a magnetic switch — outputs HIGH or LOW depending on whether a magnet is nearby. Reads with `digitalRead()`, just like a button.
*   Analog hall sensor (e.g., A1302, 49E): Outputs a voltage proportional to the magnetic field strength. Reads with `analogRead()`, just like a potentiometer.

These are used everywhere: bicycle speedometers, phone flip cases that auto-lock, security systems, and detecting whether a door is open or closed.

#### Circuit: Digital Hall Sensor

Most hall sensor modules (like the KY-003) have three pins:

1.  VCC → 5V
2.  GND → GND
3.  Signal → Pin 2

> Some modules have a built-in pull-up resistor. If you're using a bare A3144 sensor, you'll need a 10kΩ pull-up resistor between the signal pin and 5V.

#### Code: Magnetic Switch

```cpp
int HALL_PIN = 2;
int LED_PIN = 13;  // Built-in LED

void setup() {
  pinMode(HALL_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  int magnetDetected = digitalRead(HALL_PIN);

  if (magnetDetected == LOW) {  // Most digital hall sensors go LOW when a magnet is near
    digitalWrite(LED_PIN, HIGH);
    Serial.println("MAGNET DETECTED!");
  } else {
    digitalWrite(LED_PIN, LOW);
    Serial.println("No magnet.");
  }

  delay(100);
}
```

*Wave a magnet near the sensor and watch the LED light up. Try flipping the magnet — most hall sensors only respond to one magnetic pole (south). This is how "smart" phone cases know when they're closed.*

---

### Ultrasonic Distance Sensor (HC-SR04)

The HC-SR04 is an ultrasonic rangefinder — it works like a bat's echolocation. It sends out a burst of high-frequency sound (way above human hearing), waits for the echo to bounce back, and measures how long it took. From that time, we can calculate the distance to whatever object reflected the sound.

It can measure distances from about 2 cm to 400 cm (roughly 1 inch to 13 feet).

#### How It Works

1.  Arduino sends a short pulse on the Trigger pin.
2.  The sensor emits an ultrasonic burst.
3.  The sound bounces off an object and returns.
4.  The sensor sets the Echo pin HIGH for the duration of the round trip.
5.  We measure that duration with `pulseIn()` and convert it to centimeters.

#### Circuit

The HC-SR04 has four pins:

1.  VCC → 5V
2.  GND → GND
3.  Trig → Pin 7
4.  Echo → Pin 8

#### Code: Distance Measurement

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

*Point the sensor at a wall or your hand and watch the distance change in the Serial Monitor. Move your hand closer and farther away — it's oddly satisfying.*

---

### Example: Distance-Controlled LED Brightness

Let's combine the distance sensor with an LED to make something interactive. The closer your hand gets, the brighter the LED glows — like a proximity lamp.

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

*Hold your hand over the sensor and move it up and down. The LED responds to your gesture — no touching required. This is the basis of many interactive art installations.*

> Note: We use `constrain(distanceCm, 5, 50)` to clamp the distance value before mapping. Without it, readings outside the 5–50 range would produce brightness values outside 0–255, which `analogWrite()` can't handle properly.

---

## Part 2: Servo Motors

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

---

### Example 1: Servo Sweep

The simplest servo example: sweep back and forth from 0° to 180° using a `for` loop. This is the "Hello World" of servo motors.

#### Circuit

1.  Servo:
    *   Red wire → 5V
    *   Brown/Black wire → GND
    *   Orange/Yellow wire → Pin 9

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

---

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

---

## Part 3: DC Motors

A DC motor is the classic spinning motor. Unlike a servo, it doesn't go to a specific angle — it just spins continuously. You control its speed (by varying the voltage) and its direction (by swapping the polarity).

### Why We Need a Transistor

There's a catch: DC motors draw much more current than an Arduino pin can provide. An Arduino pin can output about 20mA, but even a small DC motor can draw 200mA or more. If you connect a motor directly to an Arduino pin, you could damage the Arduino.

The solution is to use a transistor (or MOSFET) as a switch. The Arduino sends a small signal to the transistor, and the transistor acts as a gate that allows a larger current from a separate power source to flow through the motor.

Think of it like a light switch on a wall: your finger uses very little force to flip the switch, but the switch controls a much larger flow of electricity to the ceiling light.

<p>
  <img src="transistor-motor-circuit.png" alt="DC motor with transistor" width="600">
  <br>
  <em>DC motor controlled through a transistor. The Arduino controls the transistor, and the transistor controls the motor.</em>
</p>

### Circuit: DC Motor with a Transistor

We'll use a TIP120 transistor (or similar NPN transistor/MOSFET):

1.  Motor: One wire to the external power supply positive (e.g., a battery pack), the other wire to the collector pin of the transistor.
2.  Transistor (TIP120):
    *   Base → Arduino Pin 9 (through a 1kΩ resistor)
    *   Collector → Motor's negative wire
    *   Emitter → GND
3.  Diode (1N4001): Place across the motor terminals (cathode stripe toward power). This protects against voltage spikes when the motor turns off.
4.  Power: Connect the external power supply's GND to the Arduino's GND (common ground).

> Why a diode? Motors are "inductive loads." When you suddenly cut power, the motor's magnetic field collapses and creates a brief voltage spike that can damage your transistor or Arduino. The diode absorbs this spike. Always use one with motors!

---

### Example 3: Speed Control with PWM

Since the motor is connected to a PWM-capable pin (~), we can use `analogWrite()` to control the speed, just like we used it to fade an LED. The value 0–255 controls how much power reaches the motor.

#### Code

```cpp
int MOTOR_PIN = 9;  // Must be a PWM pin (~)
int POT_PIN = A0;

void setup() {
  pinMode(MOTOR_PIN, OUTPUT);
  Serial.begin(9600);
}

void loop() {
  // 1. Read the potentiometer
  int potValue = analogRead(POT_PIN);

  // 2. Map it to the PWM range (0–255)
  int motorSpeed = map(potValue, 0, 1023, 0, 255);

  // 3. Set the motor speed
  analogWrite(MOTOR_PIN, motorSpeed);

  // 4. Print to Serial Monitor
  Serial.print("Speed: ");
  Serial.println(motorSpeed);

  delay(10);
}
```

*Turn the pot and watch the motor speed up and slow down. Note: most DC motors need a minimum voltage to start spinning, so the motor may not move at very low PWM values.*

---

### Example 4: Motor Ramp-Up with a While Loop

This example uses a `while` loop to gradually ramp the motor up to full speed and then back down — a satisfying kinetic effect, and a review of `while` loops from Session 04.

```cpp
int MOTOR_PIN = 9;

void setup() {
  pinMode(MOTOR_PIN, OUTPUT);
}

void loop() {
  // --- Ramp up ---
  int speed = 0;
  while (speed <= 255) {
    analogWrite(MOTOR_PIN, speed);
    speed = speed + 5;
    delay(30);
  }

  // --- Ramp down ---
  speed = 255;
  while (speed >= 0) {
    analogWrite(MOTOR_PIN, speed);
    speed = speed - 5;
    delay(30);
  }

  delay(500); // Pause before repeating
}
```

---

## Part 4: Project — 2-DOF Robot Arm

Now for the fun part. We'll combine two servos and two potentiometers to build a simple 2 Degrees of Freedom (DOF) robot arm. One servo controls the base rotation, and the other controls the arm's elevation. Each potentiometer controls one servo — so you have full manual control of the arm with your hands.

This is the same principle behind the joystick-controlled arms used in everything from toy cranes to surgical robots.

### Circuit

1.  Servo 1 (Base): Signal → Pin 9, Red → 5V, Brown → GND
2.  Servo 2 (Arm): Signal → Pin 10, Red → 5V, Brown → GND
3.  Potentiometer 1 (Base control): Middle pin → A0, Outer pins → 5V and GND
4.  Potentiometer 2 (Arm control): Middle pin → A1, Outer pins → 5V and GND

> Tip: If two servos are drawing too much current from the Arduino's 5V pin (you'll notice jittering or the Arduino resetting), use an external 5V power source for the servos and connect the grounds together.

### Physical Assembly

You can build the arm structure from:
*   Popsicle sticks or craft sticks — hot-glue them to the servo horns
*   Cardboard — cut simple arm segments and attach with hot glue
*   3D printed parts — if you're feeling ambitious (we'll cover this in Session 07!)

Mount one servo flat on the table (base rotation). Attach the second servo to the horn of the first (so it tilts up and down as the base rotates), and glue a stick or gripper to the second servo's horn.

### Code

```cpp
#include <Servo.h>

// Create two Servo objects — one for each joint.
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

*Build the arm, upload the code, and try to pick up a small object (like a crumpled piece of paper) by coordinating both knobs. It's surprisingly tricky — and surprisingly fun.*

---

## More Project Ideas

Here are some other motor projects to try on your own or for inspiration:

| Project | Motor Type | Description |
|---|---|---|
| Useless Machine | Servo | A box with a switch. Flip it on, and a servo arm reaches out and flips it back off. [Classic example →](https://www.youtube.com/results?search_query=useless+machine+arduino) |
| Zoetrope | DC Motor | A spinning drum with animation frames inside. Control the speed with a pot until the animation "locks in." Pre-cinema magic! |
| Scribble Bot | DC Motor | Tape markers to a cup, attach a DC motor with an offset weight inside. Turn it on and it draws chaotic patterns on paper. |
| Animatronic Eyes | 2 Servos | Mount two servos for X/Y eyeball movement. Build a goofy face around them with craft supplies. Control with pots or a joystick. |
| Laser Cat Toy | Servo | Mount a laser pointer on a servo and sweep it across the floor in random patterns. Add a second servo for 2D movement. |
| Motorized Turntable | DC Motor | A slow-spinning display platform for objects or small sculptures. |

---

## Part 5: Introduction to Processing

Now that we have sensors reading the world and motors acting on it, there's one more piece of the puzzle: what if the Arduino could talk to software on your computer? Imagine your potentiometer controlling a visual on screen, or a mouse click triggering a motor. That's exactly what we'll build in Session 06. But first, let's get familiar with the tool we'll use: Processing.

### What is Processing?

[Processing](https://processing.org/) is a free, open-source programming environment designed for artists and designers. It creates a window on your computer where you can draw shapes, images, and animations with code.

If you've used the Arduino IDE, Processing will feel immediately familiar — the structure is almost identical:

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

*You should see a window with an orange circle and a blue rectangle on a dark background. Not very exciting yet — but notice how similar the code structure is to Arduino.*

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

*Move your mouse around the window. The circle follows. `mouseX` and `mouseY` work like built-in sensor readings — Processing updates them for you every frame, just like `analogRead()` gives you a fresh value every time you call it.*

### The `map()` Function — Same Idea, Same Name

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

*Move the mouse left/right to change the size, up/down to change the color. Same `map()` function you've been using all semester — just a different context.*

### 🏠 Homework: Install Processing and Experiment

Before Session 06, make sure Processing is installed and working on your laptop. Try modifying the examples above:
- Change the colors or shapes.
- Add more shapes that respond to the mouse.
- What happens if you remove the `background(30)` line from `draw()`?

In Session 06, Sarah will show you how to connect Arduino to Processing over serial — so your physical sensors will control on-screen visuals, and your mouse will control motors and LEDs. Bring your Arduino and a USB cable!

---

## Key Concepts Summary

| Concept | What It Does |
|---|---|
| Hall effect sensor | Detects magnetic fields (digital or analog) |
| `pulseIn(pin, HIGH)` | Measures how long a pin stays HIGH (in µs) |
| HC-SR04 | Ultrasonic distance sensor (2–400 cm range) |
| `constrain(val, min, max)` | Clamps a value to a range |
| `#include <Servo.h>` | Loads the Servo library |
| `Servo myServo` | Creates a Servo object |
| `myServo.attach(pin)` | Assigns a pin to the servo |
| `myServo.write(angle)` | Moves servo to an angle (0–180°) |
| `analogWrite(pin, value)` | PWM output (0–255) for speed control |
| Transistor / MOSFET | Lets Arduino control high-current devices like DC motors |
| Flyback diode | Protects circuit from motor voltage spikes |
| Processing | Creative coding environment for drawing visuals with code |
| `setup()` / `draw()` | Processing equivalents of Arduino's `setup()` / `loop()` |
| `mouseX` / `mouseY` | Built-in variables tracking mouse position in Processing |
