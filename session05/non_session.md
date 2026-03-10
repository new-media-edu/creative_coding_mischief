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
