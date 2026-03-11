# Session 06: Arduino → Processing

Today we introduce Processing and use it to visualize data coming from the Arduino. We'll start simple, growing a circle with a potentiometer, then build an Etch A Sketch using two potentiometers to draw on screen.

## Agenda

+ What is Processing?
+ Growing a circle with a potentiometer
+ Etch A Sketch with two potentiometers

---

## What is Processing?

[Processing](https://processing.org/) is a free, open-source programming environment designed for artists and designers. It creates a window on your computer where you can draw shapes, images, and animations with code. Download it here: [processing.org/download](https://processing.org/download/)

If you've used the Arduino IDE, Processing will feel immediately familiar:

| Arduino | Processing |
|---|---|
| `setup()` runs once | `setup()` runs once |
| `loop()` runs forever | `draw()` runs forever (~60 times/sec) |
| `Serial.println()` sends data out | Can receive serial data |
| Talks to hardware | Draws to a screen |

That's all you need to know for now. We'll learn Processing by using it.

---

## Part 1: Growing a Circle (1 Potentiometer)

We'll read a potentiometer on the Arduino and send its value to Processing over the serial port. Processing will use that value to control the size of a circle on screen.

### The Plan

```
[ Potentiometer ] → analogRead() → Serial.println() → USB cable → Processing serial.read() → circle size
```

### The Arduino Code

Read the pot, print the value to Serial. We send one number per line with `Serial.println()`, because Processing will read one line at a time.

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
  Serial.println(potValue);
  delay(50);
}
```

Upload this to your Arduino. You can verify it works by opening the Serial Monitor. You should see numbers from 0 to 1023 streaming by.

> Important: Close the Serial Monitor before running Processing! Only one program can use the serial port at a time.

### The Processing Code

Open Processing (not the Arduino IDE) and paste the following code into a new sketch.

```java
// This line loads the serial library so Processing can talk to the Arduino.
import processing.serial.*;

// A variable to hold our serial connection.
Serial port;

// This will store the circle diameter. It starts at 0.
int circleSize;

void setup() {
  // Create a 600x600 pixel window.
  size(600, 600);

  // Print the list of available serial ports to the console (the black area below the code).
  // Look for the one that matches your Arduino.
  printArray(Serial.list());

  // Open the serial port. The number in the brackets (here [3]) is the
  // position in the list printed above. You may need to change this
  // to [0], [1], [2], etc. depending on your computer.
  port = new Serial(this, Serial.list()[3], 9600);

  // Tell Processing to collect incoming data until it sees a newline character.
  // This matches Arduino's Serial.println(), which adds a newline at the end.
  port.bufferUntil('\n');
}

void draw() {
  // Redraw the background every frame (erases the previous circle).
  background(30);

  // Set the fill color to orange (Red=255, Green=150, Blue=0).
  fill(255, 150, 0);
  noStroke();

  // Draw a circle in the center of the window.
  // "width" and "height" are built-in variables for the window size.
  ellipse(width / 2, height / 2, circleSize, circleSize);
}

// This function runs automatically every time a complete line arrives from Arduino.
void serialEvent(Serial p) {
  // Read the incoming text up to the newline character.
  String s = p.readStringUntil('\n');

  // If nothing arrived, do nothing.
  if (s == null) return;

  // Convert the text to a number. trim() removes any extra whitespace.
  int v = int(trim(s));

  // Map the Arduino's 0-1023 range to a circle size between 10 and 500 pixels.
  // This is the same map() function you've used on the Arduino!
  circleSize = int(map(v, 0, 1023, 10, 500));
}
```

### Running It

1.  Upload the Arduino code to your board.
2.  Close the Arduino Serial Monitor.
3.  Run the Processing sketch (click the Play button).
4.  Turn the potentiometer. The circle on screen should grow and shrink.

> Troubleshooting: "Port busy" or no data?
> - Make sure the Arduino Serial Monitor is closed.
> - Check the console output from `printArray(Serial.list())` and adjust the index if your Arduino isn't the first port listed.
> - Make sure the baud rate matches (9600 on both sides).

---

## Part 2: Etch A Sketch (2 Potentiometers)

Now let's use two potentiometers to draw on screen, like an Etch A Sketch. One pot controls the X position of a pen, the other controls the Y position. As you turn the knobs, the pen leaves a trail.

### The Plan

```
[ Pot 1 (X) ] → analogRead(A0) ─┐
                                 ├→ Serial.println("x,y") → USB → Processing draws a dot
