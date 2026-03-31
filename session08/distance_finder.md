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
