# Achievements Overview

This catalog mirrors the authoritative data in [`achievement_definitions.lua`](../achievement_definitions.lua) and
[`snakecosmetics.lua`](../snakecosmetics.lua). It is intended for balance reviews and economic (value) audits, so each
entry specifies the numerical goal, how progress is tracked, hidden status, and any cosmetic unlocks that are awarded.

## Summary

- **Total achievements:** 16
- **Categories:** Progress (3), Depth (0), Skill (11), Collection (2)
- **Cosmetic unlocks:** Orchard Sovereign, Crystalline Mire, Midnight Mechanica, Tidal Resonance (4 total)

## Progress Achievements

| Achievement | Goal | Requirement Detail | Tracking Source | Hidden | Unlocks |
| --- | --- | --- | --- | --- | --- |
| Apple Tycoon | 1,000 apples | Eat 1,000 apples across all runs. | `PlayerStats.totalApplesEaten` | No | Orchard Sovereign snake skin |
| Daily Dabbler | 1 daily challenge | Complete a single daily challenge. | `PlayerStats.dailyChallengesCompleted` | No | — |
| Daily Champion | 30 daily challenges | Complete 30 daily challenges overall. | `PlayerStats.dailyChallengesCompleted` | No | Crystalline Mire snake skin |

## Depth Achievements

No depth achievements are currently defined in `achievement_definitions.lua`.

## Skill Achievements

| Achievement | Goal | Requirement Detail | Tracking Source | Hidden | Unlocks |
| --- | --- | --- | --- | --- | --- |
| Combo Spark | 3 fruit combo | Reach a 3-fruit combo streak (lifetime best). | `PlayerStats.bestComboStreak` | No | — |
| Combo Surge | 6 fruit combo | Reach a 6-fruit combo streak (lifetime best). | `PlayerStats.bestComboStreak` | No | — |
| Combo Inferno | 10 fruit combo | Reach a 10-fruit combo streak (lifetime best). | `PlayerStats.bestComboStreak` | No | Tidal Resonance snake skin |
| Shieldless Wonder* | 3 floors | Clear 3 floors in a single run without consuming a shield. | `SessionStats.runFloorsCleared`, `SessionStats.runShieldsSaved` | Yes | — |
| Dragon Combo Fusion* | 1 run | In the same run, eat at least one dragonfruit and reach an 8-fruit combo streak. | `SessionStats.runDragonfruitEaten`, `SessionStats.runBestComboStreak` | Yes | — |
| Ricochet Routine | 1 wall bounce | Bounce off a wall while shielded (cumulative). | `PlayerStats.shieldWallBounces` | No | — |
| Stone Sneeze | 1 rock break | Break a rock by colliding with it while shielded (cumulative). | `PlayerStats.shieldRockBreaks` | No | — |
| Rock Crusher | 25 rock breaks | Break 25 rocks with shields over time. | `PlayerStats.shieldRockBreaks` | No | Midnight Mechanica snake skin |
| Saw Whisperer | 1 saw parry | Parry a saw blade using a shield (cumulative). | `PlayerStats.shieldSawParries` | No | — |
| Saw Annihilator | 25 saw parries | Parry 25 saw blades with shields over time. | `PlayerStats.shieldSawParries` | No | — |
| Crash-Test Maestro | 3 interactions | In a single run, block at least one wall, rock, and saw with shields. | `SessionStats.runShieldWallBounces`, `SessionStats.runShieldRockBreaks`, `SessionStats.runShieldSawParries` | No | — |

## Collection Achievements

| Achievement | Goal | Requirement Detail | Tracking Source | Hidden | Unlocks |
| --- | --- | --- | --- | --- | --- |
| Dragon Hunter | 1 dragonfruit | Collect a dragonfruit (lifetime). | `PlayerStats.totalDragonfruitEaten` | No | — |
| Dragon Connoisseur | 10 dragonfruit | Collect 10 dragonfruit over time. | `PlayerStats.totalDragonfruitEaten` | No | — |

\*Hidden achievements that only appear after being unlocked.

