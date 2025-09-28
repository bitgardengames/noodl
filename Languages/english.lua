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