[ Pot 2 (Y) ] → analogRead(A1) ─┘
```

### The Arduino Code

We read both potentiometers and send them as a comma-separated pair on each line.

#### Circuit

We're using the same circuit from Session 05 with two potentiometers and two servos, but today we only need the two potentiometers. If your robot arm is still wired up, that's fine — the servos just won't do anything.

1.  Potentiometer 1 (X): Outer pins → 5V and GND, Middle pin → A0
2.  Potentiometer 2 (Y): Outer pins → 5V and GND, Middle pin → A1

<p>
  <img src="../session05/2pot-2servo.png" alt="2 potentiometer 2 servo circuit" width="600">
  <br>
  <em><a href="https://www.tinkercad.com/things/3q7nDz11QsR-2-potentiometer-2-servo">Tinkercad Circuit</a></em>
</p>

#### Arduino Code

```cpp
int POT_X = A0;
int POT_Y = A1;

void setup() {
  Serial.begin(9600);
}

void loop() {
  int x = analogRead(POT_X);
  int y = analogRead(POT_Y);

  // Send both values separated by a comma
  Serial.print(x);
  Serial.print(",");
  Serial.println(y);

  delay(20);
}
```

### The Processing Code

Processing reads the comma-separated values, maps them to screen coordinates, and draws a small circle at that position. Because we don't clear the background each frame, the dots accumulate into a drawing.

```java
import processing.serial.*;

Serial port;

// These store the pen's current position on screen.
float penX, penY;

void setup() {
  size(800, 800);

  // Start with a white canvas.
  background(255);

  printArray(Serial.list());
  port = new Serial(this, Serial.list()[3], 9600);
  port.bufferUntil('\n');
}

void draw() {
  // We intentionally leave draw() empty.
  // If we called background() here, it would erase our drawing every frame.
  // Instead, all the drawing happens in serialEvent() below.
}

// This runs every time a complete line arrives from the Arduino.
void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  s = trim(s);

  // The Arduino sends something like "512,300".
  // split() chops that string at the comma and gives us the pieces.
  // After this line, values[0] is "512" and values[1] is "300".
  // (An "array" is just a list of things — we access each item by number.)
  String[] values = split(s, ',');

  // Make sure we actually got two values before continuing.
  if (values.length < 2) return;

  // Convert the text values to numbers and map them to screen coordinates.
  // int(values[0]) turns the text "512" into the number 512.
  float newX = map(int(values[0]), 0, 1023, 0, width);
  float newY = map(int(values[1]), 0, 1023, 0, height);

  // Draw a line from where the pen was to where it is now.
  stroke(0);         // Black ink
  strokeWeight(3);   // 3-pixel-wide line
  line(penX, penY, newX, newY);

  // Remember this position for next time.
  penX = newX;
  penY = newY;
}
```

### Running It

1.  Upload the Arduino code.
2.  Close the Serial Monitor.
3.  Run the Processing sketch.
4.  Turn the two potentiometers to draw on screen. One controls left/right, the other controls up/down.

### Bonus: Add a Clear Button

If you're feeling good about things, add a button to clear the screen and start a fresh drawing.

#### Updated Arduino Code

Add a button on pin 2 (with a pull-up resistor, or use `INPUT_PULLUP`). When pressed, send a special message so Processing knows to clear.

```cpp
int POT_X = A0;
int POT_Y = A1;
int BUTTON_PIN = 2;

void setup() {
  Serial.begin(9600);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
}

void loop() {
  // Check if the button is pressed
  if (digitalRead(BUTTON_PIN) == LOW) {
    Serial.println("CLEAR");
    delay(300);  // Simple debounce
    return;
  }

  int x = analogRead(POT_X);
  int y = analogRead(POT_Y);

  Serial.print(x);
  Serial.print(",");
  Serial.println(y);

  delay(20);
}
```

#### Updated Processing Code

Check for the "CLEAR" message and reset the background when it arrives.

```java
import processing.serial.*;

Serial port;
float penX, penY;

void setup() {
  size(800, 800);
  background(255);

  printArray(Serial.list());
  port = new Serial(this, Serial.list()[3], 9600);
  port.bufferUntil('\n');
}

void draw() {
}

void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  s = trim(s);

  // Check if the Arduino sent the word "CLEAR" (meaning the button was pressed).
  // .equals() compares two strings — it returns true if they match exactly.
  if (s.equals("CLEAR")) {
    // Re-paint the entire window white, erasing everything.
    background(255);
    return;  // Skip the rest of this function.
  }

  // Otherwise, it's a normal "x,y" pair. Split and draw as before.
  String[] values = split(s, ',');
  if (values.length < 2) return;

  float newX = map(int(values[0]), 0, 1023, 0, width);
  float newY = map(int(values[1]), 0, 1023, 0, height);

  stroke(0);
  strokeWeight(3);
  line(penX, penY, newX, newY);

  penX = newX;
  penY = newY;
}
```
