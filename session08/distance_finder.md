# Project: Scanning Distance Finder

This project combines a potentiometer, a servo motor, and an ultrasonic distance sensor (HC-SR04) to create a manual "radar" or scanning device. You can rotate the sensor using the potentiometer and see the distance to objects in real-time.

## The Concept

1.  **Potentiometer** reads your hand movement.
2.  **Arduino** maps that value to a **Servo Motor**.
3.  The **Ultrasonic Sensor**, mounted on top of the servo, rotates to point where you want.
4.  The distance is sent to the **Serial Monitor** and visualized in **Processing**.

## Components

- 1x Arduino Uno
- 1x Servo Motor (SG90 or similar)
- 1x Ultrasonic Distance Sensor (HC-SR04)
- 1x 10kΩ Potentiometer
- Breadboard and jumper wires
- (Optional) 3D printed mount to attach the sensor to the servo horn

## Wiring

| Component | Pin |
|---|---|
| **Potentiometer** | A0 |
| **Servo Signal** | Pin 9 |
| **HC-SR04 Trig** | Pin 11 |
| **HC-SR04 Echo** | Pin 12 |
| **Power** | 5V and GND |

---

## Arduino Code

Upload this to your Arduino. It handles the movement and the distance calculation.

```cpp
#include <Servo.h>

Servo myServo;
const int potPin = A0;
const int trigPin = 11;
const int echoPin = 12;
const int servoPin = 9;

long duration;
int distance;
int potValue;
int angle;

void setup() {
  myServo.attach(servoPin);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(9600);
}

void loop() {
  // 1. Read Potentiometer and move Servo
  potValue = analogRead(potPin);
  angle = map(potValue, 0, 1023, 0, 180);
  myServo.write(angle);

  // 2. Measure Distance
  // Clear the trigPin
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  // Sets the trigPin on HIGH state for 10 micro seconds
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // Reads the echoPin, returns the sound wave travel time in microseconds
  duration = pulseIn(echoPin, HIGH);

  // Calculating the distance in cm
  distance = duration * 0.034 / 2;

  // 3. Send to Serial (for Processing to read)
  Serial.println(distance);
  
  delay(50); // Small delay for stability
}
```

---

## Arduino Code (Advanced with Filtering)

If your distance values are jumping around or showing "random" large numbers, use this version. It implements a **running average filter** and ignores values that are physically impossible for the sensor (e.g., beyond 400cm).

```cpp
#include <Servo.h>

Servo myServo;
const int potPin = A0;
const int trigPin = 11;
const int echoPin = 12;
const int servoPin = 9;

// Filtering variables
const int numReadings = 10;
int readings[numReadings];      // the readings from the analog input
int readIndex = 0;              // the index of the current reading
long total = 0;                  // the running total
int average = 0;                // the average

void setup() {
  myServo.attach(servoPin);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(9600);
  
  // Initialize all readings to 0
  for (int i = 0; i < numReadings; i++) {
    readings[i] = 0;
  }
}

void loop() {
  // 1. Read Potentiometer and move Servo
  int potValue = analogRead(potPin);
  int angle = map(potValue, 0, 1023, 0, 180);
  myServo.write(angle);

  // 2. Measure Distance
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH);
  int currentDistance = duration * 0.034 / 2;

  // 3. Filter Outliers and Average
  // The HC-SR04 is unreliable beyond 400cm and often returns 0 on fail
  if (currentDistance > 0 && currentDistance < 400) {
    // Subtract the last reading
    total = total - readings[readIndex];
    // Read from the sensor
    readings[readIndex] = currentDistance;
    // Add the reading to the total
    total = total + readings[readIndex];
    // Advance to the next position in the array
    readIndex = readIndex + 1;

    // If we're at the end of the array, wrap around to the beginning
    if (readIndex >= numReadings) {
      readIndex = 0;
    }

    // Calculate the average
    average = total / numReadings;
  }

  // 4. Send to Serial
  Serial.println(average);
  
  delay(30); // Faster update since we are averaging
}
```

---

## Arduino Code (Pro: Interrupt & Timeout Handling)

