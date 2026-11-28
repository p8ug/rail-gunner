; Rail Gunner's pictures for the GameTank, in a bank of the cartridge.
; tools/gametank/make_assets.py makes the files.

gfxdata {
%option overlay_data

; a sprite sheet: the cells of the arena in every colour, and the 16 x 16
; pictures of the title page
tiles:
    %asmbinary "tiles.deflate"
; the frame table of those pictures
frames:
    %asmbinary "frames.bin"
; a sprite sheet: the 3 x 5 pixel font in ten colours
font:
    %asmbinary "font.deflate"
}
