; Rail Gunner screens for the GameTank: 128 by 128 pixels.
;
; The pages of text are in the pages block, in another bank of the cartridge
; (pages.p8).  This block is with the game: it passes the game's requests on,
; and it draws the two lines of the HUD above and below the arena, which
; change during play.
;
; The HUD is text of 31 characters in the 3 x 5 font:
;   SCORE 000000000  WAVE 00001 ^3
;   CHAIN 1 POWER =====   AMMO 40
%import gfx
%import pages
%import video_platform

screens {
    %option overlay_data

    const ubyte HUD_TOP = 8
    const ubyte HUD_BOTTOM = 114

    sub title() {
        pages.title()
    }

    sub titleValues() {
        pages.titleValues()
    }

    ; The labels are drawn with the arena: paintLabels().
    sub hudLabels() {
    }

    ; The HUD changed: both framebuffers get it, with their next frames.
    sub drawHud() {
        video.hudFrames = 2
    }

    sub drawAmmo() {
        video.ammoFrames = 2
    }

    sub waveBanner(ubyte shade) {
        pages.waveBanner(shade)
    }

    ; A sign over the arena as it stands.
    sub paused() {
        gfx.toFront()
        gametank.queue_draw_box(30, 50, 68, 24, 91)
        gametank.queue_draw_box(31, 51, 66, 22, 0)
        gametank.await_draw_queue()
        gfx.heading(40, 58, "PAUSED")
    }

    sub results() {
        pages.results()
    }

    sub continuePrompt() {
        pages.continuePrompt()
    }

    sub initialsPage() {
        pages.initialsPage()
    }

    sub initialsLetters(ubyte slot) {
        pages.initialsLetters(slot)
    }

    sub saveFailed() {
        pages.saveFailed()
    }

    ; ---- the HUD, into the framebuffer that is drawn to ----

    sub paintLabels() {
        gfx.text(2, HUD_TOP, 14, "SCORE")
        gfx.text(70, HUD_TOP, 14, "WAVE")
        gfx.text(2, HUD_BOTTOM, 14, "CHAIN")
        gfx.text(34, HUD_BOTTOM, 14, "POWER")
        if game.demoMode {
            gfx.text(106, HUD_BOTTOM, 3, "DEMO")
        } else if game.ammoMode != game.AMMO_UNLIMITED {
            gfx.text(82, HUD_BOTTOM, 14, "AMMO")
        }
        gfx.tile(114, HUD_TOP, video.SHIP - 127, 1)
        gametank.await_draw_queue()
    }

    sub paintHud() {
        gfx.score(26, HUD_TOP, 1, game.points)
        gfx.digits(90, HUD_TOP, 1, game.wave, 5)
        gfx.digits(118, HUD_TOP, 3, game.ships as uword, 1)
        gfx.digits(26, HUD_BOTTOM, 7, game.combo as uword, 1)
        if game.chargeMarks == game.CHARGE_MARKS {
            gfx.text(58, HUD_BOTTOM, 13, "READY")
        } else {
            ubyte i
            for i in 0 to game.CHARGE_MARKS-1 {
                ubyte shade = 11
                if i < game.chargeMarks {
                    shade = 13
                }
                gfx.glyph(58 + i * 4, HUD_BOTTOM, shade, '=')
            }
        }
    }

    sub paintAmmo() {
        if game.ammoMode == game.AMMO_UNLIMITED {
            return
        }
        ; a number after the label, or words in place of both
        if game.ammo != 0 {
            ubyte shade = 1
            if game.ammo <= 8 {
                shade = 7
            }
            gfx.text(82, HUD_BOTTOM, 14, "AMMO      ")
            gfx.digits(102, HUD_BOTTOM, shade, game.ammo as uword, 2)
        } else if game.ammoMode == game.AMMO_SLOWDOWN {
            gfx.text(82, HUD_BOTTOM, 7, " SLOW FIRE")
        } else if game.ammoMode == game.AMMO_PACKS {
            if game.refillX != 0 {
                gfx.text(82, HUD_BOTTOM, 7, " GET PACK ")
            } else {
                gfx.text(82, HUD_BOTTOM, 8, " GET POD  ")
            }
        } else {
            gfx.text(82, HUD_BOTTOM, 8, " RELOADING")
        }
    }
}
