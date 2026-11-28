; Rail Gunner screens for the Commander X16: pages of 40 by 30 text cells.
; The game says which page; what is on it and where is decided here.
%import video_platform
%import scores

screens {
    sub title() {
        video.clear()
        video.caption(3, 2, 3, "RAIL GUNNER")
        if game.menuPage == game.SCORES_MENU {
            video.caption(3, 6, 7, "HIGH SCORES")
            video.caption(3, 8, 15, "LOCAL TOP FIVE")
            video.caption(3, 9, 15, "ALL MODES AND STARTING WAVES")
            video.caption(3, 10, 15, "ALL AMMO AND X SHOT SETTINGS")
            leaderboard(12)
            video.caption(3, 24, 15, "ESC / SELECT  BACK")
            return
        }
        if game.menuPage == game.HELP_MENU {
            video.caption(3, 5, 7, "CONTROLS & CREDITS")
            video.caption(3, 7, 15, "ARROWS / D-PAD  MOVE")
            video.caption(3, 8, 15, "1 UP  GRAVE DOWN  CTRL LEFT  2 RIGHT")
            video.caption(3, 9, 15, "SPACE / B  FIRE")
            video.caption(3, 10, 15, "ENTER / START  PAUSE")
            video.caption(3, 11, 15, "ESC / SELECT  RETURN TO TITLE")
            video.caption(3, 14, 7, "RAIL GUNS FLASH BEFORE FIRING.")
            video.caption(3, 15, 7, "PLANTED PODS BLOCK SHOTS.")
            video.caption(3, 16, 7, "VOLATILE DRONES BLAST NEARBY CELLS.")
            video.caption(3, 17, 7, "YELLOW GHOSTS MARK INCOMING CELLS.")
            video.caption(3, 18, 7, "FLY UNDER CELLULAR DRONES TO FIRE.")
            video.caption(3, 19, 13, "FIVE GREEN PODS CHARGE ONE VOLLEY.")
            video.caption(3, 20, 15, "IT BREAKS ARMOR AND PODS IN ONE HIT.")
            video.caption(3, 21, 15, "AMMO PACKS: FLASHING POD OR + RESERVE")
            video.caption(3, 22, 15, "SHOOT RED XS IN SHOOTABLE MODE.")
            video.caption(3, 23, 3, "MUSIC: PUNCH YOUR WAY THROUGH")
            video.caption(3, 24, 15, "BY NORTHIVANASTAN / CC0 1.0")
            video.caption(3, 27, 15, "ESC / SELECT  BACK")
            return
        }
        video.cell(4, 5, video.SHIP, 1)
        video.cell(8, 5, video.PULSE, 7)
        video.cell(13, 5, video.TRAIN, 3)
        video.cell(17, 5, video.PATROL, 8)
        video.cell(21, 5, video.ARMORED, 2)
        video.cell(27, 5, video.CELL, 13)
        video.cell(32, 5, video.RAIL_POD_SEED, 3)
        ubyte row
        for row in 0 to game.HELP_MENU {
            video.caption(6, 8 + row * 2, 1, menuLabels[row])
        }
        video.caption(3, 26, 15, "UP/DOWN  SELECT   LEFT/RIGHT  CHANGE")
        video.caption(3, 27, 15, "SPACE/B  OPEN     ESC/SELECT  EXIT")
        titleValues()
    }

    ; Pad menu values so changing a choice overwrites the whole previous line.
    str[] menuLabels = ["PLAY", "MODE", "STARTING WAVE", "AMMO", "X SHOTS", "HIGH SCORES", "CONTROLS & CREDITS"]
    str[] modeNames = [
        "CLASSIC    ", "CONWAY LIFE", "HIGHLIFE   ", "RULE 30    ", "RULE 110   "
    ]
    str[] modeHelp = [
        "BUTTERFLY TRAINS SWEEP THE GRID.     ",
        "THREE NEIGHBORS CREATE A CELL.       ",
        "LIFE WITH BIRTHS AT THREE OR SIX.    ",
        "IRREGULAR PATTERNS GROW DOWNWARD.    ",
        "REPEATING PATTERNS GROW DOWNWARD.    "
    ]
    str[] ammoNames = ["UNLIMITED  ", "SLOWDOWN   ", "AUTO-RELOAD", "AMMO PACKS "]
    str[] ammoHelp = [
        "AMMO  FULL SPEED WHILE YOU HOLD FIRE ",
        "AMMO  SLOWS. RELEASE FIRE TO RECOVER ",
        "AMMO  STOPS TO RELOAD. PODS REFILL   ",
        "AMMO  FOLLOW FLASHING PODS TO REFILL "
    ]

    sub titleValues() {
        video.setup()
        ubyte row
        for row in 0 to game.HELP_MENU {
            video.cell(4, 8 + row * 2, 32, 7)
        }
        video.cell(4, 8 + game.menuFocus * 2, video.PULSE, 7)
        video.caption(21, 10, 7, modeNames[game.mode])
        video.caption(3, 22, 15, modeHelp[game.mode])
        video.digits(21, 12, 7, game.selectedWave, 5)
        video.caption(21, 14, 7, ammoNames[game.ammoMode])
        video.caption(3, 23, 15, ammoHelp[game.ammoMode])
        if game.shootableX {
            video.caption(21, 16, 7, "SHOOTABLE  ")
        } else {
            video.caption(21, 16, 7, "UNBREAKABLE")
        }
    }

    sub leaderboard(ubyte row) {
        ubyte i
        for i in 0 to 4 {
            video.cell(4, row, 49 + i, 14)
            video.cell(7, row, nameTile(scores.first[i]), 1)
            video.cell(8, row, nameTile(scores.second[i]), 1)
            video.cell(9, row, nameTile(scores.third[i]), 1)
            video.scoreDigits(13, row, 3, scores.points[i])
            row++
        }
    }

    sub nameTile(ubyte letter) -> ubyte {
        if letter >= 65 and letter <= 90 {
            return letter - 64
        }
        return 32
    }

    ; The labels of the HUD, around a newly drawn arena.
    sub hudLabels() {
        video.caption(1, 1, 14, "SCORE")
        video.caption(16, 1, 14, "WAVE")
        video.caption(31, 1, 14, "LIVES")
        video.caption(1, 28, 14, "CHAIN")
        video.caption(9, 28, 14, "POWER SHOT")
        if game.ammoMode != game.AMMO_UNLIMITED {
            video.caption(25, 28, 14, "AMMO")
        }
        if game.demoMode {
            video.caption(35, 29, 3, "DEMO")
        }
    }

    sub drawHud() {
        ubyte i
        video.scoreDigits(6, 1, 1, game.points)
        video.digits(21, 1, 1, game.wave, 5)
        video.digits(38, 1, 3, game.ships as uword, 1)
        video.digits(7, 28, 7, game.combo as uword, 1)
        for i in 0 to game.CHARGE_MARKS-1 {
            ubyte shade = 11
            if i < game.chargeMarks {
                shade = 13
            }
            video.cell(19 + i, 28, video.BAR, shade)
        }
        if game.chargeMarks == game.CHARGE_MARKS {
            video.caption(19, 28, 13, "READY")
        }
    }

    sub drawAmmo() {
        if game.ammoMode == game.AMMO_UNLIMITED {
            return
        } else if game.ammo == 0 and game.ammoMode == game.AMMO_SLOWDOWN {
            video.caption(30, 28, 7, "SLOW FIRE")
        } else if game.ammo == 0 and game.ammoMode == game.AMMO_PACKS {
            if game.refillX != 0 {
                video.caption(30, 28, 7, "GET PACK ")
            } else {
                video.caption(30, 28, 8, "GET POD  ")
            }
        } else if game.ammo == 0 {
            video.caption(30, 28, 8, "RELOADING")
        } else {
            ubyte shade = 1
            if game.ammo <= 8 {
                shade = 7
            }
            video.digits(30, 28, shade, game.ammo as uword, 2)
            video.caption(32, 28, 1, "       ")
        }
    }

    sub waveBanner(ubyte shade) {
        video.setup()
        video.caption(16, 14, shade, "WAVE ")
        video.digits(21, 14, shade, game.wave, 5)
        video.caption(15, 16, shade, "GET READY")
    }

    sub paused() {
        video.showTextMap()
        video.setup()
        video.caption(13, 14, 7, " PAUSED ")
    }

    sub results() {
        video.clear()
        video.caption(3, 3, 10, "REACTOR LOST")
        video.caption(3, 5, 14, "FINAL SCORE")
        video.scoreDigits(16, 5, 1, game.points)
    }

    sub continuePrompt() {
        video.caption(3, 25, 7, "PRESS SPACE / B TO CONTINUE")
    }

    sub initialsPage() {
        video.caption(3, 9, 7, "NEW HIGH SCORE")
        video.caption(3, 15, 15, "UP / DOWN TO CHANGE LETTER")
        video.caption(3, 16, 15, "LEFT / RIGHT TO CHOOSE SLOT")
        video.caption(3, 17, 15, "SPACE / B SAVE. SELECT / ESC SKIP.")
    }

    ; The three letters, with the one that is being changed marked.
    sub initialsLetters(ubyte slot) {
        ubyte i
        video.setup()
        for i in 0 to 2 {
            ubyte shade = 14
            if i == slot {
                shade = 7
            }
            video.cell(4 + i * 2, 12, nameTile(game.letters[i]), shade)
        }
    }

    sub saveFailed() {
        video.setup()
        video.caption(3, 20, 10, "SAVE FAILED. SCORE KEPT IN RAM.")
    }
}
