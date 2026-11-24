# Owns the archive's behaviour test, on temporary fixtures only; flake.nix runs it as a check.
# The command runs through the `bash` on PATH, as launchd runs it: CI runs it under Linux bash, and only
# a manual Mac run with /bin/bash first on PATH proves bash 3.2.
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  [ ! -r "$state/log" ] || cat "$state/log" >&2
  exit 1
}
archive() { bash "$(command -v claude-transcript-archive)" "$@"; }
listing() { zstd -dq <"$dest/claude-transcripts-$1.tar.zst" | tar -t | sort; }

HOME="$(mktemp -d)"
export HOME
src="$HOME/.claude/projects" dest="$HOME/onedrive" state="$HOME/.local/state/claude-transcript-archive"

# Claude names project folders after their path, so they start with a dash, which tar must not parse.
mkdir -p "$src/-Users-test-a/sub" "$src/b"
echo one >"$src/-Users-test-a/one.jsonl"
echo two >"$src/-Users-test-a/sub/two.jsonl"
echo three >"$src/b/three.jsonl"
echo now >"$src/b/now.jsonl"
echo notes >"$src/b/notes.txt"
touch -d '2024-01-15 10:00' "$src/-Users-test-a/one.jsonl"
touch -d '2024-01-31 23:59' "$src/-Users-test-a/sub/two.jsonl"
touch -d '2024-02-01 00:30' "$src/b/three.jsonl"
touch -d '2024-01-10 10:00' "$src/b/notes.txt"

! archive status >/dev/null || fail "status is ok before any run"
! archive run "$dest" || fail "ran without a destination"
if s="$(archive status)"; then fail "status is ok after a failure"; fi
case "$s" in "FAILED "*"$dest is missing"*) ;; *) fail "status: $s" ;; esac

mkdir "$dest"
archive run "$dest" || fail "the run failed"
[ ! -e "$state/failed" ] || fail "a success left the failure marker"
[ "$(archive status)" = "copied through 2024-02 to $dest; OneDrive upload not verified by this job" ] ||
  fail "status: $(archive status)"
grep -q '2024-01: 2 files, 8 bytes raw, ' "$state/log" || fail "the log lacks 2024-01's raw size"
[ "$(find "$dest" -type f | wc -l)" -eq 4 ] || fail "want two archives and two checksums: $(ls "$dest")"
(cd "$dest" && sha256sum --quiet -c ./*.sha256) || fail "a checksum file does not match its archive"
[ "$(listing 2024-01)" = "$(printf '%s\n' -Users-test-a/one.jsonl -Users-test-a/sub/two.jsonl)" ] ||
  fail "2024-01 holds: $(listing 2024-01)"
[ "$(listing 2024-02)" = b/three.jsonl ] || fail "2024-02 holds: $(listing 2024-02)"
[ "$(find "$src" -type f | wc -l)" -eq 5 ] || fail "a source file was removed"

archive run "$dest" || fail "the second run failed"
[ -z "$(find "$dest" -newer "$state/2024-02.sha256")" ] || fail "the second run rewrote an archive"

rm "$state/2024-01.sha256"
! archive run "$dest" || fail "overwrote an archive it has no record of"
grep -q 'exists but' "$state/failed" || fail "no failure marker for an unrecorded archive"
(cd "$dest" && sha256sum --quiet -c ./*.sha256) || fail "the refused run changed an archive"

rm "$state/failed"
touch -d '4 days ago' "$state/ok"
! archive status >/dev/null || fail "status is ok after 4 days without a run"

echo "transcript-archive: all checks passed"
