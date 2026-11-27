; Rail Gunner: the program, for every machine it is built for.
;
;   game.p8                 the game
;   scores.p8               the high score table
;   <machine>/*_platform.p8 what a machine does in its own way
;
; -srcdirs names src and the directory of one machine, which is how the
; right _platform modules are found: see the Makefile.

; The GameTank's fixed bank ends where its startup code begins.  On the
; Commander X16 this changes nothing: the program ends far below.
%memtop $fd00

%import syslib
%import target_platform
%import game
%zeropage basicsafe

main {
    sub start() {
        target.boot()
        game.run()
    }
}
