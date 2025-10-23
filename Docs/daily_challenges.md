# Daily Challenges

This reference outlines every rotating daily challenge, the in-run data each one evaluates, the thresholds required for completion,
and the experience (XP) awarded upon success. Stat keys correspond to `SessionStats` fields unless noted otherwise; custom logic is
spelled out in the completion criteria column.

| Challenge | ID | Tracked metrics | Completion criteria | XP reward |
| --- | --- | --- | --- | --- |
| Combo Crunch | `combo_crunch` | `bestComboStreak` | Reach a best combo streak of **5** fruit within a single run. | 70 XP |
| Floor Explorer | `floor_explorer` | `floorsCleared` | Clear **5** floors before the run ends. | 80 XP |
| Fruit Sampler | `fruit_sampler` | `applesEaten` | Collect **45** fruit in one run. | 70 XP |
| Shield Showoff | `shield_showoff` | `runShieldRockBreaks`, `runShieldSawParries` | Break rocks and parry saws a combined total of **6** times in a single attempt. | 95 XP |
| Combo Conductor | `combo_conductor` | `combosTriggered` | Trigger **8** combos during a run. | 60 XP |
| Shield Specialist | `shield_specialist` | `shieldsSaved` | Trigger emergency shields **3** times in one session. | 80 XP |
| Balanced Banquet | `balanced_banquet` | `applesEaten`, `combosTriggered` | After each block of **15** fruit collected, trigger a combo; complete **3** such "combo feasts" (requires ≥45 fruit and ≥3 combos). | 110 XP |
| Serpentine Marathon | `serpentine_marathon` | `tilesTravelled` | Travel **3,000** tiles in a single run. | 70 XP |
| Shield Wall Master | `shield_wall_master` | `runShieldWallBounces` | Perform **5** shield wall bounces in a single run. | 80 XP |
| Rock Breaker | `rock_breaker` | `runShieldRockBreaks` | Break **4** rocks with the shield in one outing. | 80 XP |
| Saw Parry Ace | `saw_parry_ace` | `runShieldSawParries` | Parry **2** saws with the shield during a run. | 90 XP |
| Time Keeper | `time_keeper` | `timeAlive` | Stay alive for **600 seconds** (10 minutes) or longer in one attempt. | 90 XP |
| Floor Tourist | `floor_tourist` | `totalFloorTime` | Spend **480 seconds** (8 minutes) exploring floors across one run. | 85 XP |
| Floor Conqueror | `floor_conqueror` | `floorsCleared` | Defeat **8** floors before the run ends. | 100 XP |
| Depth Delver | `depth_delver` | `deepestFloorReached` | Reach floor **10** within a single run. | 110 XP |
| Apple Hoarder | `apple_hoarder` | `applesEaten` | Consume **70** apples in one run. | 90 XP |
| Streak Perfectionist | `streak_perfectionist` | `fruitWithoutTurning` | Collect **12** fruit consecutively without turning. | 90 XP |
| Dragonfruit Gourmand | `dragonfruit_gourmand` | `dragonfruitEaten` | Eat **3** dragonfruit in one session. | 100 XP |
| Shield Triathlon | `shield_triathlon` | `runShieldWallBounces`, `runShieldRockBreaks`, `runShieldSawParries` | Perform at least one of each shield action (wall bounce, rock break, saw parry); completing all three awards progress **3**/3. | 120 XP |
| Floor Speedrunner | `floor_speedrunner` | `fastestFloorClear` | Finish any floor in **45 seconds** or less (tracking stores the best time per run). | 110 XP |
| Pace Setter | `pace_setter` | `tilesTravelled`, `timeAlive` | Maintain an average pace of **240 tiles per minute** across the run (⌊tiles ÷ time_alive⌋ × 60). | 105 XP |
| Combo Harvester | `combo_harvester` | `applesEaten`, `combosTriggered` | Bank fruit in sets of **8** before bursting into combos; achieve **4** harvests (min(floor(apples/8), combos) ≥ 4). | 95 XP |
| Shielded Marathon | `shielded_marathon` | `shieldsSaved`, `tilesTravelled` | Meet both conditions: trigger **2** emergency shields and travel **320** tiles in a single run. | 115 XP |
| Fruit Rush | `fruit_rush` | `applesEaten`, `timeAlive` | Maintain a fruit collection rate of **16 per minute** (⌊apples ÷ time_alive⌋ × 60). | 100 XP |
| Combo Courier | `combo_courier` | `combosTriggered`, `floorsCleared` | Trigger **5** combos while also clearing **4** floors in the same run. | 125 XP |
| Combo Dash | `combo_dash` | `combosTriggered`, `timeAlive` | Trigger **6** combos and finish the run within **360 seconds** (6 minutes). | 130 XP |
| Depth Sprinter | `depth_sprinter` | `floorsCleared`, `timeAlive` | Reach floor **6** within **420 seconds** (7 minutes). | 130 XP |
| Momentum Master | `momentum_master` | `fruitWithoutTurning`, `tilesTravelled` | Achieve **3** momentum surges: each surge demands **8** fruit collected without turning and **1,000** tiles travelled (min(floor(chain/8), floor(tiles/1000)) ≥ 3). | 110 XP |
| Floor Cartographer | `floor_cartographer` | `floorsCleared`, `totalFloorTime` | Visit **4** floors while spending at least **180 seconds** (3 minutes) on each (min(floorsCleared, floor(totalFloorTime/180)) ≥ 4). | 100 XP |
| Safety Dance | `safety_dance` | `runShieldWallBounces`, `runShieldSawParries` | Complete **3** defensive pairs, each comprising **2** wall bounces and **2** saw parries (min(floor(bounces/2), floor(saws/2)) ≥ 3). | 110 XP |

Each challenge aligns with the localisation strings shown in the in-game menu, ensuring the titles and descriptions here match what players see daily.
