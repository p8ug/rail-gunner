#!/usr/bin/env python3
"""Where does the size of a Prog8 program go?

Reads the map that `p8c -map` writes beside the program (name.p8map; any of
p8c's CPUs), or a 64tass listing (`-asmlist`, name.list; from p8c or prog8c),
and reports:

  * the memory map: the program's bytes, its variables, where it must end and
    how much room is left
  * the bytes of code and data per block and per subroutine
  * the bytes of the variables
  * the same per source file (--modules)

    p8size build/main.p8map                 # map, blocks, top 25 subroutines
    p8size MAP --top 60                     # more rows
    p8size MAP --block main                 # only the subroutines of block main
    p8size MAP --vars                       # the biggest variables
    p8size MAP --modules                    # per source file
    p8size A.p8map B.p8map                  # what changed, A -> B
    p8size MAP --map --min-free 128         # exit 1 if less room is left
    p8size MAP --json                       # everything, for a script
    p8size MAP --check                      # do the entries add up to the regions?

A map has a line for every block, subroutine and variable (see
docs/DESIGN.md, "The program's map").  In a listing the sizes come from
address differences and the names from the labels; the block "(runtime)"
has what belongs to no block.
"""
import argparse
import json
import os
import re
import sys
from collections import defaultdict

IMAGE_KINDS = ("code", "data")


class Program:
    """what is known of one built program"""

    def __init__(self, path):
        self.path = path
        self.name = os.path.splitext(os.path.basename(path))[0]
        self.target = None
        self.cpu = None
        self.relocatable = False
        self.regions = {}                # name -> (start, end)
        self.limit = None
        self.free = None
        self.modules = {}                # block -> source file
        self.entries = []                # (kind, address, bytes, block, name)

    def total(self, kinds):
        out = defaultdict(int)
        for kind, _, size, block, name in self.entries:
            if kind in kinds:
                out[(block, name)] += size
        return out

    @property
    def subs(self):
        return self.total(IMAGE_KINDS)

    @property
    def vars(self):
        return self.total(("var",))

    @property
    def zp(self):
        return self.total(("zp",))

    @property
    def code_bytes(self):
        return sum(self.subs.values())

    @property
    def var_bytes(self):
        return sum(self.vars.values())

    @property
    def zp_bytes(self):
        return sum(self.zp.values())

    def module_of(self, block):
        return self.modules.get(block, "(runtime)" if block.startswith("(") else "(no source)")


def read_map(path):
    prog = Program(path)
    with open(path, encoding="utf-8", errors="replace") as f:
        first = f.readline().split()
        if first[:1] != ["p8map"]:
            sys.exit(f"{path}: not a p8map file")
        if first[1:] != ["1"]:
            sys.exit(f"{path}: p8map version {' '.join(first[1:])}; this tool reads version 1")
        for raw in f:
            fields = raw.rstrip("\n").split(" ")
            key = fields[0]
            if key == "program":
                prog.name = " ".join(fields[1:])
            elif key == "target":
                prog.target = fields[1]
            elif key == "cpu":
                prog.cpu = fields[1]
            elif key == "relocatable":
                prog.relocatable = True
            elif key == "region":
                prog.regions[fields[1]] = (int(fields[2], 16), int(fields[3], 16))
            elif key == "limit":
                prog.limit = int(fields[1], 16)
            elif key == "free":
                prog.free = int(fields[1])
            elif key == "module":
                prog.modules[fields[1]] = " ".join(fields[2:])
            elif key in ("code", "data", "var", "zp"):
                name = " ".join(fields[4:])
                prog.entries.append((key, int(fields[1], 16), int(fields[2]), fields[3],
                                     "(block)" if name == "-" else name))
    return prog


# ---- a 64tass listing ----

