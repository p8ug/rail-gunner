; Where the high scores are kept on the Commander X16: two files on the disk.
; The names are those of Ion Break, so that its scores are still found.
%import diskio

storage {
    str[] names = ["ionbreak.sco", "ionbreak.bak"]

    ; Read what is in a slot (0 or 1), at most size bytes.
    ; Returns how many bytes that was: 0 when there is nothing.
    sub read(ubyte slot, uword buffer, uword size) -> uword {
        if not diskio.f_open(names[slot]) {
            return 0
        }
        uword count = diskio.f_read(buffer, size)
        diskio.f_close()
        return count
    }

    ; Put size bytes in a slot, in place of what is there.
    sub write(ubyte slot, uword buffer, uword size) -> bool {
        diskio.delete(names[slot])
        return diskio.save_raw(names[slot], buffer, size)
    }
}
