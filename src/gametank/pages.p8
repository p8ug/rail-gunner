; Rail Gunner's pages of text for the GameTank: the title page with its menu,
; the high scores, the help, and what comes after a game.
;
; A page is drawn into the framebuffer that is shown and changed there in
; place.  Text in the 3 x 5 font is 31 characters to a line, 4 pixels each;
; a line is 6 pixels high.  Headings are in the library's 8 x 8 font.
%import gfx
%import scores
%import video_platform

pages {
    %option overlay_data

    const ubyte LEFT = 10           ; where text begins
    const ubyte MENU_TOP = 42
    const ubyte MENU_STEP = 7
    const ubyte VALUES = 70

    ubyte flap

    ; Pad menu values so changing a choice overwrites the whole previous line.
    str[] menuLabels = ["PLAY", "MODE", "STARTING WAVE", "AMMO", "X SHOTS", "HIGH SCORES", "CONTROLS & CREDITS"]
    str[] modeNames = [
        "CLASSIC    ", "CONWAY LIFE", "HIGHLIFE   ", "RULE 30    ", "RULE 110   "
    ]
    str[] modeHelp = [
        "BUTTERFLY TRAINS SWEEP THE GRID",
        "THREE NEIGHBORS CREATE A CELL  ",
        "LIFE WITH BIRTHS AT 3 OR 6     ",
        "IRREGULAR PATTERNS GROW DOWN   ",
        "REPEATING PATTERNS GROW DOWN   "
    ]
    str[] ammoNames = ["UNLIMITED  ", "SLOWDOWN   ", "AUTO-RELOAD", "AMMO PACKS "]
    str[] ammoHelp = [
        "FULL SPEED WHILE YOU HOLD FIRE ",
        "SLOWS. RELEASE FIRE TO RECOVER ",
        "STOPS TO RELOAD. PODS REFILL   ",
        "FOLLOW FLASHING PODS TO REFILL "
    ]

    sub title() {
        dbg.step(15)
        video.clear()
        if game.menuPage == game.SCORES_MENU {
            gfx.heading(20, 10, "HIGH SCORES")
            gfx.text(LEFT, 26, 15, "LOCAL TOP FIVE")
            gfx.text(LEFT, 33, 15, "ALL MODES AND SETTINGS")
            leaderboard(46)
            gfx.text(LEFT, 106, 15, "C  BACK")
            return
        }
        if game.menuPage == game.HELP_MENU {
            gfx.text(2, 8, 7, "CONTROLS & CREDITS")
            gfx.text(2, 15, 15, "D-PAD  MOVE")
            gfx.text(2, 21, 15, "A / B  FIRE")
            gfx.text(2, 27, 15, "START  PAUSE")
            gfx.text(2, 33, 15, "C      RETURN TO TITLE")
            gfx.text(2, 41, 7, "RAIL GUNS FLASH BEFORE FIRING.")
            gfx.text(2, 47, 7, "PLANTED PODS BLOCK SHOTS.")
            gfx.text(2, 53, 7, "VOLATILE DRONES BLAST NEARBY.")
            gfx.text(2, 59, 7, "YELLOW GHOSTS MARK NEW CELLS.")
            gfx.text(2, 65, 7, "FLY UNDER CELL DRONES TO FIRE.")
            gfx.text(2, 71, 13, "5 GREEN PODS CHARGE ONE VOLLEY.")
            gfx.text(2, 77, 15, "IT BREAKS ARMOR AND PODS.")
            gfx.text(2, 83, 15, "AMMO PACKS: FLASHING POD OR +")
            gfx.text(2, 89, 15, "SHOOT RED XS IF SHOOTABLE.")
            gfx.text(2, 97, 3, "MUSIC: PUNCH YOUR WAY THROUGH")
            gfx.text(2, 103, 15, "BY NORTHIVANASTAN / CC0 1.0")
            gfx.text(2, 112, 15, "C  BACK")
            return
        }
        gfx.heading(20, 9, "RAIL GUNNER")
        dbg.step(18)
        ; a rail gun on either side of the name, one of them mirrored
        gfx.picture(13, 10, 13, gametank.SPRITE_FLIP_NONE)
        gfx.picture(13, 118, 13, gametank.SPRITE_FLIP_X)
        ; the cast, as on the X16's title page: ship, shot, train, patrol,
        ; armored drone, cell and rail pod
        gfx.picture(0, 16, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(1, 32, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(2, 48, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(4, 64, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(5, 80, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(17, 96, 31, gametank.SPRITE_FLIP_NONE)
        gfx.picture(11, 112, 31, gametank.SPRITE_FLIP_NONE)
        gametank.await_draw_queue()
        dbg.step(19)
        ubyte row
        for row in 0 to game.HELP_MENU {
            gfx.text(LEFT, MENU_TOP + row * MENU_STEP, 1, menuLabels[row])
        }
        gfx.text(2, 107, 15, "UP/DOWN SELECT  LEFT/RIGHT SET")
        gfx.text(2, 113, 15, "A OPEN  C BACK")
        dbg.step(20)
        titleValues()
        dbg.step(21)
    }

    sub titleValues() {
        ubyte row
        for row in 0 to game.HELP_MENU {
            ubyte mark = ' '
            if row == game.menuFocus {
                mark = '>'
            }
            gfx.glyph(3, MENU_TOP + row * MENU_STEP, 7, mark)
        }
        gfx.text(VALUES, MENU_TOP + MENU_STEP, 7, modeNames[game.mode])
        gfx.digits(VALUES, MENU_TOP + MENU_STEP * 2, 7, game.selectedWave, 5)
        gfx.text(VALUES, MENU_TOP + MENU_STEP * 3, 7, ammoNames[game.ammoMode])
        if game.shootableX {
            gfx.text(VALUES, MENU_TOP + MENU_STEP * 4, 7, "SHOOTABLE  ")
        } else {
            gfx.text(VALUES, MENU_TOP + MENU_STEP * 4, 7, "UNBREAKABLE")
        }
        gfx.text(2, 93, 15, modeHelp[game.mode])
        gfx.text(2, 99, 15, ammoHelp[game.ammoMode])
    }

    sub leaderboard(ubyte y) {
        ubyte i
        for i in 0 to 4 {
            gfx.glyph(LEFT, y, 14, '1' + i)
            gfx.glyph(LEFT + 12, y, 1, scores.first[i])
            gfx.glyph(LEFT + 16, y, 1, scores.second[i])
            gfx.glyph(LEFT + 20, y, 1, scores.third[i])
            gfx.score(LEFT + 36, y, 3, scores.points[i])
            y += 9
        }
    }

    sub waveBanner(ubyte shade) {
        gfx.heading(24, 44, "WAVE")
        gfx.heading(64, 44, gfx.format(game.wave, 5))
        gfx.text(46, 62, shade, "GET READY")
    }

    sub results() {
        video.clear()
        gfx.heading(16, 12, "REACTOR LOST")
        gfx.text(LEFT, 30, 14, "FINAL SCORE")
        gfx.score(LEFT + 48, 30, 1, game.points)
    }

    sub continuePrompt() {
        gfx.text(LEFT, 106, 7, "PRESS A TO CONTINUE")
    }

    sub initialsPage() {
        gfx.text(LEFT, 44, 7, "NEW HIGH SCORE")
        gfx.text(LEFT, 82, 15, "UP / DOWN    CHANGE LETTER")
        gfx.text(LEFT, 88, 15, "LEFT / RIGHT CHOOSE SLOT")
        gfx.text(LEFT, 94, 15, "A SAVE   C SKIP")
    }

    ; The three letters, with the one that is being changed marked.
    sub initialsLetters(ubyte slot) {
        ubyte i
        for i in 0 to 2 {
            ubyte shade = 14
            ubyte mark = ' '
            if i == slot {
                shade = 7
                mark = '^'
            }
            gfx.glyph(LEFT + 4 + i * 8, 58, shade, game.letters[i])
            gfx.glyph(LEFT + 4 + i * 8, 65, 7, mark)
        }
    }

    sub saveFailed() {
        gfx.text(LEFT, 74, 10, "SAVE FAILED. SCORE NOT KEPT.")
    }
}
