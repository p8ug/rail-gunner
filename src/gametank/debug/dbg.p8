; Marks on the screen that say how far the program got, for a console that
; does not get to the title page.  `make debug` builds with this file in
; place of src/gametank/dbg.p8: build/gametank-debug/rail_gunner.gtr.
;
; step(n) lights block n: a square of 5 pixels, sixteen to a row, the first
; row for 0-15, in the middle of the picture.  The CPU writes it into both
; framebuffers itself, so it shows whatever the blitter, its interrupt and
; the draw queue do.  All blocks that were lit are drawn again with every
; step, because a page that is cleared takes them away.
;
;   green   the step was reached
;   white   it was reached, but a blit that the library started had not
;           ended after a third of a second: its interrupt did not come
;   yellow  a note, not a step (32 and up: the third row)
;
; The steps, each lit when what it names is done:
;    1 sdk_init (the logo)           2 init_graphics
;    3 text_init                     4 the library's font loaded
;    5 the tiles sheet loaded        6 the 3 x 5 font sheet loaded
;    7 input.init                    8 audio.init
;    9 reading save slot 0 begins   10 reading save slot 1 begins
;   11 slot 0's sector searched     12 slot 1's sector searched
;   13 video.init                   14 music.init
;   15 pages.title begins           16 drawing set to the shown framebuffer
;   17 the screen cleared           18 the heading printed
;   19 the pictures drawn           20 the menu's text printed
;   21 the title page complete      22 the first wait for a frame begins
;   23 the frame came               24 the gamepads were read
; The notes:
;   32, 33  save slot 0, 1 is not empty
;   34, 35  and its last record has length 0: not of this game
%import gametank
%import gametank_banking
%import gametank_drawqueue
%import gametank_text
%import gametank_input

