# Owns the archive itself: each finished month of Claude transcripts, by last write, goes to DEST as one
# encrypted archive, recorded only after the copy there passes a checksum and a full test-extract.
# It deletes nothing local; Claude's own cleanupPeriodDays is the only thing that does.
# Launchd runs it with /bin/bash 3.2 (module.nix says why), so no bash 4 features.

src="$HOME/.claude/projects"
state="$HOME/.local/state/claude-transcript-archive"
identity="$HOME/.config/claude-transcript-archive/age-identity"
work='' partial='' reason=''

log() { echo "$(date -u +%FT%TZ) $*"; }
die() {
  reason="$*"
  exit 1
}

finish() {
  rc=$?
  [ -z "$work" ] || rm -rf -- "$work"
  [ -z "$partial" ] || rm -f -- "$partial"
  if [ "$rc" -eq 0 ]; then
    rm -f -- "$state/failed"
    touch -- "$state/ok"
  else
    reason="${reason:-exited with status $rc}"
    log "FAILED: $reason"
    log "$reason" >"$state/failed"
  fi
}

archive() {
  month="$1"
  name="claude-transcripts-$month.tar.zst.age"
  [ -d "$dest" ] || die "$dest is missing - is OneDrive running and signed in?"
  [ ! -e "$dest/$name" ] || die "$dest/$name exists but $state has no record of it; move it aside to archive $month again"

  find "$src" -name '*.jsonl' -type f -printf '%TY-%Tm %P\0' | sed -zn "s/^$month //p" >"$work/list"
  count="$(tr -cd '\0' <"$work/list" | wc -c)"
  log "$month: archiving $count files"
  tar -C "$src" --null --verbatim-files-from -T "$work/list" -cf - |
    zstd -q -T0 -19 --long=27 |
    age -e -i "$identity" -o "$work/$name"
  sum="$(sha256sum "$work/$name" | cut -d ' ' -f 1)"

  partial="$dest/$name.partial"
  cp -- "$work/$name" "$partial"
  [ "$(sha256sum "$partial" | cut -d ' ' -f 1)" = "$sum" ] || die "$month: the copy in $dest does not match its checksum"
  # --compare reads every member back and diffs it against the source byte for byte; -v lists each one.
  checked="$(age -d -i "$identity" "$partial" | zstd -dq | tar -C "$src" --compare -v -f - | wc -l)" ||
    die "$month: the copy in $dest failed its test-extract"
  [ "$checked" -eq "$count" ] || die "$month: the test-extract matched $checked of $count files"

  mv -- "$partial" "$dest/$name"
  partial=''
  echo "$sum  $name" >"$dest/$name.sha256"
  echo "$sum  $name" >"$state/$month.sha256"
  log "$month: $count files, $(stat -c %s "$dest/$name") bytes, sha256 $sum -> $dest/$name"
}

run() {
  dest="$1"
  mkdir -p -- "$state"
  exec >>"$state/log" 2>&1
  trap finish EXIT
  [ -d "$src" ] || die "$src is missing"
  [ -r "$identity" ] || die "no age identity at $identity - see the README's transcript archive setup"
  work="$(mktemp -d)"
  current="$(date +%Y-%m)"
  for month in $(find "$src" -name '*.jsonl' -type f -printf '%TY-%Tm\n' | sort -u); do
    [ "$month" \< "$current" ] && [ ! -e "$state/$month.sha256" ] || continue
    archive "$month"
  done
  log "up to date"
}

status() {
  if [ -e "$state/failed" ]; then
    echo "FAILED $(cat "$state/failed") - log: $state/log"
    return 1
  fi
  if [ -z "$(find "$state/ok" -mmin -4320 2>/dev/null)" ]; then
    echo "no successful run in 3 days - log: $state/log"
    return 1
  fi
  last="$(find "$state" -name '*.sha256' -printf '%f\n' | sort | tail -n 1)"
  last="${last%.sha256}"
  echo "ok, archived through ${last:-no month yet}"
}

case "${1:-} $#" in
"run 2") run "$2" ;;
"status 1") status ;;
*)
  echo "usage: claude-transcript-archive run DEST | status" >&2
  exit 2
  ;;
esac
