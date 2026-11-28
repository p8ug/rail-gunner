; Rail Gunner video for the GameTank.
;
; The game draws on a grid of 40 by 30 cells, as on the Commander X16.  Here
; a cell of the arena is 3 by 4 pixels of the 128 by 128 picture, and what is
; in every cell is kept in a map.  The text around the arena is not cells:
; the screens module draws it.
;
; Two ways of showing things:
;
; - A page of text (after clear() or blackout()) is drawn into the
;   framebuffer that is shown, and changed there in place.
; - The arena (after showGrid()) is drawn with both framebuffers: a frame is
;   drawn into the one that is not shown, and present() flips.  Only the
;   cells that changed are drawn, and since a framebuffer is shown every
;   other frame, those of the frame before are drawn again with them.
;
; The game erases everything that moves and draws it again, every tick.  A
; cell that is erased is only marked; when the same thing is drawn there
; again the mark goes and nothing changed.  What is still marked at the end
; of the tick is empty then.

%import gametank
%import gametank_drawqueue
%import gfx

video {
    %option overlay_data

    ; The tiles have the numbers of the X16 version.  In the sheet, tile n is
    ; column n - 127: tools/gametank/make_assets.py.
    const ubyte SHIP = 128
    const ubyte PULSE = 132
    const ubyte SHARD = 133
    const ubyte TRAIN = 134
    const ubyte PATROL = 135
    const ubyte ARMORED = 136
    const ubyte BOLT = 137
    const ubyte CELL = 138
    const ubyte POD_WAKING = 139
    const ubyte POD_ARMED = 140
    const ubyte RAIL = 141
    const ubyte BAR = 142
    const ubyte BURST = 143
    const ubyte GUN_RIGHT = 145
    const ubyte GUN_UP = 146
    const ubyte RAIL_POD_SEED = 147
    const ubyte RAIL_SHOT_RIGHT = 148
    const ubyte RAIL_SHOT_UP = 149
    const ubyte RAIL_CHARGE = 150
    const ubyte IMPACT_FLASH = 151
    const ubyte IMPACT_SMOKE = 152
    const ubyte IMPACT_FRAGMENT = 153
    const ubyte TRAIN_FLAP = 154
    const ubyte SHIP_WARNING = 155
    const ubyte AMMO_PACK = 156
    const ubyte RESERVE_PACK = 157
    const ubyte BORDER_COLOR = 2

    ; The rows of the grid that are cells here: the arena with its frame.
    const ubyte TOP = 3
    const ubyte ROWS = 25
    ; A cell on the screen: 4 + 3 * column, 2 + 4 * row.
    const ubyte LIST = 128          ; cells in a list of changes

    bool buffering                  ; set by the game for a tick; not needed here
    bool pendingFrame               ; a frame is drawn and waits for present()
    bool arenaShown
    ubyte fullFrames                ; framebuffers that need all of the arena drawn
    ubyte hudFrames, ammoFrames     ; framebuffers that need that part of the HUD drawn
    ubyte lastJiffy
    ubyte putTile, putShade         ; what put stores: where the cell is in the sheet
    ubyte changedCount, previousCount, erasedCount
    const ubyte BLASTS = 36         ; one for every drone
    ubyte[BLASTS] blastX
    ubyte[BLASTS] blastY
    ubyte[BLASTS] blastLife         ; ticks left of its flash; 0 is a free place
    ubyte stampLeft, stampRight, stampBottom

    %asm {{
        .section BSS
        ; two bytes for a cell: its column in the sheet times 4 (0 is empty),
        ; then its row in the sheet times 4, with bit 7 for: erased this tick
        map         .fill 80 * 25
        changedX    .fill 128       ; the cells that changed in this tick
        changedY    .fill 128
        previousX   .fill 128       ; and in the tick before
        previousY   .fill 128
        erasedX     .fill 128       ; the cells that are marked as erased
        erasedY     .fill 128
        .send BSS
    }}

    sub init() {
        ; target.boot() loaded the pictures
        arenaShown = false
        clearMap()
        dbg.step(13)
    }

    sub close() {
    }

    ; ---------------------------------------------------------------- frames

    ; Wait for the next frame.  When the tick took longer than a frame there
    ; is no wait: the game slows down by what it is late, not to half speed.
    sub vsync() {
        dbg.once(22)
        while cbm.TIME_LO == lastJiffy {
        }
        lastJiffy = cbm.TIME_LO
        dbg.once(23)
    }

    sub setup() {
    }

    ; The end of a tick: draw what changed into the framebuffer that is not shown.
    sub flushCells() {
        buffering = false
        sweep()
        if arenaShown {
            render()
            pendingFrame = true
        }
    }

    ; After the wait for the frame: show what flushCells() drew.
    sub present() {
        if pendingFrame {
            gametank.flip_pages()
            keepChanges()
            pendingFrame = false
        }
    }

    sub render() {
        bool all = fullFrames != 0
        if all {
            fullFrames--
            gfx.clearScreen()
        }
        gfx.blitBegin(gfx.tilesSlot, 3, 4)
        if all {
            drawMap()
        } else {
            drawChanges()
        }
        gfx.blitEnd()
        if all {
            screens.paintLabels()
            screens.paintHud()
            screens.paintAmmo()
        } else {
            if hudFrames != 0 {
                hudFrames--
                screens.paintHud()
            }
            if ammoFrames != 0 {
                ammoFrames--
                screens.paintAmmo()
            }
        }
    }

    ; ---------------------------------------------------------------- pages

    ; A black page for text, in view.
    sub blackout() {
        arenaShown = false
        pendingFrame = false
        gfx.toFront()
        dbg.step(16)
        gfx.clearScreen()
        dbg.step(17)
    }

    sub clear() {
        blackout()
    }

    ; Empty the grid.
    sub wipeText() {
        clearMap()
    }

    sub showText() {
    }

    sub prepareArena() {
    }

    ; The arena that the game drew into the grid, in view.
    sub showGrid() {
        gfx.toBack()
        arenaShown = true
        sweep()
        fullFrames = 2
        hudFrames = 0
        ammoFrames = 0
        render()
        gametank.flip_pages()
        keepChanges()
        pendingFrame = false
        lastJiffy = cbm.TIME_LO
    }

    sub enemyTile(ubyte role) -> ubyte {
        if role == 3 {
            return SHARD
        }
        return TRAIN + role
    }

    ; ---------------------------------------------------------------- the grid

    asmsub clearMap() clobbers(A, X) {
        %asm {{
            ldx  #0
-           stz  map,x
            stz  map+256,x
            stz  map+512,x
            stz  map+768,x
            stz  map+1024,x
            stz  map+1280,x
            stz  map+1536,x
            stz  map+1744,x
            inx
            bne  -
            stz  p8v_changedCount
            stz  p8v_previousCount
            stz  p8v_erasedCount
            rts
        }}
    }

    ; Put a tile in a shade (a colour of the X16 version) in a cell.  A tile
    ; below 128 is a character of the X16's text: the empty cell here.
    asmsub cell(ubyte x @R0, ubyte y @R1, ubyte tile @X, ubyte shade @Y) clobbers(A, X, Y) {
        %asm {{
            txa
            bpl  _empty
            sec
            sbc  #127
            asl  a
            asl  a
            sta  p8v_putTile
            tya
            asl  a
            asl  a
            sta  p8v_putShade
            bra  +
_empty      stz  p8v_putTile
            stz  p8v_putShade
+           ldx  cx16.r0L
            ldy  cx16.r1L
            jmp  put
        }}
    }

    ; Erase a cell: the game calls this from assembly, and wants X and Y kept.
    asmsub background(ubyte x @A, ubyte y @Y) clobbers(A) {
        %asm {{
            phx
            tax
            jsr  mark
            plx
            rts
        }}
    }

    %asm {{
; Store putTile and putShade in the cell of column X, row Y, and note the
; cell as changed when that is not what was there.  Keeps X and Y.
put         .proc
            cpy  #p8c_TOP
            bcc  _out
            cpy  #p8c_TOP+p8c_ROWS
            bcs  _out
            lda  rowLo,y
            sta  P8ZP_SCRATCH_W1
            lda  rowHi,y
            sta  P8ZP_SCRATCH_W1+1
            phy
            txa
            sec
            rol  a
            tay                 ; the cell's second byte
            lda  (P8ZP_SCRATCH_W1),y
            bmi  _marked
            cmp  p8v_putShade
            bne  _store
            dey
            lda  (P8ZP_SCRATCH_W1),y
            cmp  p8v_putTile
            beq  _same
            iny
_store      lda  p8v_putShade
            sta  (P8ZP_SCRATCH_W1),y
            dey
            lda  p8v_putTile
            sta  (P8ZP_SCRATCH_W1),y
            ; one more cell that changed; when the list is full, all of the
            ; arena is drawn instead, in both framebuffers
            ldy  p8v_changedCount
            cpy  #p8c_LIST
            bcs  _full
            txa
            sta  changedX,y
            pla
            sta  changedY,y
            inc  p8v_changedCount
            tay
            rts
_full       lda  #2
            sta  p8v_fullFrames
            ply
_out        rts
_marked     and  #$7f
            cmp  p8v_putShade
            bne  _store
            dey
            lda  (P8ZP_SCRATCH_W1),y
            cmp  p8v_putTile
            bne  _differs
            ; what was erased is drawn again: nothing changed
            iny
            lda  p8v_putShade
            sta  (P8ZP_SCRATCH_W1),y
_same       ply
            rts
_differs    iny
            bra  _store
            .pend

; Mark the cell of column X, row Y as erased, when there is something in it.
; Keeps X and Y.
mark        .proc
            cpy  #p8c_TOP
            bcc  _out
            cpy  #p8c_TOP+p8c_ROWS
            bcs  _out
            lda  rowLo,y
            sta  P8ZP_SCRATCH_W1
            lda  rowHi,y
            sta  P8ZP_SCRATCH_W1+1
            phy
            txa
            asl  a
            tay
            lda  (P8ZP_SCRATCH_W1),y
            beq  _done
            iny
            lda  (P8ZP_SCRATCH_W1),y
            bmi  _done
            ora  #$80
            sta  (P8ZP_SCRATCH_W1),y
            ldy  p8v_erasedCount
            cpy  #p8c_LIST
            bcs  _now
            txa
            sta  erasedX,y
            pla
            sta  erasedY,y
            inc  p8v_erasedCount
            tay
            rts
_now        ; no room to remember it: empty at once
            ply
            stz  p8v_putTile
            stz  p8v_putShade
            jmp  put
_done       ply
_out        rts
            .pend

rowLo       .for row := 0, row < 30, row += 1
                .byte <(map + (row - 3) * 80)
            .endfor
rowHi       .for row := 0, row < 30, row += 1
                .byte >(map + (row - 3) * 80)
            .endfor
; the left edge of a column on the screen
columnLeft  .for column := 0, column < 40, column += 1
                .byte 4 + column * 3
            .endfor
    }}

    ; The cells that are still marked as erased are empty now.
    asmsub sweep() clobbers(A, X, Y) {
        %asm {{
            stz  p8v_putTile
            stz  p8v_putShade
            lda  p8v_erasedCount
            beq  _done
_next       dec  p8v_erasedCount
            ldx  p8v_erasedCount
            ldy  erasedY,x
            lda  rowLo,y
            sta  P8ZP_SCRATCH_W1
            lda  rowHi,y
            sta  P8ZP_SCRATCH_W1+1
            lda  erasedX,x
            tax
            sec
            rol  a
            sty  P8ZP_SCRATCH_REG
            tay
            lda  (P8ZP_SCRATCH_W1),y
            bpl  +
            ldy  P8ZP_SCRATCH_REG
            jsr  put
+           lda  p8v_erasedCount
            bne  _next
_done       rts
        }}
    }

    ; After a flip: this tick's changes are the previous ones for the other
    ; framebuffer.
    asmsub keepChanges() clobbers(A, X) {
        %asm {{
            ldx  p8v_changedCount
            stx  p8v_previousCount
            beq  _done
-           lda  changedX-1,x
            sta  previousX-1,x
            lda  changedY-1,x
            sta  previousY-1,x
            dex
            bne  -
            stz  p8v_changedCount
_done       rts
        }}
    }

    ; ---------------------------------------------------------------- blits
    ; (between gfx.blitBegin() and gfx.blitEnd())

    %asm {{
; Blit the cell of column X, row Y from the sheet.  Keeps X and Y.
blitCell    .proc
            lda  rowLo,y
            sta  P8ZP_SCRATCH_W1
            lda  rowHi,y
            sta  P8ZP_SCRATCH_W1+1
            lda  columnLeft,x
            sta  gametank.BLIT_VX
            tya
            asl  a
            asl  a
            inc  a
            inc  a
            sta  gametank.BLIT_VY
            sty  P8ZP_SCRATCH_REG
            txa
            asl  a
            tay
            lda  (P8ZP_SCRATCH_W1),y
            ora  p8b_gfx.p8v_tilesX
            sta  gametank.BLIT_GX
            iny
            lda  (P8ZP_SCRATCH_W1),y
            and  #$7f
            ora  p8b_gfx.p8v_tilesY
            sta  gametank.BLIT_GY
            lda  #1
            sta  gametank.BLIT_START
            ldy  P8ZP_SCRATCH_REG
            rts
            .pend
    }}

    asmsub drawChanges() clobbers(A, X, Y) {
        %asm {{
            lda  p8v_previousCount
            beq  _now
            sta  P8ZP_SCRATCH_B1
-           dec  P8ZP_SCRATCH_B1
            ldx  P8ZP_SCRATCH_B1
            ldy  previousY,x
            lda  previousX,x
            tax
            jsr  blitCell
            lda  P8ZP_SCRATCH_B1
            bne  -
_now        lda  p8v_changedCount
            beq  _done
            sta  P8ZP_SCRATCH_B1
-           dec  P8ZP_SCRATCH_B1
            ldx  P8ZP_SCRATCH_B1
            ldy  changedY,x
            lda  changedX,x
            tax
            jsr  blitCell
            lda  P8ZP_SCRATCH_B1
            bne  -
_done       rts
        }}
    }

    asmsub drawMap() clobbers(A, X, Y) {
        %asm {{
            ldy  #p8c_TOP
_row        ldx  #0
-           jsr  blitCell
            inx
            cpx  #40
            bcc  -
            iny
            cpy  #p8c_TOP+p8c_ROWS
            bcc  _row
            rts
        }}
    }

    ; ---------------------------------------------------------------- blasts
    ; As in the X16 version, a blast flashes in its three by three cells for
    ; ten ticks.  There a count is kept for every cell of the arena; here,
    ; with 6 KB of RAM, the blasts themselves are kept, which is the same to
    ; look at: a cell flashes as long as a blast that covers it lasts.

    asmsub clearBlasts() clobbers(A, X) {
        %asm {{
            ldx  #p8c_BLASTS-1
-           stz  p8v_blastLife,x
            dex
            bpl  -
            rts
        }}
    }

    ; A blast around a cell.
    asmsub stampBlast(ubyte x @X, ubyte y @Y) clobbers(A, X, Y) {
        %asm {{
            stx  P8ZP_SCRATCH_B1
            ldx  #p8c_BLASTS-1
-           lda  p8v_blastLife,x
            beq  _free
            dex
            bpl  -
            rts                 ; more blasts than can be shown: this one does not flash
_free       lda  P8ZP_SCRATCH_B1
            sta  p8v_blastX,x
            tya
            sta  p8v_blastY,x
            lda  #11            ; ten visible ticks, then one to clear
            sta  p8v_blastLife,x
            rts
        }}
    }

    ; Draw the cells that flash, and count the blasts down when advance.
    asmsub drawBlasts(bool advance @A) clobbers(A, X, Y) {
        %asm {{
            cmp  #0
            beq  _draw
            ; the blasts that are over leave empty cells; one that still
            ; lasts draws over them again below
            stz  p8v_putTile
            stz  p8v_putShade
            ldx  #p8c_BLASTS-1
_age        lda  p8v_blastLife,x
            beq  +
            dec  p8v_blastLife,x
            bne  +
            jsr  blastCells
+           dex
            bpl  _age
_draw       lda  #(p8c_IMPACT_FLASH - 127) * 4
            sta  p8v_putTile
            lda  #8 * 4
            sta  p8v_putShade
            ldx  #p8c_BLASTS-1
_flash      lda  p8v_blastLife,x
            beq  +
            jsr  blastCells
+           dex
            bpl  _flash
            rts
        }}
    }

    %asm {{
; Put putTile and putShade in the cells of blast X, inside the arena.  Keeps X.
blastCells  .proc
            phx
            lda  p8v_blastY,x
            tay
            inc  a
            cmp  #27
            bcc  +
            lda  #26
+           sta  p8v_stampBottom
            dey
            cpy  #4
            bcs  +
            ldy  #4
+           lda  p8v_blastX,x
            tax
            inc  a
            cmp  #39
            bcc  +
            lda  #38
+           sta  p8v_stampRight
            dex
            bne  +
            inx
+           stx  p8v_stampLeft
_row        ldx  p8v_stampLeft
_column     jsr  put
            cpx  p8v_stampRight
            beq  +
            inx
            bra  _column
+           cpy  p8v_stampBottom
            beq  +
            iny
            bra  _row
+           plx
            rts
            .pend
    }}
}
