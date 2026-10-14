{ pkgs, ... }:

# Owns the Mac's keep-awake while Firstmate works: a launchd agent that holds one idle-sleep
# assertion (`caffeinate -i`) for exactly as long as any Firstmate home records a busy turn.

let
  # The busy signal is the one durable record Firstmate itself keeps per task, state/<id>.busy-state
  # (bin/fm-busy-lib.sh), read in the main home (~/firstmate) and in every home under the fleet root
  # ~/.treehouse, the secondmate homes among them. Reading it wakes and modifies nothing. A record
  # busy for longer than `max` is treated as stale, so a crashed harness can never hold the Mac awake
  # forever.
  watcher = pkgs.writeShellScript "firstmate-keepawake" ''
    shopt -s nullglob
    max=21600
    caf=

    busy() {
      local f line ts now
      printf -v now '%(%s)T' -1
      for f in "$HOME"/firstmate/state/*.busy-state "$HOME"/.treehouse/firstmate-*/*/firstmate/state/*.busy-state; do
        read -r line < "$f" || continue
        [[ $line == *" state=busy "* ]] || continue
        ts=''${line##*ts=}
        [[ $ts =~ ^[0-9]+$ ]] && (( now - ts < max )) && return 0
      done
      return 1
    }

    # -i is an idle-sleep assertion only: closing the lid still sleeps. -w ties it to this process, so
    # the assertion cannot outlive the watcher.
    while :; do
      if busy; then
        kill -0 "$caf" 2>/dev/null || { /usr/bin/caffeinate -i -w $$ & caf=$!; }
      elif [[ -n $caf ]]; then
        kill "$caf" 2>/dev/null
        caf=
      fi
      sleep 15
    done
  '';
in
{
  launchd.agents.firstmate-keepawake = {
    enable = true;
    config = {
      ProgramArguments = [ "${watcher}" ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
    };
  };
}
