# Build Rail Gunner 1.0

Extract the entire ZIP. The build uses the included p8p8 0.6.0 compiler, standard library, and 64tass 1.60.3243 assembler. The normal build works offline and needs only the host OS and its standard runtime.

| Host | From a terminal in the extracted directory |
|---|---|
| Windows x64 | Run `build.cmd` in Command Prompt |
| Linux x86-64 with glibc 2.38 or newer | Run `sh build.sh` |

Both scripts write **`build/RAILGUN.PRG`**. `rail_gunner.p8` is the main Prog8 source file. See [README.md](README.md) for loading the PRG on the X16 and running it in an emulator.

The archive includes the released binary as `RAILGUN-1.0-REFERENCE.PRG`. Compare a fresh build to that reference with `fc /b RAILGUN-1.0-REFERENCE.PRG build\RAILGUN.PRG` on Windows or `cmp RAILGUN-1.0-REFERENCE.PRG build/RAILGUN.PRG` on Linux. The released SHA-256 is `df48d71bd8f935235105e186d6bd79f238af306d84e9017bed78bf9ce92f6a3e`.

## Music regeneration

The default build compiles the checked-in `music_data.p8`. To regenerate it and `PUNCH.ZSM` from the supplied MIDI, use Python 3.10 or newer with pip.

```sh
python -m pip install --target .music-deps --no-index --find-links tools/python mido==1.3.3 packaging==26.4
python -c "import sys, runpy; sys.path.insert(0, '.music-deps'); runpy.run_path('arrange_music.py', run_name='__main__')"
```

See [tools/UPSTREAM.md](tools/UPSTREAM.md) for tool origins and license files.
