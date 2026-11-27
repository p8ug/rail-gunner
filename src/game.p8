; Rail Gunner: the game itself, the same on every machine.
; What a machine does differently is in its _platform modules:
;   video    the grid of cells, and showing a frame
;   screens  every page of text, and the layout of the HUD
;   input    keyboard and gamepads as one byte of buttons
;   audio    sound effects
;   music    the soundtrack
;   storage  where the high scores are kept (used by scores)
%import syslib
%import video_platform
%import input_platform
%import audio_platform
%import music_platform
%import screens_platform
%import scores

game {
    const ubyte XMIN = 1
    const ubyte XMAX = 38
    const ubyte YMIN = 4
    const ubyte YMAX = 26
    const ubyte CELLULAR_YMAX = YMAX - 2
    const ubyte UP = 0
    const ubyte DOWN = 1
    const ubyte LEFT = 2
    const ubyte RIGHT = 3
    const ubyte FIRE = 16
    const ubyte START = 32
    const ubyte QUIT = input.QUIT | input.SELECT
    const ubyte DRONES = 36
    const ubyte CLASSIC_SPAWN_LIMIT = DRONES - 2
    const ubyte PLAY_MENU = 0
    const ubyte MODE_MENU = 1
    const ubyte WAVE_MENU = 2
    const ubyte AMMO_MENU = 3
    const ubyte X_SHOTS_MENU = 4
    const ubyte SCORES_MENU = 5
    const ubyte HELP_MENU = 6
    const ubyte AMMO_UNLIMITED = 0
    const ubyte AMMO_SLOWDOWN = 1
    const ubyte AMMO_RELOAD = 2
    const ubyte AMMO_PACKS = 3
    const ubyte IMPACTS = 6
    const ubyte LIFE_W = 16
    const ubyte LIFE_H = 8
    const ubyte LIFE_CELLS = LIFE_W * LIFE_H
    const ubyte PULSES = 12
    const ubyte MAGAZINE = 40
    const ubyte POD_AMMO = 6
    const ubyte RESERVE_AMMO = 12
    const ubyte RELOAD_TICKS = 45
    const ubyte FIRE_INTERVAL = 6
    const ubyte SLOW_INTERVAL = 12
    const ubyte CHARGE_MARKS = 5
    const ubyte BOLTS = 5
    const ubyte DROPS = 12
    const ubyte TRAIN = 0
    const ubyte SHARD = 3
    const ubyte POD_LIFE = 148
    const ubyte POD_MORPH = 96
    const ubyte POD_FIRE = 86
    const ubyte TRAIN_LENGTH = 10
    const ubyte RAIL_APPEAR = 54
    const ubyte RAIL_STEP_FRAMES = 7
    const ubyte RAIL_HOLD = 24
    const ubyte RAIL_RECOVER = RAIL_HOLD + 9
    const ubyte RAIL_PERIOD = 168
    const ubyte RAIL_SHOT_STEP_FRAMES = 2
    const ubyte RAIL_PODS = 16
    const ubyte RAIL_POD_MORPH = 41
    const ubyte RAIL_POD_MATURE = 71
    const ubyte RAIL_POD_CHARGE = 101
    const uword RAIL_POD_LIFETIME = 1800
    const ubyte RAIL_POD_GROWTH_TICKS = 6
    const ubyte RAIL_POD_DWELL_TICKS = 8
    const ubyte IMPACT_TICKS = 12
    const ubyte SHIPS_PER_GAME = 3
    const uword DEMO_IDLE = 720
    const uword DEMO_LENGTH = 1500
    const ubyte WAVE_BLACK_FRAMES = 12
    const ubyte WAVE_INTRO_FRAMES = 48

    ; Stagger trains from alternate edges across the top four rows.
    ubyte[3] patrolX = [1, 6, 33]
    ; Half ticks per cell. Waves 1 through 5 all use the first interval.
    ubyte[7] classicInterval = [8, 7, 6, 5, 4, 3, 2]
    ubyte[4] classExtraDelay = [0, 0, 3, 0]

    ubyte px, py, moveAxis, moveWait, fireWait
    bool shipLost
    ubyte phase, spawnWait, dronesLive, clearWait
    uword wave, quota
    ubyte chargeMarks, combo, comboWait, held, edge, previous
    ubyte trainNumber, trainRemaining, formationTail, patrolNumber, difficulty, classicTempo
    ubyte openingTrains
    uword selectedWave = 1
    ubyte menuFocus, menuPage, waveRepeat, waveDirection
    uword idleFrames
    bool demoMode
    ubyte ships, waveSeed
    long wavePoints
    long points
    bool hudDirty, ammoDirty, waveIntro
    ubyte ammoMode = AMMO_UNLIMITED
    ubyte ammo, reloadWait, refillX, refillY
    ubyte markedPod
    bool wreckSound
    bool shootableX = true

    ubyte[DRONES] ex
    ubyte[DRONES] ey
    ubyte[DRONES] kind
    ubyte[DRONES] heading
    ubyte[DRONES] hp
    ubyte[DRONES] motion
    bool[DRONES] shortStep
    ubyte[DRONES] rising
    ubyte[DRONES] nextSegment   ; Slot plus one, or zero at the end of a train.
    bool[DRONES] hasLeader
    ubyte guns, droneLimit
    bool[DRONES] scatterStep
    ubyte[PULSES] sx
    ubyte[PULSES] sy
    ubyte[PULSES] charge
    ubyte[BOLTS] bx
    ubyte[BOLTS] by
    ubyte[BOLTS] velocity
    ubyte[DROPS] dx
    ubyte[DROPS] dy
    ubyte[DROPS] life
    ubyte[DROPS] podFlash
    bool[DROPS] podDamaged
    ubyte railPosition, railTime, railStep, railStopped
    bool railLeftReverse, railBottomReverse
    ubyte railAppearFrame, railCycleFrames
    ubyte railSeed = $a7
    ubyte railShotX, railShotY, railShotWait, railLatch
    bool railShotFromLeft, railShotActive
    ubyte[RAIL_PODS] railPodX
    ubyte[RAIL_PODS] railPodY
    ubyte[RAIL_PODS] railPodAge
    uword[RAIL_PODS] railPodTime
    ubyte[RAIL_PODS] railPodGrowthWait
    ubyte railPodDwell
    ubyte leftRailY, bottomRailX
    bool railFromLeft, railEngaged
    ubyte[IMPACTS] sparkX
    ubyte[IMPACTS] sparkY
    ubyte[IMPACTS] sparkLife
    ubyte sparkSlot
    bool[DRONES] volatileDrone
    bool[DRONES] blastPending
    ubyte volatileSeed
    ubyte blastLeft, blastRight, blastTop, blastBottom
    ubyte mode
    ubyte cellularRow, cellularSeed
    ubyte[LIFE_CELLS] lifeBoard
    ubyte[LIFE_CELLS] lifeNext
    ubyte[LIFE_CELLS] lifeSnapshot
    ubyte[DRONES] lifeSource
    ubyte[LIFE_W] lifeColumns
    ubyte lifeCursor, lifeEvolveCursor, lifeFront, lifeLastColumn, lifePreview
    ubyte[3] letters
    ubyte[30] rowTargets            ; not zero: a shot could hit something in this row

    sub run() {
        input.init()
        audio.init()
        scores.load()
        video.init()
        music.init()
        screens.title()

        repeat {
            frame()
            if edge & QUIT != 0 {
                if menuPage == PLAY_MENU {
                    if input.CAN_EXIT {
                        break
                    }
                    continue
                }
                menuPage = PLAY_MENU
                screens.title()
                continue
            }
            railSeed++
            if held == 0 and menuPage == PLAY_MENU and menuFocus == PLAY_MENU {
                idleFrames++
                if idleFrames == DEMO_IDLE {
                    attract()
                    screens.title()
                    idleFrames = 0
                    continue
                }
            } else {
                idleFrames = 0
            }
            if menuPage != PLAY_MENU {
                if edge & (FIRE | START) != 0 {
                    menuPage = PLAY_MENU
                    screens.title()
                }
                continue
            }
            editTitle()
            if edge & (FIRE | START) != 0 {
                if menuFocus == PLAY_MENU {
                    if railSeed == 0 {
                        railSeed = $a7
                    }
                    newGame()
                    music.start()
                    play()
                    music.stop()
                    idleFrames = 0
                    audio.silence()
                    if ships == 0 and edge & QUIT == 0 {
                        results()
                    }
                    screens.title()
                } else if menuFocus >= SCORES_MENU {
                    menuPage = menuFocus
                    screens.title()
                }
            }
        }

        audio.silence()
        input.shutdown()
        video.close()
    }

    sub frame() {
        video.vsync()
        video.present()
        held = input.poll()
        edge = held & (previous ^ $ff)
        previous = held
        audio.tick()
        music.tick()
    }

    sub editTitle() {
        if edge & input.UP != 0 and menuFocus > PLAY_MENU {
            menuFocus--
            audio.menu()
            screens.titleValues()
        } else if edge & input.DOWN != 0 and menuFocus < HELP_MENU {
            menuFocus++
            audio.menu()
            screens.titleValues()
        }

        ubyte direction = held & (input.LEFT | input.RIGHT)
        if menuFocus == MODE_MENU {
            if direction == input.RIGHT and edge & input.RIGHT != 0 {
                mode++
                if mode == 5 {
                    mode = 0
                }
                audio.menu()
                screens.titleValues()
            } else if direction == input.LEFT and edge & input.LEFT != 0 {
                if mode == 0 {
                    mode = 5
                }
                mode--
                audio.menu()
                screens.titleValues()
            }
        }
        if menuFocus == AMMO_MENU {
            if direction == input.RIGHT and edge & input.RIGHT != 0 {
                ammoMode++
                if ammoMode > AMMO_PACKS {
                    ammoMode = AMMO_UNLIMITED
                }
                audio.menu()
                screens.titleValues()
            } else if direction == input.LEFT and edge & input.LEFT != 0 {
                if ammoMode == AMMO_UNLIMITED {
                    ammoMode = AMMO_PACKS
                } else {
                    ammoMode--
                }
                audio.menu()
                screens.titleValues()
            }
        }
        if menuFocus == X_SHOTS_MENU and (direction == input.LEFT or direction == input.RIGHT) and edge & direction != 0 {
            shootableX = not shootableX
            audio.menu()
            screens.titleValues()
        }
        if menuFocus != WAVE_MENU or (direction != input.LEFT and direction != input.RIGHT) {
            waveDirection = 0
            return
        }
        uword step = 1
        if direction != waveDirection {
            waveRepeat = 0
            waveDirection = direction
        } else {
            if waveRepeat == 252 {
                waveRepeat = 240
            }
            waveRepeat++
            if waveRepeat < 24 or waveRepeat % 6 != 0 {
                return
            }
            if waveRepeat >= 144 {
                step = 1000
            } else if waveRepeat >= 72 {
                step = 100
            } else if waveRepeat >= 36 {
                step = 10
            }
        }
        uword oldWave = selectedWave
        if direction == input.RIGHT {
            if selectedWave > 65535 - step {
                selectedWave = 65535
            } else {
                selectedWave += step
            }
        } else if selectedWave <= step {
            selectedWave = 1
        } else {
            selectedWave -= step
        }
        if oldWave != selectedWave {
            if waveRepeat == 0 or waveRepeat % 12 == 0 {
                audio.menu()
            }
            screens.titleValues()
        }
    }

    sub attract() {
        uword savedWave = selectedWave
        ubyte savedAmmo = ammoMode
        ammoMode = AMMO_UNLIMITED
        ubyte savedMode = mode
        mode = 0
        selectedWave = 5
        ubyte savedSeed = railSeed
        railSeed = $a7
        newGame()
        selectedWave = savedWave
        music.start()
        demoMode = true
        arena()
        waveIntro = false
        uword elapsed = 0
        repeat DEMO_LENGTH {
            frame()
            if held != 0 or shipLost or waveIntro {
                break
            }
            held = FIRE
            if (elapsed & 127) >= 88 {
                if elapsed & 128 == 0 {
                    held |= input.RIGHT
                } else {
                    held |= input.LEFT
                }
            }
            gameTick()
            elapsed++
        }
        mode = savedMode
        ammoMode = savedAmmo
        railSeed = savedSeed
        demoMode = false
        audio.silence()
        music.stop()
    }

    sub newGame() {
        ships = SHIPS_PER_GAME
        points = 0
        wave = selectedWave
        waveSeed = railSeed
        wavePoints = points
        resetWave()
    }

    sub resetWave() {
        ubyte i
        for i in 0 to DRONES-1 {
            hp[i] = 0
            blastPending[i] = false
            lifeSource[i] = $ff
        }
        for i in 0 to PULSES-1 {
            sx[i] = 0
        }
        for i in 0 to BOLTS-1 {
            bx[i] = 0
        }
        for i in 0 to DROPS-1 {
            life[i] = 0
        }
        for i in 0 to RAIL_PODS-1 {
            railPodAge[i] = 0
        }
        railFromLeft = true
        railEngaged = false
        leftRailY = YMIN
        bottomRailX = XMIN
        railTime = 0
        railStep = 0
        railLeftReverse = false
        railBottomReverse = false
        railShotActive = false
        railPodDwell = 0
        moveAxis = 0
        px = 20
        py = 22
        shipLost = false
        fireWait = 0
        ammo = MAGAZINE
        refillX = 0
        markedPod = DROPS
        reloadWait = 0
        ammoDirty = true
        moveWait = 0
        for i in 0 to IMPACTS-1 {
            sparkLife[i] = 0
        }
        sparkSlot = 0
        video.clearBlasts()
        volatileSeed = waveSeed ^ $9d
        if volatileSeed == 0 {
            volatileSeed = $9d
        }
        phase = 0
        combo = 1
        comboWait = 0
        chargeMarks = 0
        dronesLive = 0
        railSeed = waveSeed
        audio.silence()
        clearWait = 0
        trainNumber = 0
        trainRemaining = 0
        formationTail = 0
        patrolNumber = 0
        lifePreview = 0
        spawnWait = 18
        ubyte tempoWave = 20
        if wave < 20 {
            tempoWave = wave as ubyte
        }
        difficulty = (tempoWave - 1) / 3
        droneLimit = DRONES
        classicTempo = 0
        if tempoWave >= 19 {
            classicTempo = 6
        } else if tempoWave >= 17 {
            classicTempo = 5
        } else if tempoWave >= 6 {
            classicTempo = (tempoWave - 3) / 3
        }
        openingTrains = 2
        if wave >= 3 {
            openingTrains = 3
        }
        quota = 3 + (openingTrains as uword) * TRAIN_LENGTH
        if wave >= 6 {
            quota += ((tempoWave - 6) / 4 + 1) * TRAIN_LENGTH
        }
        if wave > 20 {
            quota += ((wave - 20) / 20) * TRAIN_LENGTH
        }
        if mode != 0 {
            quota = (16 + tempoWave) * 2
            if wave > 20 {
                quota += (wave - 20) / 2
            }
            cellularSeed = waveSeed
            if cellularSeed == 0 {
                cellularSeed = $a7
            }
            cellularRow = YMIN
            seedLife()
            projectLifeRow()
        }
        guns = 1
        if wave >= 12 {
            guns = 3
        } else if wave >= 6 {
            guns = 2
        }
        railAppearFrame = RAIL_APPEAR - difficulty * 6
        railCycleFrames = RAIL_PERIOD - difficulty * 6
        hudDirty = true
        waveIntro = true
    }

    sub arena() {
        ubyte x, y
        video.blackout()
        video.wipeText()
        for x in 0 to 39 {
            video.cell(x, 3, video.BAR, video.BORDER_COLOR)
            video.cell(x, 27, video.BAR, video.BORDER_COLOR)
        }
        for y in YMIN to YMAX {
            video.cell(0, y, video.RAIL, video.BORDER_COLOR)
            video.cell(39, y, video.RAIL, video.BORDER_COLOR)
        }
        screens.hudLabels()
        drawHud()
        drawAmmo()
        drawObjects(false)
        video.cell(0, leftRailY, video.GUN_RIGHT, 8)
        video.cell(bottomRailX, 27, video.GUN_UP, 8)
        if railEngaged {
            drawRailGun()
        }
        video.prepareArena()
        video.showGrid()
    }

    sub drawHud() {
        screens.drawHud()
        hudDirty = false
    }

    sub drawAmmo() {
        screens.drawAmmo()
        ammoDirty = false
    }

    asmsub eraseObjects() clobbers(A, X, Y) {
        %asm {{
            ; The VERA address bank and increment were set by video.setup.
            lda p8b_game.p8v_px
            ldy p8b_game.p8v_py
            jsr p8b_video.p8s_background
            #p8b_gamemacros.eraseSlots p8b_game.p8v_hp, p8b_game.p8v_ex, p8b_game.p8v_ey, p8b_game.p8v_droneLimit, p8b_video.p8s_background
            #p8b_gamemacros.eraseSlots p8b_game.p8v_sx, p8b_game.p8v_sx, p8b_game.p8v_sy,  #p8b_game.p8c_PULSES, p8b_video.p8s_background
            #p8b_gamemacros.eraseSlots p8b_game.p8v_bx, p8b_game.p8v_bx, p8b_game.p8v_by,  #p8b_game.p8c_BOLTS, p8b_video.p8s_background
            #p8b_gamemacros.eraseSlots p8b_game.p8v_life, p8b_game.p8v_dx, p8b_game.p8v_dy,  #p8b_game.p8c_DROPS, p8b_video.p8s_background
            rts
        }}
    }

    sub drawObjects(bool advanceBlasts) {
        video.drawBlasts(advanceBlasts)
        if refillX != 0 {
            video.cell(refillX, refillY, video.RESERVE_PACK, 7)
        }
        ubyte i
        for i in 0 to IMPACTS-1 {
            if sparkLife[i] != 0 {
                drawImpact(i)
            }
        }
        if lifePreview != 0 {
            drawLifePreview(false)
        }
        for i in 0 to DROPS-1 {
            if life[i] != 0 {
                ubyte tile = video.AMMO_PACK
                ubyte podShade = 13
                if i == markedPod and phase & 8 == 0 {
                    podShade = 1
                }
                if life[i] <= POD_FIRE {
                    tile = video.POD_ARMED
                    podShade = 8
                } else if life[i] <= POD_MORPH {
                    tile = video.POD_WAKING
                    if life[i] & 2 != 0 {
                        podShade = 7
                    }
                }
                if podFlash[i] != 0 {
                    tile = video.BURST
                    podShade = 1
                }
                video.cell(dx[i], dy[i], tile, podShade)
            }
        }
        for i in 0 to droneLimit-1 {
            if hp[i] != 0 {
                if kind[i] == TRAIN {
                    ubyte wing = video.TRAIN
                    ubyte wingColor = 3
                    if mode == 0 and ((phase + i) & 8) != 0 {
                        wing = video.TRAIN_FLAP
                    }
                    if hasLeader[i] {
                        wingColor = 4
                    }
                    if volatileDrone[i] {
                        wingColor = 8
                    }
                    video.cell(ex[i], ey[i], wing, wingColor)
                } else {
                    ubyte enemyColor = enemyShade(kind[i])
                    if volatileDrone[i] {
                        enemyColor = 8
                    }
                    video.cell(ex[i], ey[i], video.enemyTile(kind[i]), enemyColor)
                }
            }
        }
        for i in 0 to PULSES-1 {
            if sx[i] != 0 {
                ubyte shade = 7
                if charge[i] != 0 {
                    shade = 13
                }
                video.cell(sx[i], sy[i], video.PULSE, shade)
            }
        }
        for i in 0 to BOLTS-1 {
            if bx[i] != 0 {
                video.cell(bx[i], by[i], video.BOLT, 10)
            }
        }
        for i in 0 to RAIL_PODS-1 {
            ubyte age = railPodAge[i]
            if age != 0 {
                ubyte railTile = video.RAIL_POD_SEED
                ubyte railColor = 3
                if age >= RAIL_POD_CHARGE {
                    railTile = video.RAIL_CHARGE
                    railColor = 10
                } else if age >= RAIL_POD_MATURE {
                    railTile = video.POD_ARMED
                    railColor = 10
                } else if age >= RAIL_POD_MORPH {
                    railTile = video.POD_WAKING
                    railColor = 7
                }
                video.cell(railPodX[i], railPodY[i], railTile, railColor)
            }
        }
        if railShotActive {
            ubyte shotTile = video.RAIL_SHOT_UP
            if railShotFromLeft {
                shotTile = video.RAIL_SHOT_RIGHT
            }
            video.cell(railShotX, railShotY, shotTile, 3)
        }
        if not shipLost {
            ubyte shipTile = video.SHIP
            if lifePreview != 0 and py == cellularRow and px >= 4 and px <= 34 and px & 1 == 0 {
                if lifeColumns[(px - 4) >> 1] != 0 {
                    shipTile = video.SHIP_WARNING
                }
            }
            video.cell(px, py, shipTile, 1)
        }
    }

    sub drawImpact(ubyte slot) {
        ubyte shade = 8
        ubyte tile = video.IMPACT_SMOKE
        if sparkLife[slot] > 9 {
            shade = 1
            tile = video.IMPACT_FLASH
        } else if sparkLife[slot] > 5 {
            shade = 7
            tile = video.BURST
        }
        video.cell(sparkX[slot], sparkY[slot], tile, shade)
        if sparkLife[slot] > 4 {
            impactFragments(slot, false)
        }
    }

    sub impactFragments(ubyte slot, bool erase) {
        ubyte tile = video.IMPACT_FRAGMENT
        ubyte shade = 8
        if erase {
            tile = 32
            shade = 0
        } else if sparkLife[slot] > 9 {
            shade = 7
        }
        if sparkX[slot] > XMIN {
            video.cell(sparkX[slot] - 1, sparkY[slot], tile, shade)
        }
        if sparkX[slot] < XMAX {
            video.cell(sparkX[slot] + 1, sparkY[slot], tile, shade)
        }
        if sparkY[slot] > YMIN {
            video.cell(sparkX[slot], sparkY[slot] - 1, tile, shade)
        }
        if sparkY[slot] < YMAX {
            video.cell(sparkX[slot], sparkY[slot] + 1, tile, shade)
        }
    }

    sub impact(ubyte x, ubyte y) {
        ubyte slot = sparkSlot
        sparkSlot++
        if sparkSlot == IMPACTS {
            sparkSlot = 0
        }
        sparkX[slot] = x
        sparkY[slot] = y
        sparkLife[slot] = IMPACT_TICKS
    }

    sub enemyShade(ubyte role) -> ubyte {
        if role == 1 {
            return 8
        }
        if role == SHARD {
            return 15
        }
        return 2
    }

    sub play() {
        while ships != 0  {
            if waveIntro {
                announceWave()
                if edge & QUIT != 0 {
                    return
                }
            }
            frame()
            if edge & QUIT != 0 {
                return
            }
            if edge & START != 0 {
                pause()
                if edge & QUIT != 0 {
                    return
                }
            }
            gameTick()
            if shipLost {
                ships--
                repeat 24 {
                    frame()
                    if edge & QUIT != 0 {
                        return
                    }
                }
                if ships != 0 {
                    points = wavePoints
                    resetWave()
                }
            }
        }
    }

    sub gameTick() {
        phase++
        video.setup()
        video.buffering = true
        eraseObjects()
        if refillX != 0 {
            video.background(refillX, refillY)
        }
        if lifePreview != 0 {
            drawLifePreview(true)
        }
        ubyte railSlot
        for railSlot in 0 to RAIL_PODS-1 {
            if railPodAge[railSlot] != 0 {
                video.background(railPodX[railSlot], railPodY[railSlot])
            }
        }
        if railShotActive {
            video.background(railShotX, railShotY)
        }
        ubyte spark
        for spark in 0 to IMPACTS-1 {
            if sparkLife[spark] != 0 {
                video.background(sparkX[spark], sparkY[spark])
                if sparkLife[spark] > 4 {
                    impactFragments(spark, true)
                }
                sparkLife[spark]--
            }
        }
        if comboWait != 0 {
            comboWait--
            if comboWait == 0 {
                combo = 1
                hudDirty = true
            }
        }
        ubyte previousX = px
        ubyte previousY = py
        pilot()
        if px != previousX or py != previousY {
            railPodDwell = 0
        }
        updateRailShot()
        updateRailGuns()
        pulses()
        resolveBlasts()
        if wreckSound {
            audio.blast()
            wreckSound = false
        }
        updateRailPods()
        if phase & 1 == 0 {
            enemyBolts()
            updatePods()
        }
        if not shipLost {
            fleet()
        }
        drawObjects(true)
        if hudDirty {
            drawHud()
        }
        if ammoDirty {
            drawAmmo()
        }
        video.flushCells()
    }

    sub announceWave() {
        video.blackout()
        video.wipeText()
        repeat WAVE_BLACK_FRAMES {
            frame()
            if edge & QUIT != 0 {
                return
            }
        }
        ubyte elapsed
        for elapsed in 0 to WAVE_INTRO_FRAMES - 1 {
            frame()
            if edge & QUIT != 0 {
                return
            }
            if elapsed == 0 or elapsed == 24 {
                audio.waveCue(elapsed != 0)
                screens.waveBanner(7)
                if elapsed == 0 {
                    video.showText()
                }
            } else if elapsed == 9 or elapsed == 33 {
                screens.waveBanner(11)
            }
        }
        arena()
        waveIntro = false
    }

    sub pause() {
        screens.paused()
        repeat {
            frame()
            if edge & (FIRE | START | QUIT) != 0 {
                break
            }
        }
        arena()
    }

    sub pilot() {
        if reloadWait != 0 {
            reloadWait--
            if reloadWait == 0 {
                ammo = RESERVE_AMMO
                ammoDirty = true
            }
        }
        if moveWait != 0 {
            moveWait--
        } else {
            moveShip()
        }
        if fireWait != 0 {
            fireWait--
        }
        if refillX == px and refillY == py {
            refillX = 0
            ammo = MAGAZINE
            ammoDirty = true
            audio.pickup()
        }
        if ammoMode == AMMO_SLOWDOWN and held & FIRE == 0 and phase & 7 == 0 and ammo < MAGAZINE {
            ammo++
            ammoDirty = true
        }
        if held & FIRE != 0 and fireWait == 0 and (ammo != 0 or ammoMode < AMMO_RELOAD) {
            firePulse()
        }
    }

    sub moveShip() {
        if held & $0f == 0 {
            return
        }
        ubyte vx = held & $0c
        ubyte vy = held & $03
        if (vy == 1 and py == YMIN) or (vy == 2 and py == YMAX) or vy == 3 {
            vy = 0
        }
        if (vx == 4 and px == XMIN) or (vx == 8 and px == XMAX) or vx == 12 {
            vx = 0
        }
        ; Diagonals alternate horizontal and vertical steps, never sharing a tick.
        if vx != 0 and vy != 0 {
            if moveAxis == 0 {
                vy = 0
            } else {
                vx = 0
            }
            moveAxis ^= 1
        }
        if vy == 1 {
            py--
        } else if vy == 2 {
            py++
        } else if vx == 4 {
            px--
        } else if vx == 8 {
            px++
        }
        moveWait = 2
    }

    sub firePulse() {
        ubyte firstColumn = px
        ubyte lastColumn = px
        if guns >= 2 and px > XMIN {
            firstColumn--
        }
        if guns >= 2 and px < XMAX {
            lastColumn++
        }

        ubyte freeSlots = 0
        ubyte slot
        for slot in 0 to PULSES-1 {
            if sx[slot] == 0 {
                freeSlots++
            }
        }
        ubyte volleySize = lastColumn - firstColumn + 1
        if guns == 2 {
            volleySize--
        }
        if freeSlots < volleySize {
            return
        }

        ubyte charged = 0
        if chargeMarks == CHARGE_MARKS {
            chargeMarks = 0
            charged = 1
            hudDirty = true
            audio.blast()
        }
        ubyte column = firstColumn
        if guns == 2 and column == px {
            column++
        }
        for slot in 0 to PULSES-1 {
            if sx[slot] == 0 {
                sx[slot] = column
                sy[slot] = py
                charge[slot] = charged
                volleySize--
                if volleySize == 0 {
                    break
                }
                column++
                if guns == 2 and column == px {
                    column++
                }
            }
        }
        audio.shot()
        fireWait = FIRE_INTERVAL
        if ammoMode != AMMO_UNLIMITED {
            if ammo != 0 {
                ammo--
                ammoDirty = true
                if ammo == 0 {
                    if ammoMode == AMMO_RELOAD {
                        reloadWait = RELOAD_TICKS
                    }
                    if ammoMode >= AMMO_RELOAD {
                        audio.dry()
                    }
                }
            }
            if ammoMode == AMMO_SLOWDOWN and ammo < 24 {
                fireWait = SLOW_INTERVAL - (ammo >> 2)
            }
        }
    }

    sub pulses() {
        ubyte i
        markRows()
        for i in 0 to PULSES-1 {
            if sx[i] != 0 {
                hitCell(i)
                if sx[i] != 0 {
                    movePulse(i)
                    if sx[i] != 0 {
                        hitCell(i)
                    }
                }
            }
        }
    }

    sub movePulse(ubyte i) {
        if sy[i] > YMIN {
            sy[i]--
        } else {
            sx[i] = 0
        }
    }

    sub hitCell(ubyte shotIndex) {
        ubyte x = sx[shotIndex]
        ubyte y = sy[shotIndex]
        if rowTargets[y] == 0 {
            return
        }
        ubyte i = railPodAt(x, y, shootableX)
        if i != $ff {
            impact(x, y)
            ubyte age = railPodAge[i]
            sx[shotIndex] = 0
            if charge[shotIndex] != 0 or age >= RAIL_POD_CHARGE {
                railPodAge[i] = 0
            } else {
                sx[shotIndex] = 0
                railPodGrowthWait[i] = RAIL_POD_GROWTH_TICKS
                if age >= RAIL_POD_MATURE {
                    railPodAge[i] = RAIL_POD_MORPH
                } else if age >= RAIL_POD_MORPH {
                    railPodAge[i] = 1
                } else {
                    railPodAge[i] = 0
                }
            }
            audio.hit()
            return
        }
        if shootableX {
            i = boltAt(x, y)
            if i != $ff {
                bx[i] = 0
                sx[shotIndex] = 0
                impact(x, y)
                audio.hit()
                return
            }
        }
        i = droneAt(x, y)
        if i != $ff {
            sx[shotIndex] = 0
            if charge[shotIndex] == 0 {
                hp[i]--
            } else {
                hp[i] = 0
            }
            if hp[i] == 0 and not blastPending[i] {
                wreck(i)
                if kind[i] == 2 {
                    splitDrone(x, y)
                }
            } else {
                impact(x, y)
                audio.hit()
            }
            return
        }
        i = podAt(x, y)
        if i != $ff {
            ; A pilot standing on a green pod can still collect it while firing.
            if life[i] > POD_MORPH and x == px and y == py {
                return
            }
            hitPod(shotIndex, i)
        }
    }

    ; Most rows that a shot crosses are empty, and looking for a target in each
    ; of them is most of the work of a busy tick.  So note once, before the shots
    ; move, which rows have anything that a shot could hit.  While the shots are
    ; moved nothing changes rows: a wreck leaves its pod and its shards in its
    ; own cell, and a blast is resolved afterwards.
    asmsub markRows() clobbers(A, X, Y) {
        %asm {{
            ldx #29
        _clear
            stz p8v_rowTargets,x
            dex
            bpl _clear
            ldx #0
        _drones
            lda p8v_hp,x
            beq _noDrone
            ldy p8v_ey,x
            sta p8v_rowTargets,y
        _noDrone
            inx
            cpx p8v_droneLimit
            bcc _drones
            ldx #p8c_RAIL_PODS-1
        _railPods
            lda p8v_railPodAge,x
            beq _noRailPod
            ldy p8v_railPodY,x
            sta p8v_rowTargets,y
        _noRailPod
            dex
            bpl _railPods
            ldx #p8c_DROPS-1
        _pods
            lda p8v_life,x
            beq _noPod
            ldy p8v_dy,x
            sta p8v_rowTargets,y
        _noPod
            dex
            bpl _pods
            ldx #p8c_BOLTS-1
        _bolts
            lda p8v_bx,x
            beq _noBolt
            ldy p8v_by,x
            sta p8v_rowTargets,y
        _noBolt
            dex
            bpl _bolts
            rts
        }}
    }

    ; These scans run twice per live pulse. Check rows first and preserve slot
    ; order when cells are shared. Only the player can target falling charges.
    asmsub railPodAt(ubyte x @R0, ubyte y @R1, bool includeCharge @Y) clobbers(X) -> ubyte @A {
        %asm {{
            ldx #0
        _loop
            lda p8b_game.p8v_railPodY,x
            cmp cx16.r1L
            bne _next
            lda p8b_game.p8v_railPodX,x
            cmp cx16.r0L
            bne _next
            lda p8b_game.p8v_railPodAge,x
            beq _next
            cmp #p8b_game.p8c_RAIL_POD_CHARGE
            bcc _found
            cpy #0
            bne _found
        _next
            inx
            cpx #p8b_game.p8c_RAIL_PODS
            bcc _loop
            lda #$ff
            rts
        _found
            txa
            rts
        }}
    }

    asmsub boltAt(ubyte x @R0, ubyte y @R1) clobbers(X) -> ubyte @A {
        %asm {{
            ldx #0
        _loop
            lda p8v_by,x
            cmp cx16.r1L
            bne _next
            lda p8v_bx,x
            cmp cx16.r0L
            beq _found
        _next
            inx
            cpx #p8c_BOLTS
            bcc _loop
            lda #$ff
            rts
        _found
            txa
            rts
        }}
    }

    asmsub droneAt(ubyte x @R0, ubyte y @R1) clobbers(X) -> ubyte @A {
        %asm {{
            ldx #0
        _loop
            lda p8b_game.p8v_ey,x
            cmp cx16.r1L
            bne _next
            lda p8b_game.p8v_ex,x
            cmp cx16.r0L
            bne _next
            lda p8b_game.p8v_hp,x
            bne _found
        _next
            inx
            cpx p8b_game.p8v_droneLimit
            bcc _loop
            lda #$ff
            rts
        _found
            txa
            rts
        }}
    }

    asmsub podAt(ubyte x @R0, ubyte y @R1) clobbers(X) -> ubyte @A {
        %asm {{
            ldx #0
        _loop
            lda p8b_game.p8v_dy,x
            cmp cx16.r1L
            bne _next
            lda p8b_game.p8v_dx,x
            cmp cx16.r0L
            bne _next
            lda p8b_game.p8v_life,x
            bne _found
        _next
            inx
            cpx #p8b_game.p8c_DROPS
            bcc _loop
            lda #$ff
            rts
        _found
            txa
            rts
        }}
    }

    sub hitPod(ubyte shotIndex, ubyte podIndex) {
        impact(dx[podIndex], dy[podIndex])
        bool piercing = charge[shotIndex] != 0
        sx[shotIndex] = 0
        if life[podIndex] <= POD_FIRE and not podDamaged[podIndex] and not piercing {
            podDamaged[podIndex] = true
            podFlash[podIndex] = 4
            audio.hit()
            return
        }
        life[podIndex] = 0
        audio.blast()
    }

    sub wreck(ubyte i) {
        dronesLive--
        if not volatileDrone[i] {
            impact(ex[i], ey[i])
        }
        wreckSound = true
        uword reward = ((kind[i] as uword) + 2) * 10 * (combo as uword)
        if points <= 999999999 - reward {
            points += reward
        } else {
            points = 999999999
        }
        if combo < 9 {
            combo++
        }
        comboWait = 85
        hudDirty = true
        if volatileDrone[i] {
            blastPending[i] = true
        } else {
            dropPod(ex[i], ey[i])
        }
        if lifeSource[i] != $ff {
            ubyte source = lifeSource[i]
            if mode < 3 {
                ; A partly calculated generation must use the new neighbor counts.
                lifeEvolveCursor = 0
            }
            lifeFront--
            lifeLastColumn = source
            if lifeFront == 1 {
                ubyte slot
                for slot in 0 to droneLimit-1 {
                    if hp[slot] != 0 and lifeSource[slot] != $ff {
                        lifeLastColumn = lifeSource[slot]
                        break
                    }
                }
            }
            if lifeFront <= 1 and lifeCursor == LIFE_W {
                spawnWait = 0
            }
            ubyte limit = LIFE_W
            if mode < 3 {
                limit = LIFE_CELLS
            }
            while source < limit {
                lifeBoard[source] = 0
                source += LIFE_W
            }
            lifeSource[i] = $ff
        }
        if kind[i] == TRAIN {
            breakTrain(i)
        }
    }

    sub markDrone(ubyte slot) {
        if volatileSeed & 1 == 0 {
            volatileSeed >>= 1
        } else {
            volatileSeed = (volatileSeed >> 1) ^ $b8
        }
        volatileDrone[slot] = volatileSeed & 7 == 0
    }

    sub resolveBlasts() {
        bool found = true
        while found {
            found = false
            for source in 0 to droneLimit-1 {
                if blastPending[source] {
                    blastPending[source] = false
                    ubyte x = ex[source]
                    ubyte y = ey[source]
                    blastLeft = x - 1
                    blastRight = x + 2
                    blastTop = y - 1
                    blastBottom = y + 2
                    video.stampBlast(x, y)
                    found = true
                    if px >= blastLeft and px < blastRight and py >= blastTop and py < blastBottom {
                        loseShip()
                    }
                    blastTargets()
                    if railShotActive and railShotX >= blastLeft and railShotX < blastRight and railShotY >= blastTop and railShotY < blastBottom {
                        railShotActive = false
                    }
                }
            }
        }
    }

    asmsub blastTargets() clobbers(A, X, Y) {
        %asm {{
            #p8b_gamemacros.blastSlots p8v_hp, p8v_ex, p8v_ey, p8v_droneLimit, true, p8s_wreck
            #p8b_gamemacros.blastSlots p8v_life, p8v_dx, p8v_dy, #p8c_DROPS, false, p8s_wreck
            #p8b_gamemacros.blastSlots p8v_bx, p8v_bx, p8v_by, #p8c_BOLTS, false, p8s_wreck
            #p8b_gamemacros.blastSlots p8v_railPodAge, p8v_railPodX, p8v_railPodY, #p8c_RAIL_PODS, false, p8s_wreck
            rts
        }}
    }

    sub dropPod(ubyte x, ubyte y) {
        ubyte j
        ubyte slot = 0
        ; Keep one pod per cell. A free slot has zero remaining life.
        for j in 0 to DROPS-1 {
            if life[j] != 0 and dx[j] == x and dy[j] == y {
                slot = j
                break
            }
            if life[j] < life[slot] {
                slot = j
            }
        }
        dx[slot] = x
        dy[slot] = y
        life[slot] = POD_LIFE
        podFlash[slot] = 0
        podDamaged[slot] = false
    }

    sub breakTrain(ubyte hit) {
        ubyte i
        if hasLeader[hit] {
            for i in 0 to droneLimit-1 {
                if hp[i] != 0 and nextSegment[i] == hit + 1 {
                    nextSegment[i] = 0
                    break
                }
            }
        }
        if formationTail == hit + 1 {
            formationTail = 0
        }
        ubyte follower = nextSegment[hit]
        nextSegment[hit] = 0
        if follower != 0 {
            i = follower - 1
            hasLeader[i] = false
            motion[i] = 1
            scatterStep[i] = true
        }
    }

    sub splitDrone(ubyte x, ubyte y) {
        ubyte i
        ubyte fragments = 0
        for i in 0 to droneLimit-1 {
            if hp[i] == 0 and not blastPending[i] {
                ex[i] = x
                ey[i] = y
                kind[i] = SHARD
                volatileDrone[i] = false
                lifeSource[i] = $ff
                heading[i] = fragments
                motion[i] = 1
                shortStep[i] = false
                rising[i] = 0
                nextSegment[i] = 0
                hasLeader[i] = false
                scatterStep[i] = false
                hp[i] = 1
                dronesLive++
                fragments++
                if fragments == 2 {
                    return
                }
            }
        }
    }

    sub updatePods() {
        markedPod = DROPS
        ubyte closest = 255
        ubyte i
        for i in 0 to DROPS-1 {
            if life[i] != 0 {
                if podFlash[i] != 0 {
                    podFlash[i]--
                }
                life[i]--
                if life[i] > POD_MORPH and px == dx[i] and py == dy[i] {
                    life[i] = 0
                    if chargeMarks < CHARGE_MARKS {
                        chargeMarks++
                        hudDirty = true
                    }
                    if ammoMode != AMMO_UNLIMITED {
                        if ammoMode == AMMO_SLOWDOWN and fireWait > FIRE_INTERVAL {
                            fireWait = FIRE_INTERVAL
                        }
                        if ammoMode == AMMO_SLOWDOWN or ammoMode == AMMO_PACKS {
                            ammo = MAGAZINE
                        } else {
                            ammo += POD_AMMO
                        }
                        refillX = 0
                        if ammo > MAGAZINE {
                            ammo = MAGAZINE
                        }
                        reloadWait = 0
                        ammoDirty = true
                    }
                    audio.pickup()
                } else if life[i] > POD_MORPH and ammoMode == AMMO_PACKS and ammo <= 8 {
                    ubyte distance = (abs((px as byte) - (dx[i] as byte)) + abs((py as byte) - (dy[i] as byte))) as ubyte
                    ; Movement can take three ticks per cell. Leave time to react.
                    if distance < closest and distance * 3 + 12 < (life[i] - POD_MORPH) * 2 {
                        closest = distance
                        markedPod = i
                    }
                } else if life[i] == POD_MORPH {
                    audio.warn()
                } else if life[i] == POD_FIRE or life[i] == 56 or life[i] == 26 {
                    podMissile(i)
                }
            }
        }
        if ammoMode == AMMO_PACKS and ammo == 0 and refillX == 0 and markedPod == DROPS {
            placeReserve()
            ammoDirty = true
        }
    }

    sub placeReserve() {
        for distance in 1 to 5 {
            ; Prefer three to five cells; one or two cells are a fallback.
            ubyte offset = distance + 2
            if distance > 3 {
                offset = distance - 3
            }
            if px + offset <= XMAX and reserveCell(px + offset, py) {
                refillX = px + offset
                refillY = py
                return
            }
            if px >= XMIN + offset and reserveCell(px - offset, py) {
                refillX = px - offset
                refillY = py
                return
            }
            if py >= YMIN + offset and reserveCell(px, py - offset) {
                refillX = px
                refillY = py - offset
                return
            }
            if py + offset <= YMAX and reserveCell(px, py + offset) {
                refillX = px
                refillY = py + offset
                return
            }
        }
    }

    sub reserveCell(ubyte x, ubyte y) -> bool {
        for i in 0 to droneLimit - 1 {
            if hp[i] != 0 and ex[i] == x and ey[i] == y {
                return false
            }
        }
        for i in 0 to RAIL_PODS - 1 {
            if railPodAge[i] != 0 and railPodX[i] == x and railPodY[i] == y {
                return false
            }
        }
        for i in 0 to DROPS - 1 {
            if life[i] != 0 and dx[i] == x and dy[i] == y {
                return false
            }
        }
        for i in 0 to BOLTS - 1 {
            if bx[i] == x and by[i] == y {
                return false
            }
        }
        return not (railShotActive and railShotX == x and railShotY == y)
    }

    sub podMissile(ubyte i) {
        ubyte slot = 0
        while bx[slot] != 0 {
            slot++
            if slot == BOLTS {
                return
            }
        }
        ubyte x = dx[i]
        ubyte y = dy[i]
        byte xDistance = (px as byte) - (x as byte)
        byte yDistance = (py as byte) - (y as byte)
        ubyte course = DOWN
        if abs(xDistance) > abs(yDistance) {
            course = RIGHT
            if xDistance < 0 {
                course = LEFT
            }
        } else if yDistance < 0 {
            course = UP
        }
        launchBolt(slot, x, y, course)
    }

    sub drawRailGun() {
        ubyte leftShade = 8
        ubyte bottomShade = 8
        if railEngaged {
            ubyte flash = 7
            if railStopped >= RAIL_HOLD {
                flash = 1
            }
            if railFromLeft {
                leftShade = flash
            } else {
                bottomShade = flash
            }
        }
        video.cell(0, leftRailY, video.GUN_RIGHT, leftShade)
        video.cell(bottomRailX, 27, video.GUN_UP, bottomShade)
    }

    sub updateRailGuns() {
        railTime++
        if railTime == railCycleFrames {
            railTime = 0
            railFromLeft = not railFromLeft
        }
        if railTime == railAppearFrame {
            railEngaged = true
            railStopped = 0
            audio.warn()
            drawRailGun()
        }
        if railEngaged {
            railStopped++
            if railStopped == RAIL_HOLD {
                railPosition = bottomRailX
                if railFromLeft {
                    railPosition = leftRailY
                }
                fireRailShot()
                drawRailGun()
            } else if railStopped == RAIL_RECOVER {
                railEngaged = false
                drawRailGun()
            }
        }
        railStep++
        if railStep < RAIL_STEP_FRAMES {
            return
        }
        railStep = 0
        if not railEngaged or not railFromLeft {
            video.cell(0, leftRailY, video.RAIL, video.BORDER_COLOR)
            if leftRailY == YMAX {
                railLeftReverse = true
            } else if leftRailY == YMIN {
                railLeftReverse = false
            }
            if railLeftReverse {
                leftRailY--
            } else {
                leftRailY++
            }
        }
        if not railEngaged or railFromLeft {
            video.cell(bottomRailX, 27, video.BAR, video.BORDER_COLOR)
            if bottomRailX == XMAX {
                railBottomReverse = true
            } else if bottomRailX == XMIN {
                railBottomReverse = false
            }
            if railBottomReverse {
                bottomRailX--
            } else {
                bottomRailX++
            }
        }
        drawRailGun()
    }

    sub fireRailShot() {
        railShotFromLeft = railFromLeft
        railShotX = railPosition
        railShotY = YMAX
        if railShotFromLeft {
            railShotX = XMIN
            railShotY = railPosition
        }
        railLatch = 0
        if randomLane(4, 3) != 0 {
            if railShotFromLeft {
                railLatch = 5 + randomLane(XMAX - 4, 63)
            } else {
                railLatch = YMIN + randomLane(YMAX - YMIN - 3, 31)
            }
        }
        railShotActive = true
        railShotWait = RAIL_SHOT_STEP_FRAMES
        audio.launch()
        railShotContact()
    }

    sub updateRailShot() {
        if not railShotActive {
            return
        }
        railShotContact()
        if not railShotActive {
            return
        }
        railShotWait--
        if railShotWait != 0 {
            return
        }
        railShotWait = RAIL_SHOT_STEP_FRAMES
        ubyte laneCell
        if railShotFromLeft {
            if railShotX == XMAX {
                railShotActive = false
                return
            }
            railShotX++
            laneCell = railShotX
        } else {
            if railShotY == YMIN {
                railShotActive = false
                return
            }
            railShotY--
            laneCell = railShotY
        }
        railShotContact()
        if railShotActive and laneCell == railLatch {
            latchRailPod()
        }
    }

    sub railShotContact() {
        if railPodAt(railShotX, railShotY, false) != $ff {
            railShotActive = false
            impact(railShotX, railShotY)
            audio.hit()
        } else if px == railShotX and py == railShotY {
            railShotActive = false
            loseShip()
        }
    }

    sub latchRailPod() {
        ; If the chosen cell is occupied, the seed continues off-board.
        if px == railShotX and py == railShotY {
            return
        }
        if droneAt(railShotX, railShotY) != $ff or podAt(railShotX, railShotY) != $ff {
            return
        }
        ubyte i
        ubyte freeSlot = $ff
        for i in 0 to RAIL_PODS-1 {
            if railPodAge[i] == 0 {
                freeSlot = i
            } else if railPodX[i] == railShotX and railPodY[i] == railShotY {
                return
            }
        }
        if freeSlot != $ff {
            railPodAge[freeSlot] = 1
            railPodTime[freeSlot] = RAIL_POD_LIFETIME
            railPodGrowthWait[freeSlot] = RAIL_POD_GROWTH_TICKS
            railPodX[freeSlot] = railShotX
            railPodY[freeSlot] = railShotY
            railShotActive = false
            audio.hit()
        }
    }

    sub updateRailPods() {
        ubyte i
        bool onMaturePod = false
        for i in 0 to RAIL_PODS-1 {
            ubyte age = railPodAge[i]
            if age == 0 {
                continue
            }
            if age < RAIL_POD_CHARGE {
                railPodTime[i]--
                if railPodTime[i] == 0 {
                    if age < RAIL_POD_MATURE {
                        railPodAge[i] = 0
                        continue
                    }
                    age = RAIL_POD_CHARGE
                    railPodAge[i] = age
                    audio.launch()
                } else if age < RAIL_POD_MATURE {
                    railPodGrowthWait[i]--
                    if railPodGrowthWait[i] == 0 {
                        railPodGrowthWait[i] = RAIL_POD_GROWTH_TICKS
                        age++
                        railPodAge[i] = age
                        if age == RAIL_POD_MORPH or age == RAIL_POD_MATURE {
                            audio.warn()
                        }
                    }
                }
            } else if phase & 1 == 0 {
                if px == railPodX[i] and py == railPodY[i] {
                    loseShip()
                }
                if railPodY[i] == YMAX {
                    railPodAge[i] = 0
                    continue
                }
                railPodY[i]++
            }
            if age == RAIL_POD_CHARGE and interceptPulse(railPodX[i], railPodY[i]) {
                railPodAge[i] = 0
                continue
            }
            if age >= RAIL_POD_MATURE and px == railPodX[i] and py == railPodY[i] {
                if age == RAIL_POD_CHARGE {
                    loseShip()
                } else {
                    onMaturePod = true
                }
            }
        }
        if onMaturePod {
            railPodDwell++
            if railPodDwell >= RAIL_POD_DWELL_TICKS {
                loseShip()
            }
        } else {
            railPodDwell = 0
        }
    }

    sub randomLane(ubyte range, ubyte mask) -> ubyte {
        repeat {
            if railSeed & 1 != 0 {
                railSeed = (railSeed >> 1) ^ $b8
            } else {
                railSeed >>= 1
            }
            ubyte lane = railSeed & mask
            if lane < range {
                return lane
            }
        }
    }

    sub nextWave() {
        if wave < 65535 {
            wave++
        }
        waveSeed = railSeed
        wavePoints = points
        resetWave()
    }

    sub fleet() {
        ubyte i
        if quota == 0 and dronesLive == 0 {
            clearWait++
            if clearWait == 45 {
                nextWave()
                return
            }
        }
        for i in 0 to droneLimit-1 {
            if hp[i] != 0 {
                if ex[i] == px and ey[i] == py {
                    loseShip()
                    return
                }
                if mode == 0 and not hasLeader[i] {
                    if motion[i] != 0 {
                        motion[i]--
                    } else {
                        advanceDrone(i)
                    }
                }
            }
        }
        if spawnWait != 0 {
            spawnWait--
        } else if quota != 0 {
            if mode == 0 {
                if dronesLive < CLASSIC_SPAWN_LIMIT {
                    spawn()
                }
            } else if lifePreview != 0 {
                lifePreview--
            } else if dronesLive < droneLimit {
                spawnLife()
            }
        }
    }

    sub seedLife() {
        ubyte cell
        for cell in 0 to LIFE_CELLS-1 {
            lifeBoard[cell] = 0
        }

        if mode >= 3 {
            ; Start with an uneven cluster and leave both edges open.
            ubyte anchor = 2 + (nextCellSeed() & 3)
            lifeBoard[anchor] = 1
            lifeBoard[anchor + 1] = 1
            lifeBoard[anchor + 4] = 1
            lifeBoard[anchor + 6] = 1
            lifeBoard[anchor + 7] = 1
            repeat difficulty {
                lifeBoard[nextCellSeed() & 15] = 1
            }
        } else {
            ; Two mirrored R-pentominoes interact as the board evolves.
            ubyte lifeAnchor = LIFE_W + 1 + (nextCellSeed() & 1)
            seedPentomino(lifeAnchor, true)
            seedPentomino(lifeAnchor + 7 + (nextCellSeed() & 1), false)
            repeat difficulty {
                lifeBoard[(nextCellSeed() & 63) + LIFE_W] = 1
            }
        }
        lifeEvolveCursor = 0
    }

    sub seedPentomino(ubyte anchor, bool facingRight) {
        lifeBoard[anchor + 1] = 1
        lifeBoard[anchor + LIFE_W + 1] = 1
        lifeBoard[anchor + LIFE_W * 2 + 1] = 1
        if facingRight {
            lifeBoard[anchor + 2] = 1
            lifeBoard[anchor + LIFE_W] = 1
        } else {
            lifeBoard[anchor] = 1
            lifeBoard[anchor + LIFE_W + 2] = 1
        }
    }

    sub nextCellSeed() -> ubyte {
        if cellularSeed & 1 != 0 {
            cellularSeed = (cellularSeed >> 1) ^ $b8
        } else {
            cellularSeed >>= 1
        }
        return cellularSeed
    }

    sub projectLifeRow() {
        ; The physical rows are a fixed record of successive generations.
        ; Life needs its separate 2D board, whose occupied columns form each row.
        ubyte column
        for column in 0 to LIFE_W-1 {
            lifeColumns[column] = lifeBoard[column]
        }
        if mode < 3 {
            ubyte cell
            for cell in LIFE_W to LIFE_CELLS-1 {
                if lifeBoard[cell] != 0 {
                    lifeColumns[cell % LIFE_W] = 1
                }
            }
        }
        lifeFront = 0
        for column in 0 to LIFE_W-1 {
            if lifeColumns[column] != 0 {
                lifeFront++
                lifeLastColumn = column
            }
        }
        for column in 0 to droneLimit-1 {
            lifeSource[column] = $ff
        }
        lifeCursor = 0
    }

    sub evolveLife() {
        ubyte cell, x, y, nx, ny, neighbours
        if lifeEvolveCursor == 0 {
            for cell in 0 to LIFE_CELLS-1 {
                lifeSnapshot[cell] = lifeBoard[cell]
            }
        }
        ubyte stopCell = lifeEvolveCursor + LIFE_W - 1
        for cell in lifeEvolveCursor to stopCell {
            x = cell % LIFE_W
            y = cell / LIFE_W
            neighbours = 0
            for ny in 0 to 2 {
                for nx in 0 to 2 {
                    ubyte column = x + nx
                    ubyte row = y + ny
                    if column != 0 and column <= LIFE_W and row != 0 and row <= LIFE_H {
                        if nx != 1 or ny != 1 {
                            neighbours += lifeSnapshot[(row - 1) * LIFE_W + column - 1]
                        }
                    }
                }
            }
            lifeNext[cell] = 0
            if neighbours == 3 or (neighbours == 2 and lifeSnapshot[cell] != 0) {
                lifeNext[cell] = 1
            } else if mode == 2 and neighbours == 6 and lifeSnapshot[cell] == 0 {
                lifeNext[cell] = 1
            }
        }
        lifeEvolveCursor += LIFE_W
        if lifeEvolveCursor < LIFE_CELLS {
            return
        }
        lifeEvolveCursor = 0
        for cell in 0 to LIFE_CELLS-1 {
            lifeBoard[cell] = lifeNext[cell]
        }
    }

    sub evolveElementary() {
        ubyte rule = 30
        if mode == 4 {
            rule = 110
        }
        ubyte column
        for column in 0 to LIFE_W-1 {
            ubyte pattern = lifeBoard[column] << 1
            if column != 0 {
                pattern |= lifeBoard[column - 1] << 2
            }
            if column != LIFE_W-1 {
                pattern |= lifeBoard[column + 1]
            }
            lifeNext[column] = (rule >> pattern) & 1
        }
        for column in 0 to LIFE_W-1 {
            lifeBoard[column] = lifeNext[column]
        }
    }

    sub seedLifeNear(ubyte column) {
        ; A three-cell oscillator gives visible neighbors on this row and
        ; a narrower next generation. Keep it within finite board edges.
        if column == 0 {
            column = 1
        } else if column == LIFE_W-1 {
            column--
        }
        lifeBoard[LIFE_W * 3 + column - 1] = 1
        lifeBoard[LIFE_W * 3 + column] = 1
        lifeBoard[LIFE_W * 3 + column + 1] = 1
    }

    sub drawLifePreview(bool clear) {
        ubyte column
        for column in 0 to LIFE_W-1 {
            if lifeColumns[column] != 0 {
                ubyte x = 4 + column * 2
                if clear {
                    video.background(x, cellularRow)
                } else {
                    video.cell(x, cellularRow, video.POD_WAKING, 7)
                }
            }
        }
    }

    sub spawnLife() {
        while lifeCursor < LIFE_W and lifeColumns[lifeCursor] == 0 {
            lifeCursor++
        }
        if lifeCursor == LIFE_W {
            if cellularRow == CELLULAR_YMAX {
                ; Leave two rows below the formation so the ship can fire
                ; from beyond a volatile cell's blast.
                if dronesLive == 0 {
                    cellularRow = YMIN
                    seedLife()
                    projectLifeRow()
                }
                return
            }
            if mode >= 3 {
                evolveElementary()
            } else {
                evolveLife()
                if lifeEvolveCursor != 0 {
                    return
                }
            }
            cellularRow++
            ubyte source = lifeLastColumn
            projectLifeRow()
            if lifeFront == 0 {
                if mode < 3 {
                    seedLifeNear(source)
                } else {
                    seedLife()
                }
                projectLifeRow()
                lifePreview = 2
            }
            if cellularRow + 1 >= py and cellularRow <= py + 1 {
                lifePreview = 10
            }
            return
        }
        ubyte x = 4 + lifeCursor * 2
        ubyte slot
        for slot in 0 to droneLimit-1 {
            if hp[slot] == 0 and not blastPending[slot] {
                ex[slot] = x
                ey[slot] = cellularRow
                hp[slot] = 1
                kind[slot] = TRAIN
                markDrone(slot)
                lifeSource[slot] = lifeCursor
                nextSegment[slot] = 0
                hasLeader[slot] = false
                scatterStep[slot] = false
                rising[slot] = 0
                motion[slot] = 1
                heading[slot] = lsb(wave) & 1
                dronesLive++
                quota--
                lifeCursor++
                while lifeCursor < LIFE_W and lifeColumns[lifeCursor] == 0 {
                    lifeCursor++
                }
                if lifeCursor == LIFE_W {
                    if lifeFront > 1 {
                        spawnWait = 14 - difficulty
                    }
                }
                if x == px and cellularRow == py {
                    loseShip()
                }
                return
            }
        }
    }

    sub spawn() {
        ubyte role = TRAIN
        ubyte x, y
        if trainNumber == openingTrains and patrolNumber < 3 {
            x = patrolX[patrolNumber]
            y = YMIN + (patrolNumber & 1)
            role = 1
            if patrolNumber == 0 {
                role = 2
            }
        } else {
            ; Reserve room for the whole train before opening its entry lane.
            if trainRemaining == 0 and dronesLive > CLASSIC_SPAWN_LIMIT - TRAIN_LENGTH {
                return
            }
            x = XMIN
            if trainNumber & 1 != 0 {
                x = XMAX
            }
            y = YMIN + (trainNumber & 3)
        }
        if difficulty & 1 != 0 {
            x = XMAX + XMIN - x
        }
        if droneAt(x, y) != $ff {
            return
        }
        for slot in 0 to droneLimit-1 {
            if hp[slot] == 0 and not blastPending[slot] {
                ex[slot] = x
                ey[slot] = y
                kind[slot] = role
                markDrone(slot)
                lifeSource[slot] = $ff
                nextSegment[slot] = 0
                scatterStep[slot] = false
                hasLeader[slot] = false
                heading[slot] = 1
                if x > 20 {
                    heading[slot] = 0
                }
                hp[slot] = 1
                if role == 2 {
                    hp[slot] = 2
                }
                shortStep[slot] = false
                resetDroneMotion(slot)
                rising[slot] = 0
                if role == TRAIN {
                    if trainRemaining == 0 {
                        trainRemaining = TRAIN_LENGTH
                    }
                    if formationTail != 0 {
                        ubyte tail = formationTail - 1
                        ubyte adjacent = XMIN + 1
                        if x == XMAX {
                            adjacent = XMAX - 1
                        }
                        if ex[tail] == adjacent and ey[tail] == y {
                            nextSegment[tail] = slot + 1
                            hasLeader[slot] = true
                        }
                    }
                    formationTail = slot + 1
                    trainRemaining--
                    if trainRemaining == 0 {
                        trainNumber++
                        ; Keep the first three entrances close enough to overlap.
                        ; Later groups re-use the four lanes in order.
                        if trainNumber == openingTrains + 4 {
                            trainNumber -= 4
                        }
                        formationTail = 0
                        spawnWait = 4
                    }
                } else {
                    patrolNumber++
                    spawnWait = 12
                }
                quota--
                dronesLive++
                if x == px and y == py {
                    loseShip()
                }
                return
            }
        }
    }

    sub advanceDrone(ubyte head) {
        ubyte x = ex[head]
        ubyte y = ey[head]
        ubyte direction = heading[head]
        ubyte vertical = rising[head]
        droneStep(head)
        if ex[head] == px and ey[head] == py {
            loseShip()
        }

        ; Each segment moves into the cell its leader just left.
        ubyte follower = nextSegment[head]
        while follower != 0 {
            ubyte i = follower - 1
            if (ex[i] == px and ey[i] == py) or (x == px and y == py) {
                loseShip()
            }
            ubyte previous = ex[i]
            ex[i] = x
            x = previous
            previous = ey[i]
            ey[i] = y
            y = previous
            previous = heading[i]
            heading[i] = direction
            direction = previous
            previous = rising[i]
            rising[i] = vertical
            vertical = previous
            follower = nextSegment[i]
        }
    }

    sub resetDroneMotion(ubyte i) {
        ubyte interval = classicInterval[classicTempo]
        motion[i] = (interval >> 1) - 1 + classExtraDelay[kind[i]]
        if interval & 1 != 0 {
            if not shortStep[i] {
                motion[i]++
            }
            shortStep[i] = not shortStep[i]
        }
    }

    sub droneStep(ubyte i) {
        ubyte role = kind[i]
        resetDroneMotion(i)
        if scatterStep[i] {
            scatterStep[i] = false
            stepRow(i)
            return
        }
        ubyte left = XMIN
        ubyte right = XMAX
        if role == 1 {
            left = 6
            right = 33
        }

        if heading[i] == 0 and ex[i] > left {
            ex[i]--
        } else if heading[i] == 1 and ex[i] < right {
            ex[i]++
        } else {
            ; Turn on a separate tick so the change of row is a single step.
            heading[i] ^= 1
            stepRow(i)
        }
    }

    sub stepRow(ubyte i) {
        if ey[i] == YMAX {
            rising[i] = 1
        } else if ey[i] == YMIN {
            rising[i] = 0
        }
        if rising[i] != 0 {
            ey[i]--
        } else {
            ey[i]++
        }
    }

    ; A pod projectile can also move into a shot after the player shots have moved.
    sub interceptPulse(ubyte x, ubyte y) -> bool {
        if shootableX {
            for shot in 0 to PULSES-1 {
                if sx[shot] == x and sy[shot] == y {
                    sx[shot] = 0
                    impact(x, y)
                    audio.hit()
                    return true
                }
            }
        }
        return false
    }

    sub launchBolt(ubyte slot, ubyte x, ubyte y, ubyte course) {
        audio.launch()
        if interceptPulse(x, y) {
            return
        }
        if x == px and y == py {
            loseShip()
        } else {
            bx[slot] = x
            by[slot] = y
            velocity[slot] = course
        }
    }

    sub enemyBolts() {
        ubyte i
        for i in 0 to BOLTS-1 {
            if bx[i] != 0 {
                if railPodAt(bx[i], by[i], false) != $ff {
                    bx[i] = 0
                    continue
                }
                if px == bx[i] and py == by[i] {
                    bx[i] = 0
                    loseShip()
                    continue
                }
                if velocity[i] == DOWN and by[i] < YMAX {
                    by[i]++
                } else if velocity[i] == UP and by[i] > YMIN {
                    by[i]--
                } else if velocity[i] == LEFT and bx[i] > XMIN {
                    bx[i]--
                } else if velocity[i] == RIGHT and bx[i] < XMAX {
                    bx[i]++
                } else {
                    bx[i] = 0
                    continue
                }
                if railPodAt(bx[i], by[i], false) != $ff or interceptPulse(bx[i], by[i]) {
                    bx[i] = 0
                    continue
                }
                if px == bx[i] and py == by[i] {
                    bx[i] = 0
                    loseShip()
                }
            }
        }
    }

    sub loseShip() {
        if shipLost {
            return
        }
        shipLost = true
        combo = 1
        comboWait = 0
        chargeMarks = 0
        impact(px, py)
        hudDirty = true
        audio.down()
    }

    sub results() {
        screens.results()
        audio.start()
        if scores.qualifies(points) {
            initials()
        } else {
            continuePrompt()
        }
    }

    sub continuePrompt() {
        screens.continuePrompt()
        repeat {
            frame()
            if edge & (FIRE | START | QUIT) != 0 {
                return
            }
        }
    }

    sub initials() {
        ubyte i
        ubyte slot = 0
        ubyte navWait = 0
        letters[0] = 65
        letters[1] = 65
        letters[2] = 65
        screens.initialsPage()
        repeat {
            screens.initialsLetters(slot)
            frame()
            if edge & QUIT != 0 {
                return
            }
            if edge & (FIRE | START) != 0 {
                scores.submit(points, letters[0], letters[1], letters[2])
                if not scores.last_save_ok {
                    screens.saveFailed()
                    continuePrompt()
                }
                return
            }
            if edge & 4 != 0 and slot != 0 {
                slot--
            }
            if edge & 8 != 0 and slot < 2 {
                slot++
            }
            if held & 3 == 0 {
                navWait = 0
            } else if navWait != 0 {
                navWait--
            } else {
                navWait = 7
                if held & 1 != 0 {
                    letters[slot]++
                    if letters[slot] > 90 {
                        letters[slot] = 65
                    }
                } else {
                    letters[slot]--
                    if letters[slot] < 65 {
                        letters[slot] = 90
                    }
                }
            }
        }
    }
}

