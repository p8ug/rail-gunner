; The high score table, the same on every machine.  It is kept twice, in the
; two slots of the machine's storage_platform module: a save goes to the slot
; that does not hold the newest table, so an interrupted save loses nothing.
%import storage_platform

scores {
    long[5] points
    ubyte[5] first
    ubyte[5] second
    ubyte[5] third
    bool last_save_ok = true

    const ubyte entry_count = 5
    const ubyte record_size = 42
    const ubyte legacy_size = 32
    const ubyte no_slot = 2
    ubyte active_slot = no_slot
    uword generation
    ubyte[43] data
    ubyte entry_width

    sub load() {
        ubyte row
        for row in 0 to 4 {
            points[row] = 0
            first[row] = 32
            second[row] = 32
            third[row] = 32
        }
        last_save_ok = true
        active_slot = no_slot
        generation = 0
        if read_record(0) {
            restore_record(0)
        }
        if read_record(1) {
            uword age = mkword(data[4], data[3]) - generation
            if active_slot == no_slot or (age != 0 and age < 32768) {
                restore_record(1)
            }
        }
    }

    sub qualifies(long value) -> bool {
        return value > points[entry_count - 1]
    }

    sub submit(long value, ubyte a, ubyte b, ubyte c) {
        if not qualifies(value) {
            return
        }

        ubyte row = entry_count - 1
        while row > 0 {
            ubyte above = row - 1
            if value <= points[above] {
                break
            }
            points[row] = points[above]
            first[row] = first[above]
            second[row] = second[above]
            third[row] = third[above]
            row--
        }
        points[row] = value
        first[row] = clean_letter(a)
        second[row] = clean_letter(b)
        third[row] = clean_letter(c)
        last_save_ok = save_record()
    }

    sub clean_letter(ubyte initial) -> ubyte {
        if initial < 65 or initial > 90 {
            return 65
        }
        return initial
    }

    sub checksum(ubyte end) -> uword {
        ubyte running = 0
        ubyte accumulated = 0
        ubyte pos
        for pos in 0 to end - 1 {
            running += data[pos]
            accumulated += running
        }
        return mkword(accumulated, running)
    }

    sub read_record(ubyte slot) -> bool {
        uword count = storage.read(slot, &data, record_size + 1)
        if count == 0 {
            return false
        }
        if data[0] != 73 or data[1] != 66 {
            return false
        }
        if count == legacy_size and data[2] == 1 {
            entry_width = 5
        } else if count == record_size and data[2] == 2 {
            entry_width = 7
        } else {
            return false
        }
        ubyte end = (count as ubyte) - 2
        if mkword(data[end + 1], data[end]) != checksum(end) {
            return false
        }

        long previous = 999999999
        ubyte pos = 5
        repeat entry_count {
            long value = read_points(pos)
            if value < 0 or value > previous {
                return false
            }
            previous = value
            if value != 0 {
                ubyte offset
                for offset in entry_width - 3 to entry_width - 1 {
                    ubyte initial = data[pos + offset]
                    if initial < 65 or initial > 90 {
                        return false
                    }
                }
            }
            pos += entry_width
        }
        return true
    }

    sub read_points(ubyte pos) -> long {
        long value = mkword(data[pos + 1], data[pos]) as long
        if entry_width == 7 {
            value |= (mkword(data[pos + 3], data[pos + 2]) as long) << 16
        }
        return value
    }

    sub restore_record(ubyte slot) {
        active_slot = slot
        generation = mkword(data[4], data[3])
        ubyte pos = 5
        ubyte row
        for row in 0 to 4 {
            points[row] = read_points(pos)
            first[row] = data[pos + entry_width - 3]
            second[row] = data[pos + entry_width - 2]
            third[row] = data[pos + entry_width - 1]
            pos += entry_width
        }
    }

    sub save_record() -> bool {
        if active_slot == 0 {
            return save_to_slot(1)
        }
        return save_to_slot(0)
    }

    sub save_to_slot(ubyte slot) -> bool {
        uword next_generation = generation + 1
        data[0] = 73
        data[1] = 66
        data[2] = 2
        data[3] = lsb(next_generation)
        data[4] = msb(next_generation)
        ubyte pos = 5
        ubyte row
        for row in 0 to 4 {
            uword low = points[row] as uword
            uword high = (points[row] >> 16) as uword
            data[pos] = lsb(low)
            data[pos + 1] = msb(low)
            data[pos + 2] = lsb(high)
            data[pos + 3] = msb(high)
            data[pos + 4] = first[row]
            data[pos + 5] = second[row]
            data[pos + 6] = third[row]
            pos += 7
        }
        uword check = checksum(record_size - 2)
        data[record_size - 2] = lsb(check)
        data[record_size - 1] = msb(check)

        ; Overwrite the inactive copy so interruption preserves the last valid table.
        if not storage.write(slot, &data, record_size) {
            return false
        }
        if not read_record(slot) {
            return false
        }
        if mkword(data[4], data[3]) != next_generation {
            return false
        }
        active_slot = slot
        generation = next_generation
        return true
    }
}
