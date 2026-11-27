; Where the high scores are kept on the GameTank: the two save sectors of the
; cartridge's flash memory, one for each slot.
;
; Flash can be written once after an erase, and an erase is a whole sector
; and takes a second or so.  So a sector is a row of records of 64 bytes:
; the length of what was saved, then the bytes.  A save goes into the next
; free record, and the sector is only erased when it is full.  What a slot
; holds is its last record.
%import gametank
%import gametank_persist

storage {
    %option overlay_data

    const ubyte STRIDE = 64
    ubyte[STRIDE] record

    sub sector(ubyte slot) -> uword {
        if slot == 0 {
            return gametank.SAVE_SECTOR1
        }
        return gametank.SAVE_SECTOR2
    }

    ; Read what is in a slot (0 or 1), at most size bytes.
    ; Returns how many bytes that was: 0 when there is nothing.
    sub read(ubyte slot, uword buffer, uword size) -> uword {
        uword at = target.lastRecord(sector(slot), STRIDE)
        if at == 0 {
            return 0
        }
        gametank.save_read(at, &record, STRIDE)
        ubyte count = record[0]
        if count >= STRIDE or count > size {
            return 0
        }
        ubyte i
        for i in 0 to count - 1 {
            buffer[i] = record[i + 1]
        }
        return count
    }

    ; Put size bytes (at most 63) in a slot, in place of what is there.
    sub write(ubyte slot, uword buffer, uword size) -> bool {
        if size == 0 or size >= STRIDE {
            return false
        }
        uword start = sector(slot)
        uword at = target.lastRecord(start, STRIDE)
        if at == 0 {
            at = start
        } else {
            at += STRIDE
            if at >= start + gametank.SAVE_SECTOR_SIZE {
                if not gametank.save_erase(start) {
                    return false
                }
                at = start
            }
        }
        record[0] = lsb(size)
        ubyte i
        for i in 0 to lsb(size) - 1 {
            record[i + 1] = buffer[i]
        }
        return gametank.save_write(&record, at, lsb(size) + 1)
    }
}
