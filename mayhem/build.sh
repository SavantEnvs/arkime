#!/usr/bin/env bash
#
# mayhem/build.sh — builds Arkime twice from pristine copies of the tree under mayhem/build/ (autotools
# here is in-tree, so a copy keeps the checkout untouched and the script re-runnable):
#   build/oracle  normal flags      -> tests/tests.pl (mayhem/test.sh) runs against it
#   build/fuzz    sanitized+SanCov  -> upstream's own FUZZLOCH libFuzzer harness (capture/main.c)
# Outputs: /mayhem/fuzzloch and /mayhem/fuzzloch-standalone (both enter build/fuzz/tests at startup,
# see chdir_ctor.c, because the harness reads config.test.ini and the parser/plugin .so files from there).
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

: "${SRC:=/mayhem}"
cd "$SRC"
B="$SRC/mayhem/build"
DATA=/opt/toolchains/deps/arkime-test-data-b8004faf/src
export ARKIME_BUILD_FULL_VERSION="$(git describe --tags 2>/dev/null || echo mayhem)"
unset CFLAGS CXXFLAGS LDFLAGS

rm -rf "$B"
mkdir -p "$B/base"
tar -C "$SRC" --exclude=./mayhem/build --exclude=./.git -cf - . | tar -C "$B/base" -xf -
(cd "$B/base" && sh bootstrap.sh) > "$B/bootstrap.log" 2>&1 || { tail -30 "$B/bootstrap.log"; exit 1; }
cp -a "$B/base" "$B/oracle"
cp -a "$B/base" "$B/fuzz"

link_data() {
  for f in ipv4-address-space.csv oui.txt GeoLite2-ASN.mmdb GeoLite2-City.mmdb; do ln -sf "$DATA/$f" "$1/tests/$f"; done
}

# 1) test-suite build: the project's normal flags
cd "$B/oracle"
./configure --with-python=no CC="$CC" > "$B/oracle-configure.log" 2>&1 || { tail -30 "$B/oracle-configure.log"; exit 1; }
make -C capture -j"$MAYHEM_JOBS" EXTRA_CFLAGS="$COVERAGE_FLAGS" EXTRA_LDFLAGS="$COVERAGE_FLAGS"
make -C tests/plugins
link_data "$B/oracle"

# 2) fuzz build: project (capture, parsers, plugins, thirdparty objects) with sanitizers + SanCov + DWARF 3
# -fno-sanitize=function: upstream sorts/compares through differently-typed function pointers (field.c qsort), which
# would halt on the first init; every other UBSan check stays on and halting.
FZ="$SANITIZER_FLAGS -fno-sanitize=function $DEBUG_FLAGS -fsanitize=fuzzer-no-link -fno-common"
cd "$B/fuzz"
./configure --with-python=no CC="$CC" > "$B/fuzz-configure.log" 2>&1 || { tail -30 "$B/fuzz-configure.log"; exit 1; }
# capture/Makefile builds these three without any EXTRA_CFLAGS; prebuild them instrumented (make sees them up to date)
(cd capture
 $CC -fno-strict-aliasing -pthread -fPIC -O2 $FZ -c thirdparty/js0n.c -o thirdparty/js0n.o
 $CC -fno-strict-aliasing -pthread -fPIC -O2 $FZ -c thirdparty/patricia.c -o thirdparty/patricia.o
 $CC -fno-strict-aliasing -pthread -fPIC -DNDEBUG -DHTTP_PARSER_STRICT=0 -DHTTP_PARSER_DEBUG=0 -O2 $FZ \
     -c thirdparty/http_parser.c -o thirdparty/http_parser.o)

# LeakSanitizer off at build time, plus the chdir constructor, for every binary
$CXX $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o "$B/lsan_off.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/chdir_ctor.c" -o "$B/chdir_ctor.o"
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o "$B/standalone_main.o"
# Per-input reset (fuzzloch_harness.c): upstream's FUZZLOCH harness keeps every session, fragment and queue alive
# between inputs. upstream's LLVMFuzzerTestOneInput is renamed at compile time and wrapped by one that closes all
# sessions and fragments after each input; session.o/packet.o come from wrappers that #include the unchanged
# upstream files (fuzzloch.mk), because the tables live in file-local statics.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$SRC/mayhem/fuzzloch_harness.c" -o "$B/fuzzloch_harness.o"
MK="-f Makefile -f $SRC/mayhem/fuzzloch.mk MAYHEM_DIR=$SRC/mayhem"
FZC="$FZ -DFUZZLOCH -DLLVMFuzzerTestOneInput=fuzzloch_upstream_one_input"

make -C capture $MK -j"$MAYHEM_JOBS" EXTRA_CFLAGS="$FZC" \
     EXTRA_LDFLAGS="$SANITIZER_FLAGS $LIB_FUZZING_ENGINE $B/fuzzloch_harness.o $B/lsan_off.o $B/chdir_ctor.o"
cp capture/capture "$SRC/fuzzloch"
# standalone reproducer: same objects, run-once driver instead of the libFuzzer engine ('all' always relinks)
make -C capture $MK EXTRA_CFLAGS="$FZC" \
     EXTRA_LDFLAGS="$SANITIZER_FLAGS -fsanitize=fuzzer-no-link $B/standalone_main.o $B/fuzzloch_harness.o $B/lsan_off.o $B/chdir_ctor.o"
cp capture/capture "$SRC/fuzzloch-standalone"
# the fuzz-node plugin set in tests/plugins, instrumented like the rest
make -C tests/plugins CC="$CC $FZ"
link_data "$B/fuzz"
