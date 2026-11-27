; Rail Gunner sound effects for the GameTank: the SDK's player gives an
; effect one of the four FM channels, and the music has it back afterwards.
;
; Shots, hits and blasts take the channel of the drums; everything else
; takes the channel of the lead.  On a channel an effect is not started
; while a more important one plays.
%import gametank
%import sfx_data

audio {
    %option overlay_data

    const ubyte IMPACTS = 3         ; channels
    const ubyte SIGNALS = 1
    const ubyte MINOR = 0           ; importance, as the SDK takes it
    const ubyte NORMAL = 1 << 4
    const ubyte MAJOR = 2 << 4
    const ubyte URGENT = 3 << 4

    sub init() {
    }

    ; An effect is a few frames long: it is left to end.
    sub silence() {
    }

    ; The music's tick moves the effects along too: music.tick().
    sub tick() {
    }

    sub play(uword effect, ubyte channel) {
        gametank.play_sound_effect(effect, banks.ASSETS, channel)
    }

    sub menu() {
        play(&sfxdata.menu, SIGNALS | MINOR)
    }

    sub dry() {
        play(&sfxdata.dry, SIGNALS | NORMAL)
    }

    sub pickup() {
        play(&sfxdata.pickup, SIGNALS | NORMAL)
    }

    sub shot() {
        play(&sfxdata.shot, IMPACTS | MINOR)
    }

    sub hit() {
        play(&sfxdata.hit, IMPACTS | NORMAL)
    }

    sub blast() {
        play(&sfxdata.blast, IMPACTS | MAJOR)
    }

    sub warn() {
        play(&sfxdata.warn, SIGNALS | NORMAL)
    }

    sub launch() {
        play(&sfxdata.launch, SIGNALS | NORMAL)
    }

    sub down() {
        play(&sfxdata.down, IMPACTS | URGENT)
    }

    sub start() {
        play(&sfxdata.start, SIGNALS | MAJOR)
    }

    sub waveCue(bool higher) {
        if higher {
            play(&sfxdata.wave_high, SIGNALS | MAJOR)
        } else {
            play(&sfxdata.wave_low, SIGNALS | MAJOR)
        }
    }
}
