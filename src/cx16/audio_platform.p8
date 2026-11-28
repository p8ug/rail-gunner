; Rail Gunner sound effects. Each effect owns its voices so a shot never
; cancels a warning, hit, explosion, or crash.
audio {
    const ubyte AMMO_FRAMES = 6
    const ubyte SHOT_FRAMES = 6
    const ubyte HIT_FRAMES = 5
    const ubyte BLAST_FRAMES = 15
    const ubyte WARN_FRAMES = 8
    const ubyte LAUNCH_FRAMES = 9
    const ubyte DOWN_FRAMES = 18
    const ubyte START_FRAMES = 9
    const ubyte WAVE_FRAMES = 12

    ubyte menu_left
    ubyte[6] menu_gain = [63, 56, 51, 46, 38, 0]
    ubyte ammo_left
    bool ammo_pickup
    ubyte shot_left
    ubyte hit_left
    ubyte blast_left
    ubyte warn_left
    ubyte launch_left
    ubyte down_left
    ubyte start_left
    ubyte wave_left
    uword wave_lift

    ; Frequency words and gains from the hard attack to trailing silence.
    uword[7] shot_pitch = [4650, 1790, 1020, 740, 520, 0, 0]
    ubyte[7] shot_gain = [49, 38, 22, 11, 4, 0, 0]
    ubyte[7] shot_shape = [$09, $26, $0e, $21, $15, $15, $15]
    uword[7] shot_grain = [30800, 16100, 8600, 5400, 3700, 0, 0]
    ubyte[7] shot_noise = [62, 48, 30, 15, 6, 0, 0]
    uword[7] shot_body = [620, 530, 390, 300, 225, 0, 0]
    ubyte[7] shot_body_gain = [57, 49, 37, 24, 12, 0, 0]

    uword[6] hit_pitch = [2040, 1340, 720, 430, 280, 0]
    ubyte[6] hit_gain = [48, 43, 35, 24, 10, 0]
    ubyte[6] hit_noise = [58, 47, 35, 24, 11, 0]

    uword[16] blast_pitch = [890, 770, 480, 540, 359, 430, 310, 280,
                             325, 240, 220, 190, 170, 146, 125, 0]
    uword[16] blast_grain = [7100, 4400, 6400, 5200, 3100, 3700, 2380, 2100,
                             1650, 1900, 1200, 980, 800, 610, 450, 0]
    ubyte[16] blast_gain = [56, 51, 47, 41, 35, 32, 27, 21,
                            23, 17, 14, 11, 9, 7, 4, 0]
    ubyte[16] blast_noise = [62, 58, 50, 41, 34, 37, 28, 23,
                             21, 18, 15, 11, 9, 7, 5, 0]

    uword[9] warn_pitch = [1180, 972, 1610, 0, 1390, 1090, 690, 455, 0]
    ubyte[9] warn_gain = [37, 31, 27, 0, 33, 26, 19, 10, 0]
    uword[10] launch_pitch = [510, 880, 1380, 1690, 1440, 930, 670, 520, 390, 0]
    uword[10] launch_grain = [13100, 10450, 7900, 9300, 6700, 5200, 3900, 2980, 1700, 0]
    ubyte[10] launch_gain = [48, 44, 37, 32, 26, 20, 15, 10, 5, 0]
    ubyte[10] launch_noise = [47, 44, 40, 34, 29, 21, 16, 11, 6, 0]

    uword[19] down_pitch = [1770, 1260, 890, 1240, 620, 740, 500, 390, 480,
                            320, 300, 240, 270, 205, 179, 150, 133, 112, 0]
    uword[19] down_grain = [11400, 7490, 8910, 5400, 7210, 3320, 3810, 2590, 1840,
                            2230, 1530, 1180, 1430, 954, 820, 690, 777, 440, 0]
    ubyte[19] down_gain = [55, 51, 49, 41, 39, 43, 34, 27, 33,
                           27, 24, 19, 16, 15, 12, 9, 6, 4, 0]
    ubyte[19] down_noise = [56, 51, 46, 37, 39, 31, 26, 24, 22,
                            20, 17, 15, 13, 11, 9, 7, 7, 4, 0]

    uword[10] start_pitch = [640, 865, 1160, 1560, 1070, 1630, 2160, 2630, 2630, 2630]
    ubyte[10] start_gain = [32, 33, 34, 32, 26, 33, 27, 21, 12, 0]
    uword[13] wave_pitch = [570, 730, 1060, 1420, 0, 1800, 2230, 2500, 2720, 2160, 1920, 1380, 0]
    ubyte[13] wave_gain = [49, 46, 43, 38, 0, 41, 42, 35, 32, 25, 17, 9, 0]
    ubyte[13] wave_noise = [40, 23, 12, 6, 0, 24, 15, 10, 7, 5, 3, 0, 0]

    uword[7] dry_pitch = [3550, 2390, 0, 1790, 1320, 0, 0]
    ubyte[7] dry_gain = [36, 24, 0, 20, 10, 0, 0]
    uword[7] pickup_pitch = [1880, 2660, 3550, 3990, 3990, 3990, 0]
    ubyte[7] pickup_gain = [32, 27, 30, 25, 17, 8, 0]

    sub init() {
        silence()
    }

    sub silence() {
        ubyte offset
        menu_left = 0
        ammo_left = 0
        shot_left = 0
        hit_left = 0
        blast_left = 0
        warn_left = 0
        launch_left = 0
        down_left = 0
        start_left = 0
        wave_left = 0
        for offset in 0 to 15 {
            write_voice(offset << 2, 0, 0, 0)
        }
    }

    sub menu() {
        menu_left = 5
        write_voice(60, 1120, menu_gain[0], $80)
    }

    sub dry() {
        menu_left = 0
        ammo_pickup = false
        ammo_left = AMMO_FRAMES
        render_ammo(0)
    }

    sub pickup() {
        menu_left = 0
        ammo_pickup = true
        ammo_left = AMMO_FRAMES
        render_ammo(0)
    }

    sub render_ammo(ubyte frame) {
        if ammo_pickup {
            write_voice(60, pickup_pitch[frame], pickup_gain[frame], $80)
        } else {
            write_voice(60, dry_pitch[frame], dry_gain[frame], $c0)
        }
    }

    sub shot() {
        shot_left = SHOT_FRAMES
        render_shot(0)
    }

    sub hit() {
        hit_left = HIT_FRAMES
        render_hit(0)
    }

    sub blast() {
        blast_left = BLAST_FRAMES
        render_blast(0)
    }

    sub warn() {
        warn_left = WARN_FRAMES
        render_warn(0)
    }

    sub launch() {
        launch_left = LAUNCH_FRAMES
        render_launch(0)
    }

    sub down() {
        down_left = DOWN_FRAMES
        render_down(0)
    }

    sub start() {
        start_left = START_FRAMES
        render_start(0)
    }

    sub waveCue(bool higher) {
        wave_lift = 0
        if higher {
            wave_lift = 590
        }
        wave_left = WAVE_FRAMES
        render_wave(0)
    }

    sub tick() {
        if menu_left != 0 {
            menu_left--
            write_voice(60, 820 + (menu_left as uword) * 70, menu_gain[5 - menu_left], $80)
        }
        if ammo_left != 0 {
            ammo_left--
            render_ammo(AMMO_FRAMES - ammo_left)
        }
        if shot_left != 0 {
            shot_left--
            render_shot(SHOT_FRAMES - shot_left)
        }
        if hit_left != 0 {
            hit_left--
            render_hit(HIT_FRAMES - hit_left)
        }
        if blast_left != 0 {
            blast_left--
            render_blast(BLAST_FRAMES - blast_left)
        }
        if warn_left != 0 {
            warn_left--
            render_warn(WARN_FRAMES - warn_left)
        }
        if launch_left != 0 {
            launch_left--
            render_launch(LAUNCH_FRAMES - launch_left)
        }
        if down_left != 0 {
            down_left--
            render_down(DOWN_FRAMES - down_left)
        }
        if start_left != 0 {
            start_left--
            render_start(START_FRAMES - start_left)
        }
        if wave_left != 0 {
            wave_left--
            render_wave(WAVE_FRAMES - wave_left)
        }
    }

    sub render_shot(ubyte frame) {
        write_voice(0, shot_pitch[frame], shot_gain[frame], shot_shape[frame])
        write_voice(4, shot_grain[frame], shot_noise[frame], $c0)
        write_voice(40, shot_body[frame], shot_body_gain[frame], $40)
    }

    sub render_hit(ubyte frame) {
        write_voice(8, hit_pitch[frame], hit_gain[frame], $40)
        write_voice(12, 4410, hit_noise[frame], $c0)
    }

    sub render_blast(ubyte frame) {
        write_voice(16, blast_pitch[frame], blast_gain[frame], $40)
        write_voice(20, blast_grain[frame], blast_noise[frame], $c0)
    }

    sub render_warn(ubyte frame) {
        write_voice(24, warn_pitch[frame], warn_gain[frame], $21)
    }

    sub render_launch(ubyte frame) {
        write_voice(44, launch_pitch[frame], launch_gain[frame], $0f)
        write_voice(48, launch_grain[frame], launch_noise[frame], $c0)
    }

    sub render_down(ubyte frame) {
        ubyte waveform = $40
        if frame & 1 != 0 {
            waveform = $25
        }
        write_voice(28, down_pitch[frame], down_gain[frame], waveform)
        write_voice(32, down_grain[frame], down_noise[frame], $c0)
    }

    sub render_start(ubyte frame) {
        write_voice(36, start_pitch[frame], start_gain[frame], $80)
    }

    sub render_wave(ubyte frame) {
        write_voice(52, wave_pitch[frame] + wave_lift, wave_gain[frame], $18)
        write_voice(56, 8600, wave_noise[frame], $c0)
    }

    ; PSG registers are ordinary VERA addresses 1:F9C0 through 1:F9FF.
    ; Preserve the active VERA control and the original DATA0 pointer, even
    ; when drawing code is streaming tiles through DATA0 between effects.
    asmsub write_voice(ubyte offset @R0, uword freq @R1, ubyte volume @X, ubyte shape @Y) clobbers(A) {
        %asm {{
            php
            sei
            lda $9f25
            pha
            stz $9f25
            lda $9f20
            pha
            lda $9f21
            pha
            lda $9f22
            pha
            lda $02
            ora #$c0
            sta $9f20
            lda #$f9
            sta $9f21
            lda #$11
            sta $9f22
            lda $04
            sta $9f23
            lda $05
            sta $9f23
            txa
            ora #$c0
            sta $9f23
            tya
            sta $9f23
            pla
            sta $9f22
            pla
            sta $9f21
            pla
            sta $9f20
            pla
            sta $9f25
            plp
            rts
        }}
    }
}