ADDR = re.compile(r"^([.>])([0-9a-f]+)$")
HEX = re.compile(r"[0-9a-f]{2}( [0-9a-f]{2})*")
IDENT = re.compile(r"[A-Za-z_][\w.]*|[+\-]+")
MNEMONICS = set("""adc and asl bcc bcs beq bit bmi bne bpl brk bvc bvs clc cld cli
    clv cmp cpx cpy dec dex dey eor inc inx iny jmp jsr lda ldx ldy lsr nop ora
    pha php pla plp rol ror rti rts sbc sec sed sei sta stx sty tax tay tsx txa
    txs tya bra phx phy plx ply stz trb tsb wai stp""".split())
ZP_LINE = re.compile(r"^=(\d+)\t+(p8v_\w+)\s*=\s*\d+\s*;\s*zp\s+(\w+)")
LOCAL = re.compile(r"^(\+|-|_.*|p8_label_gen_\d+_(?!tempv).*|p8l_.*|\.\w+)$")
VAR_DECL = re.compile(r"^\.(byte|word|dword|long|fill)\b\s*(.*)$")
TYPE_SIZE = {"ubyte": 1, "byte": 1, "bool": 1, "uword": 2, "word": 2,
             "pointer": 2, "long": 4, "float": 5}


def split_line(raw, monitor):
    """a listing line -> (address, number of bytes, label, statement), or None"""
    fields = raw.split("\t")
    m = ADDR.match(fields[0])
    if not m:
        return None
    rest = fields[1:]
    hexf = ""
    if rest and HEX.fullmatch(rest[0].strip()):
        hexf = rest.pop(0).strip()
    src = [f.strip() for f in rest if f.strip()]
    if monitor and m.group(1) == "." and hexf and src:
        src.pop(0)
    label, stmt = None, ""
    if len(src) >= 2:
        label, stmt = src[0], " ".join(src[1:])
    elif src:
        parts = src[0].split(None, 1)
        if len(parts) == 2 and IDENT.fullmatch(parts[0]) and parts[0].lower() not in MNEMONICS:
            label, stmt = parts
        elif IDENT.fullmatch(src[0]) and src[0].lower() not in MNEMONICS:
            label = src[0]
        else:
            stmt = src[0]
    if label and not IDENT.fullmatch(label):
        label, stmt = None, " ".join(src)
    return int(m.group(2), 16), len(hexf.split()), label, stmt


def declared_size(kind, operand):
    """the bytes a .byte ?/.word ?/.fill n line sets aside, None if it has values"""
    operand = operand.split(";")[0].strip()
    if kind == "fill":
        expr = operand.split(",")[0]
        if not re.fullmatch(r"[\d\s*+()]+", expr):
            return None
        return eval(expr)  # only digits and * + ( ), checked above
    if operand.replace(" ", "").strip("?,") != "":
        return None
    per = {"byte": 1, "word": 2, "dword": 4, "long": 3}[kind]
    return per * operand.count("?")


def scoped(sub, var):
    var = var.replace("p8v_", "")
    if re.fullmatch(r"p8_label_gen_\d+_tempv", var):
        var = "(temp)"          # numbered anew in each build
    return f"{sub}.{var}" if sub else var


