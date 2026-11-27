; Rail Gunner input for the GameTank: both gamepads, as the game's one byte
; of buttons.  A and B fire, START pauses, C goes back.
%import gametank
%import gametank_input

input {
    %option overlay_data

    const ubyte UP = 1
    const ubyte DOWN = 2
    const ubyte LEFT = 4
    const ubyte RIGHT = 8
    const ubyte FIRE = 16
    const ubyte START = 32
    const ubyte QUIT = 64
    const ubyte SELECT = 128
    ; A console has nowhere to exit to: QUIT on the title page does nothing.
    const bool CAN_EXIT = false

    sub init() {
    }

    sub shutdown() {
    }

    sub poll() -> ubyte {
        gametank.update_inputs()
        uword pads = gametank.player1_buttons | gametank.player2_buttons
        ubyte state = 0
        if pads & gametank.INPUT_MASK_UP != 0 {
            state |= UP
        }
        if pads & gametank.INPUT_MASK_DOWN != 0 {
            state |= DOWN
        }
        if pads & gametank.INPUT_MASK_LEFT != 0 {
            state |= LEFT
        }
        if pads & gametank.INPUT_MASK_RIGHT != 0 {
            state |= RIGHT
        }
        if pads & (gametank.INPUT_MASK_A | gametank.INPUT_MASK_B) != 0 {
            state |= FIRE
        }
        if pads & gametank.INPUT_MASK_START != 0 {
            state |= START
        }
        if pads & gametank.INPUT_MASK_C != 0 {
            state |= SELECT
        }
        return state
    }
}
