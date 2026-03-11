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
import processing.serial.*;

Serial port;
int circleSize;

void setup() {
  size(600, 600);
  printArray(Serial.list());

  // Change the index to match your Arduino's port
  port = new Serial(this, Serial.list()[3], 9600);
  port.bufferUntil('\n');
}

void draw() {
  background(30);
  fill(255, 150, 0);
  noStroke();
  ellipse(width / 2, height / 2, circleSize, circleSize);
}

void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;

  int v = int(trim(s));
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

1.  Potentiometer 1 (X): Outer pins → 5V and GND, Middle pin → A0
2.  Potentiometer 2 (Y): Outer pins → 5V and GND, Middle pin → A1

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
float penX, penY;

void setup() {
  size(800, 800);
  background(255);

  printArray(Serial.list());
  port = new Serial(this, Serial.list()[3], 9600);
  port.bufferUntil('\n');
}

void draw() {
  // Drawing happens in serialEvent, not here.
  // We leave draw() mostly empty so the background doesn't get cleared.
}

void serialEvent(Serial p) {
  String s = p.readStringUntil('\n');
  if (s == null) return;
  s = trim(s);

  // Split the comma-separated values
  String[] values = split(s, ',');
  if (values.length < 2) return;

  float newX = map(int(values[0]), 0, 1023, 0, width);
  float newY = map(int(values[1]), 0, 1023, 0, height);

  // Draw a line from the previous position to the new one
  stroke(0);
  strokeWeight(3);
  line(penX, penY, newX, newY);

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

  // Check for the clear command
  if (s.equals("CLEAR")) {
    background(255);
    return;
  }

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