def read_listing(path):
    prog = Program(path)
    prog.cpu = "6502"
    lines = []          # (address, kind, text, bytes)
    zp_lines = []
    labels = {}
    var = "?"
    monitor = False
    with open(path, encoding="utf-8", errors="replace") as f:
        for raw in f:
            raw = raw.rstrip("\n")
            if raw.startswith(";Offset"):
                monitor = ";Monitor" in raw
                continue
            m = ZP_LINE.match(raw)
            if m:
                zp_lines.append((len(lines), m.group(2), m.group(3)))
                continue
            line = split_line(raw, monitor)
            if not line:
                continue
            addr, nbytes, label, stmt = line
            d = VAR_DECL.match(stmt)
            size = declared_size(d.group(1), d.group(2)) if d and not nbytes else None
            if size is not None:
                var = label or var          # an unnamed one belongs to the one before it
                lines.append((addr, "var", var, size))
                continue
            if label:
                lines.append((addr, "label", label, 0))
            if nbytes or stmt.startswith("."):
                lines.append((addr, "code", stmt, nbytes))
    code = sorted({e[0] for e in lines if e[1] == "code"})
    nxt = {a: b - a for a, b in zip(code, code[1:])}
    first = last = None
    if code:
        first = code[0]
        tail = max((e for e in lines if e[1] == "code"), key=lambda e: e[0])
        nxt[tail[0]] = tail[3]
        last = tail[0] + tail[3]
    block, cur = "(runtime)", None
    var_first = var_end = None
    zp_iter = iter(zp_lines)
    zp_next = next(zp_iter, None)
    for i, (addr, kind, text, size) in enumerate(lines):
        while zp_next and zp_next[0] <= i:
            prog.entries.append(("zp", 0, TYPE_SIZE.get(zp_next[2], 2), block, scoped(cur, zp_next[1])))
            zp_next = next(zp_iter, None)
        if kind == "label":
            labels.setdefault(text, addr)
            if text.startswith("p8b_"):
                block, cur = text[4:], None
            elif text.startswith("p8s_"):
                cur = text[4:]
            elif text.startswith(("prog8_", "p8v_", "p8c_")) or LOCAL.match(text):
                pass
            elif re.fullmatch(r"string_\d+", text):
                block, cur = "(runtime)", "(strings)"
            else:
                block, cur = "(runtime)", text
        elif kind == "var":
            # (room set aside inside the code is part of the code's size already)
            if first is None or not first <= addr < last:
                prog.entries.append(("var", addr, size, block, scoped(cur, text)))
                var_end = max(var_end or 0, addr + size)
                var_first = addr if var_first is None else min(var_first, addr)
        else:
            n = nxt.pop(addr, 0)
            if n:
                prog.entries.append(("code", addr, n, block, cur or "(block)"))
    for _, name, typ in ([zp_next] if zp_next else []) + list(zp_iter):
        prog.entries.append(("zp", 0, TYPE_SIZE.get(typ, 2), block, scoped(cur, name)))
    if not any(t.startswith("p8b_") for t in labels):
        # not a prog8 program: its routines are all there is
        prog.entries = [(k, a, n, "(program)", name) for k, a, n, _, name in prog.entries]
    if first is not None:
        prog.regions["image"] = (first, last)
    start = labels.get("prog8_bss_section_start", var_first)
    if start is not None and var_end is not None:
        prog.regions["vars"] = (start, max(var_end, start))
    end = labels.get("prog8_program_end")
    if end is None:
        end = max((x for x in (last, var_end) if x is not None), default=None)
    prog.limit = memtop_from_asm(path)
    if prog.limit is not None and end is not None:
        prog.free = prog.limit - end
    prog.end = end
    return prog


def memtop_from_asm(list_path):
    asm = os.path.splitext(list_path)[0] + ".asm"
    try:
        with open(asm, encoding="utf-8", errors="replace") as f:
            for line in f:
                # (prog8c: .cerror * >= $8000; p8c: .cerror prog8_program_end >= $8000)
                m = re.search(r"\.cerror\s+(?:\*|prog8_program_end)\s*>=?\s*\$([0-9a-fA-F]+)", line)
                if m:
                    return int(m.group(1), 16)
    except OSError:
        pass
    return None


def read(path):
    try:
        with open(path, "rb") as f:
            head = f.read(6)
    except OSError as error:
        sys.exit(f"{path}: {error.strerror}")
    return read_map(path) if head.startswith(b"p8map") else read_listing(path)


# ---- reports ----

REGION_NAMES = {"image": "code + data", "vars": "variables", "data": "data",
                "uppervars": "variables above", "upper": "code above"}


def hexa(a):
    return "?" if a is None else f"${a:04x}"


