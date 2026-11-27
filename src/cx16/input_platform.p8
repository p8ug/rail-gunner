input {
    const ubyte UP = 1
    const ubyte DOWN = 2
    const ubyte LEFT = 4
    const ubyte RIGHT = 8
    const ubyte FIRE = 16
    const ubyte START = 32
    const ubyte QUIT = 64
    const ubyte SELECT = 128
    ; QUIT on the title page ends the program: there is a BASIC prompt to go back to.
    const bool CAN_EXIT = true

    asmsub init() clobbers(A, X) {
        %asm {{
            php
            sei
            lda hook_installed
            bne _done
            ldx #key_count-1
        _clear
            stz pressed_keys,x
            dex
            bpl _clear
            lda key_vector
            sta old_handler
            lda key_vector+1
            sta old_handler+1
            lda #<keyboard_event
            sta key_vector
            lda #>keyboard_event
            sta key_vector+1
            inc hook_installed
        _done
            plp
            rts
        }}
    }

    asmsub shutdown() clobbers(A, X, Y) {
        %asm {{
            php
            sei
            lda hook_installed
            beq _done
            lda old_handler
            sta key_vector
            lda old_handler+1
            sta key_vector+1
            stz hook_installed
            lda #$13          ; KERNAL kbdbuf_clear
            jsr $feab
        _done
            plp
            rts
        }}
    }

    asmsub poll() clobbers(X, Y) -> ubyte @A {
        %asm {{
            ; Merge connected physical pads. The standard KERNAL IRQ scans them.
            lda #$ff
            sta pad_buttons
            lda #4
            sta pad_index
        _port
            lda pad_index
            jsr $ff56         ; joystick_get: active-low buttons in A, present in Y
            cpy #0
            bne _next
            and pad_buttons
            sta pad_buttons
        _next
            dec pad_index
            bne _port

            lda pad_buttons
            eor #$ff
            tax
            and #$0f
            tay
            txa
            lsr a
            lsr a
            lsr a
            lsr a
            tax
            lda directions,y
            ora actions,x
            ldx #key_count-1
        _keys
            ora pressed_keys,x
            dex
            bpl _keys
            rts
        }}
    }

    %asm {{
    key_vector = $032e
    hook_installed .byte 0
    old_handler .word 0
    pad_buttons .byte 0
    pad_index .byte 0

    ; IBM keyboard positions, independent of the selected PETSCII keymap.
    key_codes .byte $02,$01,$3a,$03,$3d,$2b,$6e,$10,$53,$54,$4f,$59
    key_count = *-key_codes
    key_masks .byte $01,$02,$04,$08,$10,$20,$40,$80,$01,$02,$04,$08
    pressed_keys .fill key_count,0
    directions .byte 0,8,4,12,2,10,6,14,1,9,5,13,3,11,7,15
    actions .byte 0,32,128,160,0,32,128,160,16,48,144,176,16,48,144,176

    keyboard_event
        ; Preserve the KERNAL's incoming registers and status when chaining.
        php
        pha
        phx
        phy
        tay
        and #$7f
        ldx #key_count-1
    _find
        cmp key_codes,x
        beq _found
        dex
        bpl _find
        bra _chain
    _found
        tya
        bmi _released
        lda key_masks,x
        bra _save
    _released
        lda #0
    _save
        sta pressed_keys,x
    _chain
        ply
        plx
        pla
        plp
        jmp (old_handler)
    }}
}