This is the "bulletproof" version. It solves the three biggest issues:
- **Timeouts:** Prevents the code from "hanging" if no object is detected.
- **Settling Time:** Gives the servo a moment to stop drawing peak current before the sensor fires.
- **Stable Timing:** Uses `unsigned long` for duration to prevent math errors.

```cpp
#include <Servo.h>

Servo myServo;
const int potPin = A0;
const int trigPin = 11;
const int echoPin = 12;
const int servoPin = 9;

void setup() {
  myServo.attach(servoPin);
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  Serial.begin(9600);
}

void loop() {
  // 1. Move the Servo
  int potValue = analogRead(potPin);
  int angle = map(potValue, 0, 1023, 0, 180);
  myServo.write(angle);

  // 2. THE "SETTLING" DELAY
  // Wait 15ms to let the servo finish its micro-movement 
  // and let electrical noise on the power line settle.
  delay(15); 

  // 3. Measure Distance with TIMEOUT
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  // pulseIn(pin, value, timeout) 
  // 25000 microseconds = ~425cm. If no echo, it returns 0 immediately.
  unsigned long duration = pulseIn(echoPin, HIGH, 25000); 

  if (duration > 0) {
    int distance = duration * 0.034 / 2;
    Serial.println(distance);
  } else {
    // Optional: Print a special value or nothing if out of range
    // Serial.println(-1); 
  }
  
  delay(20); 
}
```

## Processing Code

Run this on your computer while the Arduino is plugged in. It creates a visual display of the distance.

```processing
import processing.serial.*;

Serial myPort;
String val;
int distance = 0;

void setup() {
  size(600, 400);
  
  // List all available serial ports
  println(Serial.list());
  
  // IMPORTANT: Change [0] to match the index of your Arduino's port
  // Usually it's the last one in the list on Mac or COMX on Windows
  String portName = Serial.list()[0]; 
  myPort = new Serial(this, portName, 9600);
  
  // Don't generate a serialEvent until you get a newline character
  myPort.bufferUntil('\n');
}

void draw() {
  background(20, 20, 30);
  
  // Draw a simple "Radar" arc or bar
  noStroke();
  fill(0, 255, 100, 150);
  float barWidth = map(distance, 0, 200, 0, width);
  rect(0, height - 100, barWidth, 60);
  
  // Text Display
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(64);
  text(distance + " cm", width/2, height/2);
  
  textSize(20);
  text("Distance Finder", width/2, 50);
  
  // Warning if too close
  if (distance < 10 && distance > 0) {
    fill(255, 0, 0);
    text("TOO CLOSE!", width/2, height/2 + 80);
  }
}

void serialEvent(Serial myPort) {
  // Read the data until the newline
  val = myPort.readStringUntil('\n');
  
  if (val != null) {
    val = trim(val); // Remove whitespace
    distance = int(val); // Convert string to integer
  }
}
```

## Tips for Success

- **Power:** The servo and distance sensor can draw a lot of current. If your Arduino keeps resetting, try powering it from a wall adapter rather than just USB, or use a separate power supply for the servo (don't forget to connect the grounds!).
- **Mounting:** Use blue-tack or a 3D printed bracket to hold the HC-SR04 onto the servo horn. If it's loose, your measurements will be jittery.
- **Port Selection:** In the Processing code, if you get an error saying the port is busy or not found, double check the `Serial.list()` output in the console and adjust the `[0]` index.

## Troubleshooting: Garbled Serial Data

If you see weird characters like `2FRH1Mj` in the Serial Monitor or Processing console, it usually means one of two things:

1.  **Baud Rate Mismatch:** Ensure both your Arduino code (`Serial.begin(9600)`) and your Serial Monitor/Processing code are set to the same speed (**9600**). If they don't match, the data will look like gibberish.
2.  **Electrical Noise:** Servos are "noisy" motors. When they move, they can cause a momentary dip in power that confuses the Arduino's serial communication. 
    - **The Fix:** Add a large capacitor (e.g., 100uF or 1000uF) across the 5V and GND rails on your breadboard to smooth out the power spikes.
    - **Check Wires:** Ensure your GND wires are all connected together (Common Ground) and that no wires are loose. A loose GND wire is the #1 cause of "magic" characters.