def show_map(prog):
    what = " ".join(x for x in (prog.target, prog.cpu) if x)
    print(f"{prog.path}:" + (f"  ({what})" if what else ""))
    for name, (start, end) in prog.regions.items():
        label = REGION_NAMES.get(name, name)
        where = f"{end - start:6d} bytes" if prog.relocatable else f"{hexa(start)}-{hexa(end)}  {end - start:6d} bytes"
        print(f"  {label:16s} {where}")
    if not prog.regions:
        print(f"  code + data      {prog.code_bytes:6d} bytes")
        print(f"  variables        {prog.var_bytes:6d} bytes")
    if prog.zp_bytes:
        pad = "" if prog.relocatable else " " * 13
        print(f"  {'zeropage':16s} {pad}{prog.zp_bytes:6d} bytes")
    if prog.limit is not None:
        line = f"  must end before  {hexa(prog.limit)}"
        if prog.free is not None:
            line += f"   free {prog.free} bytes"
            if prog.free < 0:
                line += "   (TOO BIG)"
        print(line)


def table(rows, total, top):
    for (block, name), n in rows[:top]:
        print(f"  {n:6d}  {100.0 * n / total:5.1f}%  {block}.{name}")
    rest = sum(n for _, n in rows[top:])
    if rest:
        print(f"  {rest:6d}  {100.0 * rest / total:5.1f}%  ({len(rows) - top} more)")


def by_size(d):
    return sorted(d.items(), key=lambda kv: (-kv[1], kv[0]))


def short_path(path):
    parts = path.replace("\\", "/").split("/")
    return "/".join(parts[-2:]) if len(parts) > 1 else path


def module_totals(prog):
    out = defaultdict(lambda: [0, 0])
    for kind, _, size, block, _ in prog.entries:
        if kind in IMAGE_KINDS:
            out[prog.module_of(block)][0] += size
        elif kind in ("var", "zp"):
            out[prog.module_of(block)][1] += size
    return out