dbg {
    %option overlay_safe

    const ubyte BLOCKS = 48
    const ubyte REACHED = $fc
    const ubyte LATE = $07
    const ubyte NOTE = $1f

    ubyte[BLOCKS] marks

    sub step(ubyte n) {
        ubyte colour = REACHED
        if n >= 32 {
            colour = NOTE
        }
        uword tries = 0
        while gametank.draw_busy {
            tries++
            if tries == 60000 {
                colour = LATE
                break
            }
        }
        marks[n] = colour
        show()
    }

    ; What the console reads from the banks of the program, before the first
    ; call into one: a line for each of the banks 128-130 with its number,
    ; its first four bytes and the sum of its 16,384 bytes, all in hex, then
    ; the same again read a second time.  `make debug` prints what the lines
    ; have to be.  It stays until a button is pressed.
    ubyte[17] line
    ubyte[] hex = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F']
    ubyte[4 * 6] heads
    uword[6] sums
    ubyte at

    sub put(ubyte value) {
        line[at] = hex[value >> 4]
        line[at + 1] = hex[value & 15]
        at += 2
    }

    sub started(uword buttons) -> bool {
        return buttons & gametank.INPUT_MASK_START != 0 and buttons & $0c0c != $0c0c
    }

    sub report() {
        ubyte n
        for n in 0 to 5 {
            ubyte bank = 128 + n
            if n >= 3 {
                bank -= 3
            }
            gametank.push_rom_bank()
            gametank.change_rom_bank(bank)
            uword sum = 0
            uword p
            for p in $8000 to $bfff {
                sum += @(p)
            }
            sums[n] = sum
            heads[n * 4] = @($8000)
            heads[n * 4 + 1] = @($8001)
            heads[n * 4 + 2] = @($8002)
            heads[n * 4 + 3] = @($8003)
            gametank.pop_rom_bank()
        }
        repeat 2 {
            gametank.queue_clear_border(0)
            gametank.queue_clear_screen(0)
            gametank.await_draw_queue()
            gametank.text_color = gametank.TEXT_COLOR_WHITE
            for n in 0 to 5 {
                at = 0
                if n >= 3 {
                    put(125 + n)
                } else {
                    put(128 + n)
                }
                line[2] = ' '
                at = 3
                put(heads[n * 4])
                put(heads[n * 4 + 1])
                put(heads[n * 4 + 2])
                put(heads[n * 4 + 3])
                line[11] = ' '
                at = 12
                put(msb(sums[n]))
                put(lsb(sums[n]))
                line[16] = 0
                gametank.text_cursor_x = 0
                gametank.text_cursor_y = 8 + n * 8
                gametank.text_print_string(&line)
            }
            gametank.flip_pages()
        }
        show()
        ; Below them, what the library reads from the two gamepads, as it
        ; changes: player1_buttons, then player2_buttons.  START on either
        ; pad goes on (a port with nothing in it may read as anything, so
        ; not with up and down at once), and so do 40 seconds.
        uword frames = 0
        repeat {
            gametank.await_vsync(1)
            gametank.update_inputs()
            gametank.queue_draw_box(0, 80, 127, 8, 0)
            gametank.await_draw_queue()
            at = 0
            put(msb(gametank.player1_buttons))
            put(lsb(gametank.player1_buttons))
            line[4] = ' '
            at = 5
            put(msb(gametank.player2_buttons))
            put(lsb(gametank.player2_buttons))
            line[9] = 0
            gametank.text_cursor_x = 8
            gametank.text_cursor_y = 80
            gametank.text_print_string(&line)
            gametank.flip_pages()
            frames++
            if frames == 2400 {
                break
            }
            if frames > 30 and started(gametank.player1_buttons) or started(gametank.player2_buttons) {
                break
            }
        }
    }

    ; For what is called every frame: only the first time.
    sub once(ubyte n) {
        if marks[n] == 0 {
            step(n)
        }
    }

    asmsub show() clobbers(A, X, Y) {
        %asm {{
            php
            sei
            lda  gametank.flagsMirror
            and  #~(gametank.DMA_ENABLE | gametank.DMA_IRQ) & 255
            ora  #gametank.DMA_CPU_TO_VRAM
            sta  gametank.DMAFLAGS
            lda  gametank.banksMirror
            and  #~gametank.BANK_SECOND_FRAMEBUFFER & 255
            sta  gametank.BANKREG
            jsr  _paint
            lda  gametank.banksMirror
            ora  #gametank.BANK_SECOND_FRAMEBUFFER
            sta  gametank.BANKREG
            jsr  _paint
            lda  gametank.banksMirror
            sta  gametank.BANKREG
            lda  gametank.flagsMirror
            sta  gametank.DMAFLAGS
            plp
            rts

_paint      ldx  #p8c_BLOCKS-1
_block      lda  p8v_marks,x
            beq  _skip
            sta  P8ZP_SCRATCH_B1
            lda  _low,x
            sta  P8ZP_SCRATCH_W1
            lda  _high,x
            sta  P8ZP_SCRATCH_W1+1
            lda  #5
            sta  P8ZP_SCRATCH_REG
_row        ldy  #4
            lda  P8ZP_SCRATCH_B1
-           sta  (P8ZP_SCRATCH_W1),y
            dey
            bpl  -
            lda  P8ZP_SCRATCH_W1
            clc
            adc  #128
            sta  P8ZP_SCRATCH_W1
            bcc  +
            inc  P8ZP_SCRATCH_W1+1
+           dec  P8ZP_SCRATCH_REG
            bne  _row
_skip       dex
            bpl  _block
            rts

; where block n is in a framebuffer: 8 + 7 * (n & 15), 56 + 8 * (n / 16)
_low        .for n := 0, n < p8c_BLOCKS, n += 1
                .byte <($4000 + (56 + 8 * (n / 16)) * 128 + 8 + 7 * (n & 15))
            .endfor
_high       .for n := 0, n < p8c_BLOCKS, n += 1
                .byte >($4000 + (56 + 8 * (n / 16)) * 128 + 8 + 7 * (n & 15))
            .endfor
            ; !notreached!
        }}
    }
}
