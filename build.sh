#!/bin/sh
set -eu
cd "$(dirname "$0")"
root=$(pwd)
p8="$root/tools/linux/p8p8"
PATH="$root/tools/linux/64tass:$PATH"
export PATH
mkdir -p build
"$p8/bin/p8c" -lib "$p8/lib/p8p8" -target cx16 -out build rail_gunner.p8
cp build/rail_gunner.prg build/RAILGUN.PRG
printf '%s\n' 'Built build/RAILGUN.PRG'
