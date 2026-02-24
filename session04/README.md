# Session 04: Stateful Changes and Sequences

In the previous session, our code either played one sound continuously or played a short melody once in `setup()`. But what if we want to create dynamic, changing sounds that evolve over time?

This session introduces a powerful concept: **state management**. Instead of using `for` or `while` loops, which can "block" the Arduino's `loop()` function, we will use global variables to keep track of the program's "state." The `loop()` function will run very quickly, and on each pass, it will check these state variables and decide what to do next.

This approach is fundamental to writing responsive, non-blocking Arduino code.

## Key Concepts

*   **Global Variables:** Variables declared outside of any function. They retain their value between runs of the `loop()` function, allowing us to store information over time (e.g., the current pitch, the current note in a melody).
*   **State Machine:** A programming pattern where the code can be in one of several "states." Based on the current state, it does something, and then it might transition to a new state. We will use `if` and `else if` statements to check our state.
*   **Arrays:** A way to store a list of values (like a sequence of musical notes) under a single variable name.

---

### Example: A Dynamic Siren

This example creates a classic siren sound that smoothly rises in pitch, then falls, and repeats. It uses a variable `pitchPeriod` to control the tone and a `sirenMode` variable to keep track of whether the pitch should be rising or falling.

```cpp
// The pin connected to our speaker
const int SPEAKER_PIN = 8;

// This global variable stores the current period of the sound wave in microseconds.
// A smaller number means a higher pitch. We'll start with a low pitch.
int pitchPeriod = 1000;

// This global variable is our "state" for the siren.
// 0 = pitch is rising
// 1 = pitch is falling
int sirenMode = 0; 

void setup() {
  // Set the speaker pin as an output.
  pinMode(SPEAKER_PIN, OUTPUT);
}

void loop() {
  // This check happens thousands of times per second.
  // First, we check which mode the siren is in.
  
  if (sirenMode == 0) {
    // --- RISING PITCH MODE ---
    
    // Decrease the period slightly. This makes the pitch go up.
    pitchPeriod = pitchPeriod - 5; 
    
    // This is a safety check. If the pitch gets too high (period gets too short),
    // we switch to the falling pitch mode.
    if (pitchPeriod <= 200) {
      sirenMode = 1; // Switch to falling mode
    }
    
  } else {
    // --- FALLING PITCH MODE ---
    
    // Increase the period slightly. This makes the pitch go down.
    pitchPeriod = pitchPeriod + 5;
    
    // If the pitch gets low enough (period gets long enough),
    // we switch back to the rising pitch mode to repeat the cycle.
    if (pitchPeriod >= 1000) {
      sirenMode = 0; // Switch to rising mode
    }
  }

  // --- Generate the sound ---
  // After updating the pitchPeriod, we generate one cycle of the sound wave.
  // Because the loop repeats so fast, this creates a continuous, changing tone.
  digitalWrite(SPEAKER_PIN, HIGH);
  delayMicroseconds(pitchPeriod);
  digitalWrite(SPEAKER_PIN, LOW);
  delayMicroseconds(pitchPeriod);
}
```
---

### Example: A "Techno" Bassline with Arrays

This example plays a sequence of notes stored in an **array**. It uses an index variable (`currentNoteIndex`) to remember which note it should play next. When the sequence is finished, it starts over from the beginning.

This is much more powerful than writing `tone(...)`, `delay(...)` over and over, because you can easily change the melody just by changing the numbers in the array.

```cpp
const int SPEAKER_PIN = 6;

// --- The Melody ---
// An array is a list of values. This array holds the PERIOD of each note in
// microseconds. A smaller number is a higher pitch.
// A value of 0 will represent a "rest" or silence.
int bassline[] = { 900, 0, 900, 0, 700, 0, 900, 0,
                   900, 0, 900, 0, 600, 600, 0, 0 };

// This constant holds the total number of notes in our array.
// The `sizeof` operator is a handy way to calculate this automatically.
const int NOTE_COUNT = sizeof(bassline) / sizeof(int);

// This variable is our state! It's the index that tracks which note we are currently playing.
int currentNoteIndex = 0;

// This variable tracks time. We'll use it to decide when to move to the next note.
unsigned long lastNoteTime = 0;

// This constant defines how long each note should play, in milliseconds.
const int NOTE_DURATION = 150;


void setup() {
  pinMode(SPEAKER_PIN, OUTPUT);
  // Get the time at which the sketch starts.
  lastNoteTime = millis();
}

void loop() {
  // Get the current note's period from the array using our index.
  int notePeriod = bassline[currentNoteIndex];

  // First, check if the current note is a rest.
  if (notePeriod == 0) {
    // If it's a rest, do nothing to the speaker (silence).
    noTone(SPEAKER_PIN);
  } else {
    // If it's a note, generate the tone by rapidly pulsing the speaker.
    // This is the same manual tone generation technique as in the previous examples.
    digitalWrite(SPEAKER_PIN, HIGH);
    delayMicroseconds(notePeriod);
    digitalWrite(SPEAKER_PIN, LOW);
    delayMicroseconds(notePeriod);
  }

  // --- Timekeeping Logic ---
  // This section decides when to advance to the next note in the sequence.
  
  // `millis()` returns the number of milliseconds since the Arduino started.
  // We check if NOTE_DURATION milliseconds have passed since we started playing the current note.
  if (millis() - lastNoteTime > NOTE_DURATION) {
    // If enough time has passed, it's time to move to the next note.
    
    // Move to the next index in the array.
    currentNoteIndex = currentNoteIndex + 1;

    // Check if we've reached the end of the array.
    if (currentNoteIndex >= NOTE_COUNT) {
      // If so, reset the index back to 0 to loop the melody.
      currentNoteIndex = 0; 
    }
    
    // Finally, record the time that this new note started.
    lastNoteTime = millis();
  }
}
```

Try changing the values in the `bassline` array to create your own unique melodies!
