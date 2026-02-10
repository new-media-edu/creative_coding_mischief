# Session 01: Introduction to Arduino

1. Introductions

2. Course overview

3. What is GitHub?

4. Hands-on with Arduino
    + Overview
    + Basic wiring and electronics
    + Basic programming: flow, variables, constants, comments, etc.

## Arduino and Electronics

What is electricity?

<div align="center">
  <figure>
    <img src="electricity.png" alt="How electricity flows in circuits" width="600">
    <figcaption><i>How electricity flows in circuits</i></figcaption>
  </figure>
</div>

What is Arduino?

<div align="center">
  <figure>
    <img src="arduinos.webp" alt="Different Arduino board models" width="600">
    <figcaption><i>Different Arduino board models</i></figcaption>
  </figure>
</div>

Pins, voltage, power, etc.

## Start with the classic output: blinking an LED

```c
// Example 01: Blinking LED
const int LED = 13;  // LED connected to digital pin 13

void setup() {
  pinMode(LED, OUTPUT);  // sets the digital pin as output
}

void loop() {
  digitalWrite(LED, HIGH);  // turns the LED on
  delay(1000);              // waits for a second
  digitalWrite(LED, LOW);   // turns the LED off
  delay(1000);              // waits for a second
}
```

But wait, pin 13? What about other pins... and what about resistors?

<div align="center">
  <figure>
    <img src="arduino-led-breadboard.jpg" alt="Arduino wired to an LED on a breadboard" width="600">
    <figcaption><i>Arduino wired to an LED on a breadboard</i></figcaption>
  </figure>
</div>

LEDs are greedy. Unlike a resistor or a motor, an LED has almost no internal resistance once it starts conducting. It will try to pull as much current as the power supply can provide until it literally burns itself out. Think of the LED like a water wheel below a waterfall. Too much water will break the wheel, but it still needs enough to activate. A resistor basically "wastes" some of the voltage supplied to the LED circuit by converting it to heat. In short: if we don't use a resistor in series with the LED, the LED will burn out quickly. Fun fact: it does not matter whether the LED is "in front" or "behind" the resistor, it only matters that resistance is introduced into the circuit.

### Experiment

Make some changes to personalize the sketch and learn-by-doing. I learned to program by downloading source code and changing things one at a time until I understood what each part did. Some ideas for this sketch:

+ Change the delay by substituting the number 1000 (technically referred to as a numeric literal) for a variable.
+ Rather than an on/off repeated pattern, how might you make this more complicated? (Bonus: [Random function](https://docs.arduino.cc/language-reference/en/functions/random-numbers/random/))
+ Make the sketch blink 2 or 3 LEDs


## Classic input: button

<div align="center">
  <figure>
    <img src="button.png" alt="Push button component" width="600">
    <figcaption><i>Push button component</i></figcaption>
  </figure>
</div>

The Floating State

A digital input pin on an Arduino is extremely sensitive. It acts like a tiny antenna.

+ If you connect a pin to 5V, it reads HIGH.

+ If you connect it to GND, it reads LOW.

+ If you connect it to nothing (an open switch), it is "Floating."

In a floating state, the pin will pick up electromagnetic interference from the air, nearby wires, or even your hand. The Arduino will rapidly flip between 0 and 1 randomly. A resistor is used to "tie" the pin to a known state when the button is not pressed.

### Using an External Pull-Down Resistor

<div align="center">
  <figure>
    <img src="button-arduino-pulldown.png" alt="Button circuit with external pull-down resistor" width="600">
    <figcaption><i>Button circuit with external pull-down resistor</i></figcaption>
  </figure>
</div>

This is the most intuitive way to wire a button for beginners: the button "pulses" the signal to HIGH when pressed.
The Wiring

+ Connect one side of the button to 5V.

+ Connect the other side of the button to your Digital Pin (e.g., Pin 2).

+ Connect a 10kΩ resistor from that same Digital Pin to GND.

How it Works

+ Button Open (Not Pressed): The Digital Pin is connected to GND through the resistor. The resistor "pulls" the voltage down to 0V. The Arduino reads LOW.

+ Button Closed (Pressed): There is now a direct, low-resistance path from 5V to the Digital Pin. The 5V "overpowers" the GND connection. The Arduino reads HIGH.

```c
const int BUTTON = 2;  // button connected to digital pin 2
const int LED = 13;    // LED connected to digital pin 13

void setup() {
  pinMode(BUTTON, INPUT);   // set button pin as input
  pinMode(LED, OUTPUT);     // set LED pin as output
}

void loop() {
  int buttonState = digitalRead(BUTTON);  // read button state
  
  if (buttonState == HIGH) {  // button pressed (pulled HIGH by 5V)
    digitalWrite(LED, HIGH);   // turn LED on
  } else {                     // button not pressed
    digitalWrite(LED, LOW);    // turn LED off
  }
}
```

### Using an Internal Pull-Up Resistor

<div align="center">
  <figure>
    <img src="button-arduino-pullup.png" alt="Button circuit with internal pull-up resistor" width="600">
    <figcaption><i>Button circuit with internal pull-up resistor</i></figcaption>
  </figure>
</div>

This method uses the Arduino's built-in pull-up resistor, eliminating the need for an external resistor. The button "pulls" the signal to LOW when pressed.

The Wiring

+ Connect one side of the button to your Digital Pin (e.g., Pin 2).

+ Connect the other side of the button to GND.

+ Enable the internal pull-up in your code using `pinMode(PIN, INPUT_PULLUP);`.

How it Works

+ Button Open (Not Pressed): The internal pull-up resistor "pulls" the voltage up to 5V. The Arduino reads HIGH.

+ Button Closed (Pressed): There is now a direct, low-resistance path from the Digital Pin to GND. The connection to ground has no resistance, making it the path the electricity travels through. The Arduino reads LOW.

```c
const int BUTTON = 2;  // button connected to digital pin 2
const int LED = 13;    // LED connected to digital pin 13

void setup() {
  pinMode(BUTTON, INPUT_PULLUP);  // set button pin with internal pull-up
  pinMode(LED, OUTPUT);           // set LED pin as output
}

void loop() {
  int buttonState = digitalRead(BUTTON);  // read button state
  
  if (buttonState == LOW) {   // button pressed (pulled LOW by GND)
    digitalWrite(LED, HIGH);   // turn LED on
  } else {                    // button not pressed
    digitalWrite(LED, LOW);   // turn LED off
  }
}
```

## Serial Communication

<div align="center">
  <figure>
    <img src="arduino-serial.webp" alt="Serial communication between Arduino and computer" width="600">
    <figcaption><i>Serial communication between Arduino and computer</i></figcaption>
  </figure>
</div>

```c
void setup()                      // run once, when the sketch starts
{
    Serial.begin(9600);           // set up Serial library at 9600 bps
}

void loop()                       // run over and over again
{
    Serial.println("Hello world!");  // prints hello with ending line break
    delay(1000);
}
```

### Experiment

+ Try it with print instead of println.

## Links to review this content

[Blink an LED with Arduino](https://docs.arduino.cc/built-in-examples/basics/Blink/)

[Arduino button tutorial with a pulldown resistor](https://docs.arduino.cc/built-in-examples/digital/Button/)

[Arduino button tutorial with a pullup resistor](https://docs.arduino.cc/tutorials/generic/digital-input-pullup/)

[In-depth Serial tutorial from the legendary Lady Ada](https://www.ladyada.net/learn/arduino/lesson4.html)