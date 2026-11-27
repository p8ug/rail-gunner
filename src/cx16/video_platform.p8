%import syslib

video {
    const ubyte SHIP = 128
    const ubyte GRID_CELL = 129
    const ubyte GRID_RIGHT = 130
    const ubyte GRID_BOTTOM = 131
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
    const ubyte GRID_CORNER = 144
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
    const ubyte RESERVE_PACK = 43
    const ubyte BORDER_COLOR = 2
    const ubyte GRID_COLOR = 5
    const uword GRID_PALETTE_ADDR = $fa00 + GRID_COLOR * 2

    ubyte oldMode, oldBorder, oldGridColorLo, oldGridColorHi
    ubyte oldTiles, oldTextMap
    ubyte oldGridConfig, oldGridMap, oldGridTiles, oldVideo
    uword oldGridX, oldGridY
    ubyte[232] art = [
        $00,$10,$38,$38,$7c,$7c,$54,$28,
        $ff,$80,$80,$80,$80,$80,$80,$80,
        $80,$80,$80,$80,$80,$80,$80,$80,
        $ff,$00,$00,$00,$00,$00,$00,$00,
        $18,$3c,$3c,$3c,$18,$18,$08,$00,
        $00,$08,$14,$2a,$54,$28,$10,$00,
        $24,$42,$db,$ff,$7e,$7e,$66,$18,
        $18,$3c,$7e,$db,$ff,$42,$a5,$00,
        $7e,$db,$ff,$3c,$3c,$ff,$db,$7e,
        $00,$00,$24,$18,$18,$24,$00,$00,
        $00,$18,$24,$5a,$5a,$24,$18,$00,
        $00,$18,$3c,$5a,$66,$3c,$18,$00,
        $00,$18,$3c,$7e,$66,$7e,$24,$00,
        $24,$24,$24,$24,$24,$24,$24,$24,
        $00,$00,$00,$ff,$ff,$00,$00,$00,
        $81,$24,$5a,$18,$18,$5a,$24,$81,
        $80,$00,$00,$00,$00,$00,$00,$00,
        $00,$70,$f0,$fe,$fe,$f0,$70,$00,
        $00,$18,$18,$18,$7e,$ff,$ff,$00,
        $00,$7e,$42,$5a,$42,$24,$18,$00,
        $00,$08,$1c,$7e,$7e,$1c,$08,$00,
        $00,$18,$3c,$7e,$3c,$18,$18,$00,
        $00,$66,$66,$3c,$3c,$18,$18,$00,
        $81,$5a,$3c,$ff,$ff,$3c,$5a,$81,
        $00,$42,$00,$18,$18,$00,$42,$00,
        $00,$00,$20,$18,$18,$04,$00,$00,
        $00,$24,$5a,$7e,$3c,$3c,$24,$18,
        $c3,$91,$38,$38,$7c,$7c,$d5,$eb,
        $00,$7e,$42,$5a,$7e,$5a,$42,$7e
    ]

    sub init() {
        ubyte i
        ubyte unusedX, unusedY
        oldMode, unusedX, unusedY = cx16.get_screen_mode()
        cx16.VERA_CTRL = 0
        oldBorder = cx16.VERA_DC_BORDER
        cx16.set_screen_mode(3)
        oldTiles = cx16.VERA_L1_TILEBASE
        oldTextMap = cx16.VERA_L1_MAPBASE
        cx16.VERA_L1_MAPBASE = $d8

        ; Build a private character set in VERA RAM using the current ROM font.
        cx16.VERA_CTRL = 0
        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = (oldTiles & $fc) << 1
        cx16.VERA_ADDR_H = $10 | (oldTiles >> 7)
        cx16.VERA_CTRL = 1
        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = 0
        cx16.VERA_ADDR_H = $11
        repeat 2048 {
            cx16.VERA_DATA1 = cx16.VERA_DATA0
        }
        cx16.VERA_CTRL = 0
        cx16.VERA_ADDR_H = $11
        cx16.VERA_ADDR_M = 4
        cx16.VERA_ADDR_L = 0
        for i in 0 to len(art)-1 {
            cx16.VERA_DATA0 = art[i]
        }
        cx16.VERA_L1_TILEBASE = $80
        oldVideo = cx16.VERA_DC_VIDEO
        oldGridConfig = cx16.VERA_L0_CONFIG
        oldGridMap = cx16.VERA_L0_MAPBASE
        oldGridTiles = cx16.VERA_L0_TILEBASE
        oldGridX = cx16.VERA_L0_HSCROLL
        oldGridY = cx16.VERA_L0_VSCROLL
        cx16.VERA_ADDR_H = $11
        cx16.VERA_ADDR = GRID_PALETTE_ADDR
        oldGridColorLo = cx16.VERA_DATA0
        oldGridColorHi = cx16.VERA_DATA0
        cx16.VERA_ADDR = GRID_PALETTE_ADDR
        cx16.VERA_DATA0 = $c6
        cx16.VERA_DATA0 = $0c
        loadGrid()
    }

    sub loadGrid() {
        ubyte x, y
        ; Layer 0 stays in VRAM while the game draws transparent objects on L1.
        cx16.VERA_DC_VIDEO = oldVideo & $ef
        cx16.VERA_L0_CONFIG = $10
        cx16.VERA_L0_MAPBASE = $84
        cx16.VERA_L0_TILEBASE = $80
        cx16.VERA_L0_HSCROLL = 0
        cx16.VERA_L0_VSCROLL = 0
        cx16.VERA_ADDR_H = $11
        cx16.VERA_ADDR = $0800
        for y in 0 to 31 {
            for x in 0 to 63 {
                ubyte tile = 32
                if x >= 1 and x <= 39 and y >= 4 and y <= 27 {
                    tile = GRID_CELL
                    if y == 27 {
                        tile = GRID_BOTTOM
                        if x == 39 {
                            tile = GRID_CORNER
                        }
                    } else if x == 39 {
                        tile = GRID_RIGHT
                    }
                }
                cx16.VERA_DATA0 = tile
                cx16.VERA_DATA0 = GRID_COLOR
            }
        }
    }

    sub showGrid() {
        cx16.VERA_DC_VIDEO = oldVideo | $10
    }

    sub close() {
        cx16.VERA_CTRL = 0
        cx16.VERA_DC_VIDEO = oldVideo
        cx16.VERA_L0_CONFIG = oldGridConfig
        cx16.VERA_L0_MAPBASE = oldGridMap
        cx16.VERA_L0_TILEBASE = oldGridTiles
        cx16.VERA_L0_HSCROLL = oldGridX
        cx16.VERA_L0_VSCROLL = oldGridY
        cx16.VERA_L1_MAPBASE = oldTextMap
        cx16.VERA_L1_TILEBASE = oldTiles
        cx16.VERA_ADDR_H = $11
        cx16.VERA_ADDR = GRID_PALETTE_ADDR
        cx16.VERA_DATA0 = oldGridColorLo
        cx16.VERA_DATA0 = oldGridColorHi
        cx16.set_screen_mode(oldMode)
        cx16.VERA_CTRL = 0
        cx16.VERA_DC_BORDER = oldBorder
    }

    %asm {{
        .section BSS
        blastTiles .fill 920
        blastRows  .fill 30
        .send BSS
    }}

    asmsub clearBlasts() clobbers(A, X) {
        %asm {{
            ldx #0
        _clear:
            stz blastTiles,x
            stz blastTiles+256,x
            stz blastTiles+512,x
            stz blastTiles+664,x
            inx
            bne _clear
            ldx #29
        _rows:
            stz blastRows,x
            dex
            bpl _rows
            rts
        }}
    }

    asmsub markBlast(ubyte x @X, ubyte y @Y) clobbers(A) {
        %asm {{
            lda _lo,y
            sta _spot+1
            sta _stamp+1
            lda _hi,y
            sta _spot+2
            sta _stamp+2
        _spot:
            lda blastTiles,x
            bne _active
            lda blastRows,y
            inc a
            sta blastRows,y
        _active:
            lda #11           ; Ten visible ticks, then one to clear.
        _stamp:
            sta blastTiles,x
            rts
        _lo:
            .for row := 0, row < 27, row += 1
                .byte <(blastTiles+(row-4)*40)
            .endfor
        _hi:
            .for row := 0, row < 27, row += 1
                .byte >(blastTiles+(row-4)*40)
            .endfor
            ; !notreached!
        }}
    }

    asmsub stampBlast(ubyte x @X, ubyte y @Y) clobbers(A, X, Y) {
        %asm {{
            ; Limit the three-by-three footprint to the playable grid.
            txa
            inc a
            cmp #39
            bcc _right
            lda #38
        _right:
            sta _endX
            dex
            bne _left
            inx
        _left:
            stx _startX
            tya
            inc a
            cmp #27
            bcc _bottom
            lda #26
        _bottom:
            sta _endY
            dey
            cpy #4
            bcs _row
            ldy #4
        _row:
            ldx _startX
        _column:
            jsr p8s_markBlast
            cpx _endX
            beq _nextRow
            inx
            bra _column
        _nextRow:
            cpy _endY
            beq _done
            iny
            bra _row
        _done:
            rts
        _startX: .byte 0
        _endX: .byte 0
        _endY: .byte 0
            ; !notreached!
        }}
    }

    asmsub drawBlasts(bool advance @A) clobbers(A, X, Y) {
        %asm {{
            sta _advance
            ldy #4
        _row:
            lda blastRows,y
            beq _nextRow
            lda p8s_markBlast._lo,y
            sta _spot+1
            sta _tick+1
            lda p8s_markBlast._hi,y
            sta _spot+2
            sta _tick+2
            ldx #1
        _column:
        _spot:
            lda blastTiles,x
            beq _nextColumn
            lda _advance
            beq _flash
        _tick:
            dec blastTiles,x
            bne _flash
            lda blastRows,y
            dec a
            sta blastRows,y
            lda #32
            sta p8v_bufferTile
            stz p8v_bufferShade
            bra _draw
        _flash:
            lda #p8c_IMPACT_FLASH
            sta p8v_bufferTile
            lda #8
            sta p8v_bufferShade
        _draw:
            lda p8v_buffering
            beq _direct
            txa
            jsr p8s_stageCell
            bra _nextColumn
        _direct:
            txa
            asl a
            sta $9f20
            tya
            clc
            adc #$b0
            sta $9f21
            lda p8v_bufferTile
            sta $9f23
            lda p8v_bufferShade
            sta $9f23
        _nextColumn:
            inx
            cpx #39
            bcc _column
        _nextRow:
            iny
            cpy #27
            bcc _row
            rts
        _advance: .byte 0
            ; !notreached!
        }}
    }

    ; Compose all changed cells, including the rails and HUD. Zero is the
    ; untouched sentinel. Playfield and HUD writes use nonzero tile numbers.
    bool buffering, pendingFrame
    ; The two 8 KiB text maps start at VRAM $18000 and $1b000.
    ubyte writePage = $80
    ubyte bufferTile, bufferShade
    %asm {{
        .section BSS
        stagedTiles  .fill 1200
        stagedShades .fill 1200
        rowFirst     .fill 30
        rowEnd       .fill 30
        .send BSS
    }}

    asmsub stageCell(ubyte x @A, ubyte y @Y) clobbers(A) {
        %asm {{
            phx
            phy
            tax
            lda $02
            pha
            lda $03
            pha
            lda $04
            pha
            lda $05
            pha
            lda _tileLo,y
            sta $02
            lda _tileHi,y
            sta $03
            lda _shadeLo,y
            sta $04
            lda _shadeHi,y
            sta $05
            lda rowEnd,y
            beq _first
            txa
            cmp rowFirst,y
            bcs _rangeEnd
        _first:
            txa
            sta rowFirst,y
        _rangeEnd:
            txa
            cmp rowEnd,y
            bcc _write
            inc a
            sta rowEnd,y
        _write:
            txa
            tay
            lda p8v_bufferTile
            sta ($02),y
            lda p8v_bufferShade
            sta ($04),y
            pla
            sta $05
            pla
            sta $04
            pla
            sta $03
            pla
            sta $02
            ply
            plx
            rts
        _tileLo:
            .for row := 0, row < 30, row += 1
                .byte <(stagedTiles + row * 40)
            .endfor
        _tileHi:
            .for row := 0, row < 30, row += 1
                .byte >(stagedTiles + row * 40)
            .endfor
        _shadeLo:
            .for row := 0, row < 30, row += 1
                .byte <(stagedShades + row * 40)
            .endfor
        _shadeHi:
            .for row := 0, row < 30, row += 1
                .byte >(stagedShades + row * 40)
            .endfor
            ; !notreached!
        }}
    }

    ; Write the same delta to the hidden map twice. Its second write
    ; catches the old front map up after it becomes the back map.
    asmsub writeCells(bool clear @A) clobbers(A, X, Y) {
        %asm {{
            sta _clear
            stz p8v_buffering
            lda $02
            pha
            lda $03
            pha
            lda $04
            pha
            lda $05
            pha
            ldx #0
        _row:
            lda rowEnd,x
            beq _next
            txa
            clc
            adc p8v_writePage
            sta $9f21
            lda p8s_stageCell._tileLo,x
            sta $02
            lda p8s_stageCell._tileHi,x
            sta $03
            lda p8s_stageCell._shadeLo,x
            sta $04
            lda p8s_stageCell._shadeHi,x
            sta $05
            ldy rowFirst,x
        _column:
            lda ($02),y
            beq _skip
            pha
            tya
            asl a
            sta $9f20
            pla
            sta $9f23
            lda ($04),y
            sta $9f23
            lda _clear
            beq _skip
            lda #0
            sta ($02),y
        _skip:
            iny
            tya
            cmp rowEnd,x
            bcc _column
            lda _clear
            beq _next
            stz rowEnd,x
        _next:
            inx
            cpx #30
            bcc _row
            pla
            sta $05
            pla
            sta $04
            pla
            sta $03
            pla
            sta $02
            rts
        _clear: .byte 0
            ; !notreached!
        }}
    }

    sub flushCells() {
        writeCells(false)
        pendingFrame = true
    }

    ; Wait for the start of the next frame.
    sub vsync() {
        sys.waitvsync()
    }

    sub present() {
        if pendingFrame {
            setup()
            cx16.VERA_L1_MAPBASE = (writePage >> 1) | $80
            writePage ^= $30
            writeCells(true)
            pendingFrame = false
        }
    }

    sub prepareArena() {
        cx16.VERA_CTRL = 1
        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = $80
        cx16.VERA_ADDR_H = $11
        cx16.VERA_CTRL = 0
        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = $b0
        cx16.VERA_ADDR_H = $11
        repeat 8192 {
            cx16.VERA_DATA1 = cx16.VERA_DATA0
        }
        writePage = $80
    }

    sub showTextMap() {
        ; Finish any queued frame before changing screens, then use the
        ; KERNAL text map for the arena setup, pause message and menus.
        present()
        cx16.VERA_L1_MAPBASE = $d8
        writePage = $80
    }

    asmsub cell(ubyte x @R0, ubyte y @R1, ubyte tile @X, ubyte shade @Y) clobbers(A) {
        %asm {{
            lda p8v_buffering
            beq _direct
            stx p8v_bufferTile
            sty p8v_bufferShade
            phy
            ldy $04
            lda $02
            jsr p8b_video.p8s_stageCell
            ply
            rts
        _direct:
            lda $02
            asl a
            sta $9f20
            lda $04
            clc
            adc #$b0
            sta $9f21
            stx $9f23
            sty $9f23
            rts
        }}
    }

    sub setup() {
        cx16.VERA_CTRL = 0
        cx16.VERA_ADDR_H = $11
    }

    sub blackout() {
        setup()
        cx16.VERA_DC_BORDER = 0
        cx16.VERA_DC_VIDEO = oldVideo & $8f
        showTextMap()
    }

    sub showText() {
        cx16.VERA_DC_VIDEO = oldVideo & $ef
    }

    sub clear() {
        blackout()
        wipeText()
        showText()
    }

    sub wipeText() {
        ubyte y
        setup()
        for y in 0 to 29 {
            cx16.VERA_ADDR_L = 0
            cx16.VERA_ADDR_M = $b0 + y
            repeat 40 {
                cx16.VERA_DATA0 = 32
                cx16.VERA_DATA0 = 1
            }
        }
    }

    sub caption(ubyte x, ubyte y, ubyte shade, str message) {
        ubyte i = 0
        ubyte tile = message[i]
        while tile != 0 {
            if tile >= $c1 and tile <= $da {
                tile -= $c0
            }
            cell(x + i, y, tile, shade)
            i++
            tile = message[i]
        }
    }

    uword[5] decimalPlace = [1, 10, 100, 1000, 10000]

    long[9] scorePlaces = [100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1]

    sub scoreDigits(ubyte x, ubyte y, ubyte shade, long value) {
        ubyte place
        for place in 0 to 8 {
            long divisor = scorePlaces[place]
            ubyte tile = 48
            while value >= divisor {
                value -= divisor
                tile++
            }
            cell(x, y, tile, shade)
            x++
        }
    }

    sub digits(ubyte x, ubyte y, ubyte shade, uword value, ubyte count) {
        ubyte place = 5
        repeat 5 {
            place--
            uword divisor = decimalPlace[place]
            ubyte tile = 48
            while value >= divisor {
                value -= divisor
                tile++
            }
            if place < count {
                cell(x, y, tile, shade)
                x++
            }
        }
    }

    sub enemyTile(ubyte role) -> ubyte {
        if role == 3 {
            return SHARD
        }
        return TRAIN + role
    }

    asmsub background(ubyte x @A, ubyte y @Y) clobbers(A) {
        %asm {{
            pha
            lda p8v_buffering
            beq _direct
            lda #32
            sta p8v_bufferTile
            stz p8v_bufferShade
            pla
            jmp p8b_video.p8s_stageCell
        _direct:
            pla
            asl a
            sta $9f20
            tya
            clc
            adc #$b0
            sta $9f21
            lda #32
            sta $9f23
            stz $9f23
            rts
        }}
    }
}
