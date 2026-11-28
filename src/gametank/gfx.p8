; Drawing with the GameTank's blitter, for every part of Rail Gunner.
;
; This block is in the fixed bank and is called from the banks with their
; own bank left in place (overlay_safe), so a string that is in a bank can
; be printed from there.  It never changes banks itself; loading the sheets
; is left to the library.
;
; Two sprite sheets are loaded: the cells of the arena with the pictures of
; the title page, and a 3 x 5 pixel font in ten colours.  The library's own
; 8 x 8 font is there too, for headings.
;
; A blit here is started and left to finish while the next one is prepared:
; at one pixel per cycle a cell (12 pixels) or a character (24) is done long
; before the code gets to its next blit.  The blitter's interrupt is off
; meanwhile, and the draw queue is waited for first.

%import gametank
%import gametank_draw
%import gametank_sprites
%import gametank_drawqueue
%import gametank_text
%import gfxdata

gfx {
    %option overlay_safe

    ubyte tilesSlot, fontSlot
    ubyte tilesX, tilesY        ; where a sheet is in its page of sprite ram: 0 or 128
    ubyte fontX, fontY
    bool front                  ; drawing goes to the framebuffer that is shown
    ubyte penX, originX, originY
    ubyte[12] number            ; the digits of digits() and score()

    ; where the font of a shade (a colour of the X16 version, 0-15) is in the
    ; font sheet; tools/gametank/make_assets.py has the list of the ten that exist
    ubyte[16] fontLeft = [0, 0, 64, 0, 0, 64, 0, 64, 0, 0, 64, 0, 64, 64, 0, 64]
    ubyte[16] fontTop = [0, 0, 0, 24, 0, 72, 96, 24, 48, 48, 48, 72, 96, 72, 96, 96]

    uword[5] decimalPlace = [1, 10, 100, 1000, 10000]
    long[9] scorePlaces = [100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1]

    sub init() {
        gametank.text_init()
        dbg.step(3)
        void gametank.text_load_font()
        dbg.step(4)
        tilesSlot = gametank.allocate_sprite(&gfxdata.tiles, banks.ASSETS)
        gametank.set_sprite_frametable(tilesSlot, &gfxdata.frames, banks.ASSETS)
        dbg.step(5)
        fontSlot = gametank.allocate_sprite(&gfxdata.font, banks.ASSETS)
        dbg.step(6)
        tilesX = (tilesSlot & gametank.SPRITE_OFFSET_X_MASK) << 4
        tilesY = (tilesSlot & gametank.SPRITE_OFFSET_Y_MASK) << 3
        fontX = (fontSlot & gametank.SPRITE_OFFSET_X_MASK) << 4
        fontY = (fontSlot & gametank.SPRITE_OFFSET_Y_MASK) << 3
        front = false
    }

    ; Draw to the framebuffer that is shown, for a page that is built up in
    ; view and changed in place: no flip_pages() until toBack().
    sub toFront() {
        if not front {
            gametank.await_draw_queue()
            gametank.bankflip ^= gametank.BANK_SECOND_FRAMEBUFFER
            front = true
        }
    }

    ; Draw to the framebuffer that is not shown, as flip_pages() expects.
    sub toBack() {
        if front {
            gametank.await_draw_queue()
            gametank.bankflip ^= gametank.BANK_SECOND_FRAMEBUFFER
            front = false
        }
    }

    ; All of the picture black, through the draw queue.
    sub clearScreen() {
        gametank.queue_clear_border(0)
        gametank.queue_clear_screen(0)
        gametank.await_draw_queue()
    }

    ; Set the blitter for blits of w * h pixels from a sprite slot that are
    ; started one after another, color 0 drawn too.  blitEnd() afterwards.
    sub blitBegin(ubyte slot, ubyte w, ubyte h) {
        gametank.await_draw_queue()
        gametank.DMAFLAGS = (gametank.flagsMirror | gametank.DMA_ENABLE | gametank.DMA_GCARRY | gametank.DMA_OPAQUE) & ~(gametank.DMA_COLORFILL | gametank.DMA_IRQ)
        gametank.banksMirror = gametank.bankflip | (slot & gametank.BANK_GRAM_MASK) | gametank.CLIP_MODE_XY
        gametank.BANKREG = gametank.banksMirror
        gametank.BLIT_WIDTH = w
        gametank.BLIT_HEIGHT = h
    }

    ; The last blit is left to finish, then the blitter is the library's again.
    asmsub blitEnd() clobbers(A, X) {
        %asm {{
            ldx  #6
-           dex
            bne  -
            lda  gametank.flagsMirror
            sta  gametank.DMAFLAGS
            rts
        }}
    }

    ; Print in the 3 x 5 font, 4 pixels to a character, at a pixel position.
    ; The shade is a colour of the X16 version.  The 4 x 6 pixels of a
    ; character are all drawn, so text replaces what was there.
    sub text(ubyte x, ubyte y, ubyte shade, str message) {
        penX = x
        originX = fontX | fontLeft[shade & 15]
        originY = fontY + fontTop[shade & 15]
        blitBegin(fontSlot, 4, 6)
        gametank.BLIT_VY = y
        puts(message)
        blitEnd()
    }

    asmsub puts(str message @AY) clobbers(A, X, Y) {
        %asm {{
            sta  P8ZP_SCRATCH_W1
            sty  P8ZP_SCRATCH_W1+1
            ldy  #0
_next       lda  (P8ZP_SCRATCH_W1),y
            beq  _done
            cmp  #96
            bcc  +
            sbc  #32            ; small letters as capitals
+           sec
            sbc  #32
            and  #63
            tax
            and  #15
            asl  a
            asl  a
            ora  p8v_originX
            sta  gametank.BLIT_GX
            txa
            lsr  a
            lsr  a
            lsr  a
            lsr  a
            tax
            lda  _rows,x
            clc
            adc  p8v_originY
            sta  gametank.BLIT_GY
            lda  p8v_penX
            sta  gametank.BLIT_VX
            clc
            adc  #4
            sta  p8v_penX
            lda  #1
            sta  gametank.BLIT_START
            iny
            bne  _next
_done       rts
_rows       .byte 0, 6, 12, 18
            ; !notreached!
        }}
    }

    ; One character.
    sub glyph(ubyte x, ubyte y, ubyte shade, ubyte character) {
        number[0] = character
        number[1] = 0
        text(x, y, shade, &number)
    }

    ; The last count digits of a value as text, in number.
    sub format(uword value, ubyte count) -> uword {
        ubyte place = 5
        ubyte at = 0
        repeat 5 {
            place--
            uword divisor = decimalPlace[place]
            ubyte digit = '0'
            while value >= divisor {
                value -= divisor
                digit++
            }
            if place < count {
                number[at] = digit
                at++
            }
        }
        number[at] = 0
        return &number
    }

    ; The nine digits of a score as text, in number.
    sub formatScore(long value) -> uword {
        ubyte place
        for place in 0 to 8 {
            long divisor = scorePlaces[place]
            ubyte digit = '0'
            while value >= divisor {
                value -= divisor
                digit++
            }
            number[place] = digit
        }
        number[9] = 0
        return &number
    }

    sub digits(ubyte x, ubyte y, ubyte shade, uword value, ubyte count) {
        text(x, y, shade, format(value, count))
    }

    sub score(ubyte x, ubyte y, ubyte shade, long value) {
        text(x, y, shade, formatScore(value))
    }

    ; A heading in the library's 8 x 8 font, white, on top of what is there.
    sub heading(ubyte x, ubyte y, str message) {
        gametank.text_color = gametank.TEXT_COLOR_WHITE
        gametank.text_cursor_x = x
        gametank.text_cursor_y = y
        gametank.text_print_string(message)
    }

    ; One of the 16 x 16 pictures, around a position, through the draw queue.
    sub picture(ubyte frame, ubyte x, ubyte y, ubyte flip) {
        gametank.queue_draw_sprite_frame(tilesSlot, x, y, frame, flip)
    }

    ; A cell of the arena (tools/gametank/make_assets.py numbers them) in a
    ; shade, at a pixel position, through the draw queue.
    sub tile(ubyte x, ubyte y, ubyte index, ubyte shade) {
        gametank.queue_draw_sprite(x, y, 3, 4, index << 2, shade << 2, tilesSlot)
    }
}
