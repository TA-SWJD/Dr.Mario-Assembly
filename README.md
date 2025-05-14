# 🎮 Dr. Mario – Assembly Edition

Welcome to **Dr. Mario**, a retro puzzle game lovingly rebuilt *entirely in MIPS Assembly* for the SATURN platform! Pills drop, viruses hide, and you must match colors to survive. This version not only replicates the classic gameplay but also introduces several enhanced features — all coded low-level, pixel-by-pixel.

---

## 🚀 Features Implemented

### ✅ Milestones
- **Milestone 1:** Capsule generation and rendering
- **Milestone 2:** Capsule movement and rotation
- **Milestone 3:** Collision detection with wall, viruses, and landed capsules
- **Milestone 4 & 5:** Color matching, deletion, gravity-based falling

### 🌟 Easy Features
1. **Gravity:** Capsules fall one row every second
2. **Increasing Speed:** Gravity speeds up as you clear more rows
3. **Game Over & Retry:** Pixel-based "Game Over" screen with an `R` key restart
4. **Sound Effects:** Rotating, dropping, landing, and pause all have sounds
5. **Pause Mode:** Press `P` to pause and resume the game
6. **Next Capsule Preview:** See the upcoming capsule before it drops
7. **Side Panel Art:** Includes pixel art of Dr. Mario and viruses!

### 🔥 Hard Feature
- **Background Music:** Full Dr. Mario “Fever” theme plays in the background *without interfering with gameplay* (implemented with a non-blocking custom loop and syscall 31)

---

## 🕹️ How to Play

### Controls
- `←` / `→` : Move capsule left / right
- `↓` : Speed up the fall
- `Z` / `X` : Rotate capsule
- `P` : Pause / Resume
- `Q` : Quit game
- `R` : Restart after game over

### Objective
Match 4 or more same-colored blocks vertically or horizontally to eliminate viruses. Clear them all to win!

---

## 🖥️ How to Run

To play this game, you'll need to install the [SATURN MIPS emulator](https://github.com/1whatleytay/saturn.git):

Drag drmario.asm into Saturn to run the game
