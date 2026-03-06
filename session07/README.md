# Session 07: Mid-Semester Build Day

Today is yours. You've spent the last six sessions learning the building blocks — LEDs, buttons, sensors, sound, motors, serial communication, and Processing. Now it's time to put them together into something of your own.

## The Plan

This is an open studio session. You can come in with your own project idea, or choose one of the prompts below. The only rule: build something that works by the end of class. It doesn't have to be polished, it has to do something.

## Project Prompts

If you don't have your own idea, pick one of these. Each one is scoped to be achievable in a single session using the components and techniques we've covered so far.

### 1. Electronic Instrument

Using the delay-based square wave technique or the `tone()` function from Session 03, build a playable instrument.

Requirements:
- Uses at least 3 sensors or inputs in any combination. For example:
  - 3 buttons (each plays a different note)
  - 1 button + 2 potentiometers (one for pitch, one for tempo)
  - 1 button + 1 potentiometer + 1 distance sensor (wave your hand to bend the pitch)
  - ...or any other combination you can think of
- Produces sound through a piezo buzzer or speaker
- Each input should have a clear, audible effect on the output

Techniques you'll use: `analogRead()`, `digitalRead()`, `tone()`, `map()`, `delay()` / `delayMicroseconds()`

Stretch goals: Add an LED that reacts to the pitch. Use Processing to visualize the sound in real time.

### 2. Cat Toy

Using motors (servo or DC) and possibly a laser pointer module, build an automated toy for your feline friend (or an imaginary one).

Requirements:
- Uses at least 1 motor (servo or DC) to create movement
- Has some element of unpredictability — a cat loses interest in a pattern it can predict. Consider using `random()` to vary timing, direction, or speed
- Has an on/off switch or button to start and stop the toy

Possible approaches:
- A servo sweeping a laser pointer in random arcs across the floor
- A DC motor spinning a dangling string or feather on an arm
- A servo-mounted laser that responds to a distance sensor (moves away when the cat gets close)

Techniques you'll use: `Servo` library, `analogWrite()` for DC motor speed, `random()`, transistor circuits

Stretch goals: Add a sensor so the toy reacts to the cat. Use a potentiometer to set a "chaos level" that controls how erratic the movement is.

### 3. Reaction Time Game

Build a reflex-testing game: an LED lights up at a random time, and the player has to press a button as fast as possible. The Arduino measures their reaction time and gives feedback.

Requirements:
- Uses at least 3 LEDs (e.g., a countdown sequence or multiple targets)
- Uses at least 1 button for player input
- Measures and displays reaction time over Serial (or on an LCD if you're feeling ambitious)
- Uses a buzzer for audio feedback (a beep on success, a sad tone on timeout)

Possible approaches:
- Classic reflex test: 3 LEDs count down (3... 2... 1...), then a 4th "go" LED lights up at a random delay. Player slams the button. Time is printed to Serial.
- Whack-a-mole: Multiple LEDs light up one at a time in random order. Each has a corresponding button. Hit the right button before the LED moves on.
- Speed round: LEDs light up faster and faster. How long can you keep up?

Techniques you'll use: `digitalRead()`, `digitalWrite()`, `millis()`, `random()`, `tone()`, Serial output

Stretch goals: Add a Processing sketch that displays a leaderboard. Use a potentiometer to set the difficulty. Add a two-player mode.

## Tips for the Day

- Start simple. Get the most basic version working first, then add features.
- Test as you go. Wire one component, write the code for it, and verify it works before adding the next.
- Use Serial.println() liberally. It's your best debugging tool. Print sensor values, variable states, anything that helps you understand what's happening.
- Ask for help. That's what I'm here for.

## Deliverable

A working prototype of your chosen project, demonstrated at the end of class. Be prepared to show what it does and explain one thing you learned or one problem you solved while building it.