; The assembly macros of the game.  They are outside its block because on the
; GameTank that block is in a bank of the cartridge, and there the assembler
; has it inside a macro of its own, where a macro with parameters cannot be
; defined.  A macro is no code: this block takes no room.
gamemacros {
    %option force_output
    %asm {{
        ; Erase the cells of the slots that are in use: \1 says which are,
        ; \2 and \3 are their columns and rows, \4 the number of slots,
        ; \5 the routine that erases a cell.
        eraseSlots .macro
            ldx #0
        _loop
            lda \1,x
            beq _next
            lda \2,x
            ldy \3,x
            jsr \5
        _next
            inx
            cpx \4
            bcc _loop
        .endmacro

        ; Clear the slots that are inside the blast, the same parameters;
        ; \5 says whether a slot is a drone, which \6 wrecks.
        blastSlots .macro
            ldx #0
        _loop:
            lda \1,x
            beq _next
            lda \3,x
            cmp p8b_game.p8v_blastTop
            bcc _next
            cmp p8b_game.p8v_blastBottom
            bcs _next
            lda \2,x
            cmp p8b_game.p8v_blastLeft
            bcc _next
            cmp p8b_game.p8v_blastRight
            bcs _next
            stz \1,x
            .if \5
                phx
                txa
                jsr \6
                plx
            .endif
        _next:
            inx
            cpx \4
            bcc _loop
        .endmacro
    }}
}
