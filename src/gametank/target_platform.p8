; What the build needs for the GameTank: the program is a cartridge.
;
; The fixed bank (16 KB, always there) holds the GameTank library and what
; has to be there at all times.  Everything else is in banks of the cartridge
; that are brought in while their code runs: the lists below say which block
; is in which bank.  What calls each other often is in the same bank, because
; a call into another bank changes banks twice.
%option romable

%import gametank
%import gametank_banking
%import gfx
%import dbg

%overlay banks.GAME, game, video, screens, input, audio, music
%overlay banks.PAGES, pages, scores, storage
%overlay banks.ASSETS, gfxdata, songdata, sfxdata

banks {
    const ubyte GAME = 128          ; the game and what it calls every frame
    const ubyte PAGES = 129         ; the pages of text, the high scores
    const ubyte ASSETS = 130        ; sprite sheets, the song, the sound effects
    ; 254 is where the high scores are saved: nothing else may be there
}

target {
    ; Before anything else: the GameTank logo and its jingle, which also
    ; starts the sound chip and the music player, then the pictures.
    sub boot() {
        gametank.sdk_init()
        dbg.step(1)
        gametank.init_graphics()
        dbg.step(2)
        gfx.init()
        dbg.report()
    }

    ; The address of the last used record of a save sector, or 0 when the
    ; sector is empty.  A record is stride bytes, and its first byte is $ff
    ; as long as it is free.  This reads another bank of the cartridge, so
    ; it has to be here in the fixed bank, not in a bank itself.
    sub lastRecord(uword sector, ubyte stride) -> uword {
        uword found = 0
        uword at = sector
        gametank.push_rom_bank()
        gametank.change_rom_bank(gametank.BANK_SAVE)
        while at < sector + gametank.SAVE_SECTOR_SIZE and @(at) != $ff {
            found = at
            at += stride
        }
        gametank.pop_rom_bank()
        return found
    }
}
