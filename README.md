
# 🧪 Game Polish Checklist

## 🎮 Game Feel
- [x] Add floating text for powerups and bonuses
- [x] Add subtle shake or pop effect when collecting fruit
- [x] Add minor camera shake or flash when dying
- [ ] Add sfx/audio cue for achievements popping

## 🖼️ Visual Polish
- [ ] Add screen glow/vignette during high scores or powerups
- [x] Add juicy particles for fruit collection
- [x] Make achievement notifications animated
- [ ] Add snake animation on idle title screen
- [ ] Enhance cosmetics menu with previews

## 🧭 UI and UX
- [ ] Highlight selected buttons and modes more clearly
- [x] Add a "Back" button to every sub-menu
- [ ] Add hover tooltips or short descriptions for settings
- [ ] Improve cosmetics menu organization (e.g. tabs or filters)

## 🗂️ Systems Polish
- [ ] Add achievements for edge cases (like collecting a fruit at the same time as dying)
- [ ] Add sound/music toggle directly on pause/settings screen
- [ ] Improve save data feedback (e.g. "Saved!" text on exit)
- [x] Ensure achievements persist and can't be earned multiple times erroneously

## 🧠 Accessibility & Settings
- [ ] Add colorblind mode toggle (fruit/obstacle colors?)
- [ ] Allow keyboard rebinding or arrow/WASD toggle
- [x] Add volume sliders instead of just mute toggle

## 🎯 Design & Balance
- [x] Document why fruit value and tail length matter to the game loop
- [x] Prototype fruit streak systems that interact with tail length
- [ ] Evaluate cosmetic unlocks tied to extreme tail milestones

### Tail Rhythm Streaks
- Fruit combos now scale with the snake's body length via Tail Rhythm tiers.
- Longer tails extend the combo window and add extra "Tail Flow" bonus points when streaking.
- Each tier pops celebratory floating text so players understand when their tail powers up.

## 🏁 Final Touches / Launch Polish
- [x] Add game version to main menu
- [ ] Add credits screen (can be simple)
- [x] Add loading screen for transitions with fade
- [ ] Add splash screen or intro logo
- [ ] Add "How to Play" popup or section
- [ ] Final pass for consistent fonts / text sizes
