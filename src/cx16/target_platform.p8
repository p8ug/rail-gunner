; What the build needs for the Commander X16: nothing.  The program is one
; file, loaded into RAM.  (The GameTank's version of this module says which
; code goes into which bank of the cartridge.)

target {
    ; Before anything else.  The game's modules set the machine up themselves.
    sub boot() {
    }
}