def show(prog, args):
    show_map(prog)
    if args.map:
        return
    if args.modules:
        totals = module_totals(prog)
        total = prog.code_bytes or 1
        print("by source file:    code + data          variables")
        for module, (code, var) in sorted(totals.items(), key=lambda kv: (-kv[1][0], kv[0])):
            print(f"  {code:6d}  {100.0 * code / total:5.1f}%  {var:6d}  {short_path(module)}")
        return
    if args.vars:
        print("variables:")
        table(by_size(prog.vars), prog.var_bytes or 1, args.top)
        if prog.zp:
            print("zeropage variables:")
            table(by_size(prog.zp), prog.zp_bytes, args.top)
        return
    total = prog.code_bytes or 1
    blocks = defaultdict(int)
    for (b, _), n in prog.subs.items():
        blocks[b] += n
    print("code + data by block:")
    for b, n in sorted(blocks.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {n:6d}  {100.0 * n / total:5.1f}%  {b}")
    rows = [kv for kv in by_size(prog.subs) if not args.block or kv[0][0] == args.block]
    print("code + data by subroutine:" + (f" (block {args.block})" if args.block else ""))
    table(rows, total, args.top)


def changes(a, b, top, title):
    rows = sorted(((k, b.get(k, 0) - a.get(k, 0)) for k in set(a) | set(b)),
                  key=lambda kv: (-abs(kv[1]), kv[0]))
    rows = [r for r in rows if r[1]]
    if not rows:
        return
    print(f"{title}:")
    for (block, name), d in rows[:top]:
        note = " (new)" if (block, name) not in a else " (gone)" if (block, name) not in b else ""
        print(f"  {d:+7d}  {block}.{name}{note}")
    rest = sum(d for _, d in rows[top:])
    if rest:
        print(f"  {rest:+7d}  ({len(rows) - top} more)")


def diff(a, b, args):
    print(f"{a.path} -> {b.path}")

    def line(label, x, y):
        if x is None or y is None:
            return
        print(f"  {label:13s}{x:7d} -> {y:7d}  {y - x:+d}")
    line("code + data", a.code_bytes, b.code_bytes)
    line("variables", a.var_bytes, b.var_bytes)
    line("zeropage", a.zp_bytes, b.zp_bytes)
    line("free", a.free, b.free)
    if args.modules:
        ma, mb = module_totals(a), module_totals(b)
        changes({(short_path(k), "code + data"): v[0] for k, v in ma.items()},
                {(short_path(k), "code + data"): v[0] for k, v in mb.items()}, args.top, "by source file")
        return
    changes(a.subs, b.subs, args.top, "code + data")
    changes(a.vars, b.vars, args.top, "variables")


def as_json(prog):
    return {
        "path": prog.path, "program": prog.name, "target": prog.target, "cpu": prog.cpu,
        "relocatable": prog.relocatable,
        "regions": {k: {"start": s, "end": e, "bytes": e - s} for k, (s, e) in prog.regions.items()},
        "limit": prog.limit, "free": prog.free,
        "code_and_data": prog.code_bytes, "variables": prog.var_bytes, "zeropage": prog.zp_bytes,
        "modules": {k: {"code_and_data": v[0], "variables": v[1]} for k, v in module_totals(prog).items()},
        "entries": [{"kind": k, "address": a, "bytes": n, "block": b, "name": name,
                     "module": prog.module_of(b)} for k, a, n, b, name in prog.entries],
    }


def check(prog):
    """do the entries fill each region?  the messages when not"""
    wrong = []
    if prog.relocatable:
        # (addresses are offsets in the kind's own section)
        sums = defaultdict(int)
        for kind, _, size, _, _ in prog.entries:
            sums[kind] += size
        for name, kind in (("image", "code"), ("data", "data"), ("vars", "var")):
            if name in prog.regions:
                start, end = prog.regions[name]
                if end - start != sums[kind]:
                    wrong.append(f"{prog.path}: region {name} has {end - start} bytes, its entries {sums[kind]}")
        return wrong
    for name, (start, end) in prog.regions.items():
        got = sum(size for kind, addr, size, _, _ in prog.entries
                  if kind != "zp" and start <= addr < end)
        if got != end - start:
            wrong.append(f"{prog.path}: region {name} has {end - start} bytes, its entries {got}")
        want = "var" if "vars" in name else None
        for kind, addr, size, block, entry in prog.entries:
            if kind != "zp" and start <= addr < end and (kind == "var") != (want == "var"):
                wrong.append(f"{prog.path}: {kind} {block}.{entry} at {hexa(addr)} is in region {name}")
    return wrong


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="one .p8map or .list file, or two to compare")
    ap.add_argument("--top", type=int, default=25, help="rows to show (default 25)")
    ap.add_argument("--block", help="only subroutines of this block (main, txt ...)")
    ap.add_argument("--vars", "--bss", action="store_true", help="list the biggest variables")
    ap.add_argument("--modules", action="store_true", help="the sizes per source file")
    ap.add_argument("--map", action="store_true", help="only the memory map")
    ap.add_argument("--json", action="store_true", help="everything as JSON")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 unless the entries add up to the regions")
    ap.add_argument("--memtop", type=lambda s: int(s.replace("$", "0x"), 0),
                    help="first address the program may not use ($8000, 0x8000)")
    ap.add_argument("--min-free", type=int, metavar="N",
                    help="exit 1 if fewer than N bytes are left")
    args = ap.parse_args()
    if len(args.files) > 2:
        sys.exit("give one or two files")
    progs = [read(p) for p in args.files]
    for prog in progs:
        if args.memtop is not None:
            end = getattr(prog, "end", None)
            if end is None and prog.limit is not None and prog.free is not None:
                end = prog.limit - prog.free
            prog.limit = args.memtop
            prog.free = None if end is None else args.memtop - end
    if args.check:
        wrong = [w for prog in progs for w in check(prog)]
        if wrong:
            sys.exit("\n".join(wrong))
    if args.json:
        out = [as_json(p) for p in progs]
        json.dump(out[0] if len(out) == 1 else out, sys.stdout, indent=1)
        print()
    elif len(progs) == 1:
        show(progs[0], args)
    else:
        diff(progs[0], progs[1], args)
    if args.min_free is not None:
        prog = progs[-1]
        if prog.free is None:
            sys.exit(f"{prog.path}: where the program must end is not known, use --memtop")
        if prog.free < args.min_free:
            sys.exit(f"{prog.path}: only {prog.free} bytes free, want {args.min_free}")


if __name__ == "__main__":
    main()
