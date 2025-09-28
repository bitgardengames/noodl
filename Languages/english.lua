local english = {
    name = "English",
    strings = {
        common = {
            back = "Back",
            back_to_menu = "Back to Menu",
            on = "On",
            off = "Off",
            unknown = "???",
            yes = "Yes",
            no = "No",
        },
        menu = {
            start_game = "Start Game",
            settings = "Settings",
            achievements = "Achievements",
            quit = "Quit",
            version = "v1.0.0",
            title_word = "noodl",
        },
        settings = {
            title = "Settings",
            toggle_fullscreen = "Toggle Fullscreen",
            toggle_music = "Toggle Music",
            toggle_sfx = "Toggle Sound FX",
            music_volume = "Music Volume",
            sfx_volume = "SFX Volume",
            language = "Language",
            back = "Back",
        },
        modeselect = {
            title = "Select Game Mode",
            locked_prefix = "Locked — ${description}",
            back_to_menu = "Back to Menu",
            high_score = "High Score: ${score}",
        },
        achievements = {
            title = "Achievements",
            back_to_menu = "Back to Menu",
            popup_heading = "${title} Unlocked!",
            popup_message = "${title}: ${description}",
            categories = {
                progress = "Milestones",
                depth = "Descent",
                skill = "Skill",
                collection = "Collection",
            },
            progress = {
                label = "${current}/${goal}",
                unlocked = "Completed",
            },
        },
        pause = {
            title = "Paused",
            resume = "Resume",
            toggle_music = "Music: ${state}",
            toggle_sfx = "Sound FX: ${state}",
            quit = "Quit to Menu",
        },
        gameover = {
            title = "Game Over",
            final_score = "Final Score: ${score}",
            high_score = "High Score: ${score}",
            apples_eaten = "Apples Eaten: ${count}",
            default_message = "You died.",
            run_summary_title = "Run Summary",
            high_score_badge = "New Personal Best!",
            mode_label = "Mode: ${mode}",
            total_apples_collected = "Lifetime Apples: ${count}",
            fruit_summary_title = "Meta Fruit Spoils",
            no_fruit_summary = "No meta fruit collected this run.",
            fruit_chip = "${label}: +${gained} (Total ${total})",
            achievements_header = "Achievements Earned",
            no_achievements = "No achievements unlocked this run.",
            tip_prefix = "Tip: ${tip}",
            play_again = "Play Again",
            quit_to_menu = "Quit to Menu",
            deaths = {
                self = {
                    "You bit yourself. Ouch.",
                    "Snake vs. Snake: Snake wins.",
                    "Ever heard of personal space?",
                    "Cannibalism? Bold choice.",
                    "Your tail says hi… a little too close.",
                    "Snake made a knot it couldn’t untie.",
                    "Congratulations, you played yourself.",
                    "Snake practiced yoga… permanently.",
                },
                wall = {
                    "Splat! Right into the wall.",
                    "The wall was stronger.",
                    "Note to self: bricks don’t move.",
                    "Snake discovered geometry… fatally.",
                    "That’s not an exit.",
                    "Turns out walls don’t taste like apples.",
                    "Ever heard of brakes?",
                    "Snake tried parkour. Failed.",
                },
                rock = {
                    "That rock didn’t budge.",
                    "Oof. Rocks are hard.",
                    "Who put that there?!",
                    "Snake tested rock durability. Confirmed.",
                    "Rock 1 – Snake 0.",
                    "Snake’s greatest enemy: landscaping.",
                    "New diet: minerals.",
                    "You’ve unlocked Rock Appreciation 101.",
                    "Rock solid. Snake squishy.",
                },
                saw = {
                    "That wasn’t a salad spinner.",
                    "Just rub some dirt on it.",
                    "OSHA has entered the chat.",
                    "Snake auditioned for a horror movie.",
                },
                flame = {
                    "Snake got toasted by a searing flame jet.",
                    "Those vents breathe fire—give them space.",
                    "A molten wake isn't a good place to swim.",
                    "The floor decided to exhale… loudly.",
                },
                unknown = {
                    "Mysterious demise...",
                    "The void has claimed you.",
                    "Well, that’s one way to end it.",
                    "Snake blinked out of existence.",
                    "Cosmic forces intervened.",
                    "Snake entered the glitch dimension.",
                },
            },
            tips = {
                "Corner the apple, not yourself.",
                "Leave a runway before you sprint for snacks.",
                "Snaking along the walls can buy you breathing room.",
                "Give future-you an exit before taking a risky bite.",
                "Short hops beat long loops when the board gets crowded.",
                "A quick zigzag can reset your rhythm before doubling back.",
            },
        },
        game = {
            floor_traits = {
                section_title = "Floor Traits",
                default_title = "Traits",
                more_modifiers_one = "+${count} more modifier",
                more_modifiers_other = "+${count} more modifiers",
            },
        },
        gamemodes = {
            unlock_popup = "${mode} Unlocked!",
            classic = {
                label = "Classic",
                description = "Traditional Snake — steady pace, no pressure.",
            },
            hardcore = {
                label = "Hardcore",
                description = "Faster speed, tighter reflexes required.",
                unlock_description = "Score 25 in Classic mode.",
            },
            timed = {
                label = "Timed",
                description = "60 seconds. Eat as many apples as you can.",
                unlock_description = "Eat 50 apples total.",
                timer_label = "Time: ${seconds}",
            },
            daily = {
                label = "Daily Challenge",
                description = "A new challenge each day — random effects, one shot.",
            },
        },
        upgrades = {
            rarities = {
                common = "Common",
                uncommon = "Uncommon",
                rare = "Rare",
                epic = "Epic",
                legendary = "Legendary",
            },
            momentum_label = "Momentum",
            quick_fangs = {
                name = "Quick Fangs",
                description = "Snake moves 10% faster.",
                combo_celebration = "Fang Rush",
            },
            stone_skin = {
                name = "Stone Skin",
                description = "Gain a crash shield that shatters rocks and shrugs off a saw clip.",
                shield_text = "Stone Skin!",
            },
            aegis_recycler = {
                name = "Aegis Recycler",
                description = "Every 2 broken shields forge a fresh one.",
                reforged = "Aegis Reforged",
            },
            saw_grease = {
                name = "Saw Grease",
                description = "Saws move 20% slower.",
            },
            hydraulic_tracks = {
                name = "Hydraulic Tracks",
                description = "Fruit retracts saws for 0.5s (+0.5s per stack).",
            },
            extra_bite = {
                name = "Extra Bite",
                description = "Exit unlocks one fruit earlier.",
                celebration = "Early Exit",
            },
            metronome_totem = {
                name = "Metronome Totem",
                description = "Fruit adds +0.35s to the combo timer.",
                timer_bonus = "+0.35s",
            },
            adrenaline_surge = {
                name = "Adrenaline Surge",
                description = "Snake gains a burst of speed after eating fruit.",
                adrenaline_shout = "Adrenaline!",
            },
            stone_whisperer = {
                name = "Stone Whisperer",
                description = "Rocks appear far less often after you snack.",
            },
            tail_trainer = {
                name = "Tail Trainer",
                description = "Gain an extra segment each time you grow and move 4% faster.",
            },
            pocket_springs = {
                name = "Pocket Springs",
                description = "Every 8 fruits forge a crash shield charge.",
            },
            mapmakers_compass = {
                name = "Mapmaker's Compass",
                description = "Exit unlocks one fruit earlier but rocks spawn 15% more often.",
            },
            linked_hydraulics = {
                name = "Linked Hydraulics",
                description = "Hydraulic Tracks gain +1.5s sink time per stack and +0.5s per second of saw stall.",
            },
            twilight_parade = {
                name = "Twilight Parade",
                description = "Fruit at 4+ combo grant +2 bonus score and stall saws 0.8s.",
                combo_bonus = "Twilight Parade +2",
            },
            lucky_bite = {
                name = "Lucky Bite",
                description = "+1 score every time you eat fruit.",
            },
            momentum_memory = {
                name = "Momentum Memory",
                description = "Adrenaline bursts last 2 seconds longer.",
            },
            molting_reflex = {
                name = "Molting Reflex",
                description = "Crash shields trigger a 60% adrenaline surge.",
            },
            circuit_breaker = {
                name = "Circuit Breaker",
                description = "Saw tracks freeze for 1s after each fruit.",
            },
            stonebreaker_hymn = {
                name = "Stonebreaker Hymn",
                description = "Every other fruit shatters the nearest rock. Stacks to every fruit.",
            },
            echo_aegis = {
                name = "Echo Aegis",
                description = "Crash shields unleash a shockwave that stalls saws.",
            },
            resonant_shell = {
                name = "Resonant Shell",
                description = "Gain +0.35s saw stall for every Defense upgrade you've taken.",
            },
            wardens_chorus = {
                name = "Warden's Chorus",
                description = "Floor starts build crash shield progress from each Defense upgrade.",
            },
            gilded_trail = {
                name = "Gilded Trail",
                description = "Every 5th fruit grants +3 bonus score.",
                combo_bonus = "Gilded Trail +3",
            },
            momentum_cache = {
                name = "Momentum Cache",
                description = "Combo finishers grant +1 bonus per link but saws move 5% faster.",
            },
            aurora_band = {
                name = "Aurora Band",
                description = "Combo window +0.35s but exit needs +1 fruit.",
            },
            caravan_contract = {
                name = "Caravan Contract",
                description = "Shops offer +1 card but an extra rock spawns.",
            },
            fresh_supplies = {
                name = "Fresh Supplies",
                description = "Discard these cards and restock the shop with new ones.",
            },
            stone_census = {
                name = "Stone Census",
                description = "Each Economy upgrade cuts rock spawn chance by 7% (min 20%).",
            },
            guild_ledger = {
                name = "Guild Ledger",
                description = "Each shop slot cuts rock spawn chance by 1.5%.",
            },
            venomous_hunger = {
                name = "Venomous Hunger",
                description = "Combo rewards are 50% stronger but the exit needs +1 fruit.",
            },
            predators_reflex = {
                name = "Predator's Reflex",
                description = "Adrenaline bursts are 25% stronger and trigger at floor start.",
            },
            combo_harmonizer = {
                name = "Combo Harmonizer",
                description = "Combo window extends 0.12s for every Combo upgrade you own.",
            },
            grim_reliquary = {
                name = "Grim Reliquary",
                description = "Begin each floor with +1 crash shield, but saws move 10% faster.",
            },
            relentless_pursuit = {
                name = "Relentless Pursuit",
                description = "Saws gain 15% speed but stall for +1.5s after fruit.",
            },
            ember_engine = {
                name = "Ember Engine",
                description = "First fruit each floor stalls saws for 3s and erupts sparks.",
            },
            tempest_nectar = {
                name = "Tempest Nectar",
                description = "Fruit grant +1 bonus score and stall saws for 0.6s.",
                combo_bonus = "Tempest Nectar +1",
            },
            spectral_harvest = {
                name = "Spectral Harvest",
                description = "Once per floor, echoes collect the next fruit instantly after you do.",
            },
            solar_reservoir = {
                name = "Solar Reservoir",
                description = "First fruit each floor stalls saws 2s and grants +4 bonus score.",
                combo_bonus = "Solar Reservoir +4",
            },
            crystal_cache = {
                name = "Crystal Cache",
                description = "Crash shields burst into motes worth +2 bonus score.",
                combo_bonus = "Crystal Cache +2",
            },
            tectonic_resolve = {
                name = "Tectonic Resolve",
                description = "Rock spawns -15%. Begin each floor with +1 crash shield.",
            },
            titanblood_pact = {
                name = "Titanblood Pact",
                description = "Gain +3 crash shields and saw stall +2s, but grow by +5 and gain +1 extra growth.",
            },
            chronospiral_core = {
                name = "Chronospiral Core",
                description = "Saws slow by 25% and spin 40% slower, combo rewards +60%, but grow by +4 and gain +1 extra growth.",
            },
            phoenix_echo = {
                name = "Phoenix Echo",
                description = "Once per run, a fatal crash rewinds the floor instead of ending the run.",
            },
            event_horizon = {
                name = "Event Horizon",
                description = "Legendary: Colliding with a wall opens a portal that ejects you from the opposite side of the arena.",
            },
        },
        achievements_definitions = {
            sessionStarter = {
                title = "First Steps",
                description = "Start your first run",
            },
            firstApple = {
                title = "Tasty Beginning",
                description = "Eat your first apple",
            },
            appleHoarder = {
                title = "Apple Hoarder",
                description = "Eat 100 total apples",
            },
            appleConqueror = {
                title = "Apple Conqueror",
                description = "Eat 500 total apples",
            },
            appleTycoon = {
                title = "Apple Tycoon",
                description = "Eat 1,000 total apples",
            },
            appleEternal = {
                title = "Endless Appetite",
                description = "Eat 2,500 total apples",
            },
            fullBelly = {
                title = "Full Belly",
                description = "Reach a snake length of 50",
            },
            comboSpark = {
                title = "Combo Spark",
                description = "Chain a combo of 3 fruit",
            },
            comboSurge = {
                title = "Combo Surge",
                description = "Chain a combo of 6 fruit",
            },
            comboInferno = {
                title = "Combo Inferno",
                description = "Chain a combo of 10 fruit",
            },
            scoreChaser = {
                title = "Score Chaser",
                description = "Reach a score of 250",
            },
            fruitFiesta = {
                title = "Fruit Fiesta",
                description = "Eat 25 fruit in a single run",
            },
            floorSprinter = {
                title = "Floor Sprinter",
                description = "Clear 3 floors in a single run",
            },
            scoreLegend = {
                title = "Score Legend",
                description = "Reach a score of 500",
            },
            wallRicochet = {
                title = "Ricochet Routine",
                description = "Bounce off a wall using a crash shield.",
            },
            rockShatter = {
                title = "Stone Sneeze",
                description = "Shatter a rock by face-checking it with a crash shield.",
            },
            sawParry = {
                title = "Saw Whisperer",
                description = "Let a crash shield devour a saw for you.",
            },
            shieldTriad = {
                title = "Crash-Test Maestro",
                description = "In one run, shrug off a wall, rock, and saw with crash shields.",
            },
            dragonHunter = {
                title = "Dragon Hunter",
                description = "Collect the legendary Dragonfruit",
            },
            tokenMenagerie = {
                title = "Token Menagerie",
                description = "Collect four different meta fruit tokens in a single run.",
            },
            floorScout = {
                title = "Depth Scout",
                description = "Reach floor 3",
            },
            floorDiver = {
                title = "Cavern Diver",
                description = "Reach floor 6",
            },
            floorAbyss = {
                title = "Abyss Stalker",
                description = "Reach floor 10",
            },
            floorAscendant = {
                title = "Skyward Survivor",
                description = "Reach floor 14",
            },
            floorTraveler = {
                title = "Seasoned Descent",
                description = "Clear 20 floors total",
            },
            floorVoyager = {
                title = "Underworld Voyager",
                description = "Clear 60 floors total",
            },
            seasonedRunner = {
                title = "Seasoned Runner",
                description = "Play 20 total runs",
            },
        },
    },
}

return english
