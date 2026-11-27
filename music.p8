%import music_data

music {
    uword cursor
    ubyte delay
    bool playing

    sub init() {
        stop()
    }

    sub start() {
        cursor = &music_data.track + 16
        delay = 0
        playing = true
    }

    sub stop() {
        playing = false
        ubyte voice
        for voice in 0 to 7 {
            ymWrite(8, voice)
        }
        ymWrite(15, 0)
    }

    ; The embedded arrangement is generated as an FM-only, looping 60 Hz ZSM.
    sub tick() {
        if not playing {
            return
        }
        if delay != 0 {
            delay--
            if delay != 0 {
                return
            }
        }
        repeat {
            ubyte command = @(cursor)
            cursor++
            if command == $80 {
                cursor = &music_data.track + 16
            } else if command > $80 {
                delay = command & $7f
                return
            } else {
                repeat command & $3f {
                    ubyte reg = @(cursor)
                    cursor++
                    ymWrite(reg, @(cursor))
                    cursor++
                }
            }
        }
    }

    asmsub ymWrite(ubyte reg @X, ubyte value @A) {
        %asm {{
        _wait:
            bit $9f41
            bmi _wait
            stx $9f40
            sta $9f41
            rts
        }}
    }
}
