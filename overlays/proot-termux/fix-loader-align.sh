#!/bin/sh
# Assert the just-linked loader's PT_LOAD layout is safe for proot.
#
# Background: proot maps each guest PT_LOAD with both address and file
# offset masked down to the page size (see add_mapping in
# src/execve/enter.c), which silently assumes p_offset and p_vaddr are
# congruent modulo the page size.  Past toolchain hacks broke this:
# a hardcoded 8-byte patch at file offset 112, then `-n` (nmagic),
# which made lld merge everything into one PT_LOAD with p_offset 0xb0
# -- the guest then executed its own ELF header and died with SIGSEGV
# on first exec (CI run 36609782404).  This script asserts the three
# invariants the loader recipe depends on, and fails the build loudly
# if a toolchain upgrade ever breaks them:
#
#   1. at least one PT_LOAD exists;
#   2. no PT_LOAD has p_align > 64K (bloat tripwire);
#   3. every PT_LOAD satisfies p_offset % M == p_vaddr % M with
#      M = max(p_align, 4K) (the congruence add_mapping assumes,
#      lifted to the segment's own alignment so >4K hosts are covered).
#
# It rewrites nothing.  Invoked from src/GNUmakefile's loader link
# recipe as:
#
#   fix-loader-align.sh <readelf> <loader-file>
set -eu
# Note: no `pipefail` here: the shebang is /bin/sh (dash on some
# systems, which rejects `set -o pipefail`).  Every pipeline below
# ends in an explicit numeric assertion, so nothing fails silently.

readelf_bin=${1:?usage: fix-loader-align.sh READELF FILE}
f=${2:?usage: fix-loader-align.sh READELF FILE}

# POSIX sh has no hex parsing except $((0x...)) arithmetic, so extract
# columns with awk (field split only) and compare in the shell.
# readelf -lW guarantees unwrapped lines.  The modulus is per-segment
# max(p_align, 4K): add_mapping masks with the host page size, and the
# linker guarantees offset/vaddr congruence modulo p_align, so this is
# strictly stronger than a flat 4K check with the same false-positive
# profile on sane linkers.
seen=0
bad_align=0
bad_cong=0
for row in $("$readelf_bin" -lW "$f" | awk '/^  LOAD /{print $2 ":" $3 ":" $NF}'); do
	seen=$((seen + 1))
	offset=${row%%:*}
	rest=${row#*:}
	vaddr=${rest%%:*}
	align=${rest##*:}
	if [ "$((align))" -gt 65536 ]; then
		bad_align=$((bad_align + 1))
	fi
	mod=$((align > 4096 ? align : 4096))
	if [ $((offset % mod)) -ne $((vaddr % mod)) ]; then
		echo "fix-loader-align.sh: PT_LOAD offset $offset / vaddr $vaddr not congruent mod $mod in $f" >&2
		bad_cong=$((bad_cong + 1))
	fi
done
if [ "$seen" -eq 0 ]; then
	echo "fix-loader-align.sh: no PT_LOAD found in $f" >&2
	exit 1
fi
if [ "$bad_align" -ne 0 ]; then
	echo "fix-loader-align.sh: $bad_align PT_LOAD with p_align > 64K in $f" >&2
	exit 1
fi
if [ "$bad_cong" -ne 0 ]; then
	echo "fix-loader-align.sh: $bad_cong PT_LOAD break offset/vaddr congruence in $f" >&2
	exit 1
fi
