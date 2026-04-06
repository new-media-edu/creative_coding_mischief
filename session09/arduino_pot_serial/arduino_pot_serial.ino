/**
 * Arduino Potentiometer Serial Output
 * 
 * Reads a potentiometer on analog pin A0 and sends the value (0-1023)
 * to the Serial port.
 */

const int potPin = A0;

void setup() {
  Serial.begin(9600);
}

void loop() {
  int val = analogRead(potPin);
  Serial.println(val);
  delay(20); // ~50fps
}
