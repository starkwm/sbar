import Foundation

// Embedded so a binary-only install can run the adapters without a resource bundle.
enum AgentAdapterScripts {
  static let adapter = #"""
    #!/bin/bash
    # sbar-agent-activity-v1: sbar-owned adapter. Never reads transcripts or returns hook decisions.
    # Requires macOS's /usr/bin/jq and lockf.
    set -euo pipefail

    marker=sbar-agent-activity-v1
    script="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"

    fail() {
      echo "$*" >&2
      exit 1
    }

    # POSIX single quoting for hook commands run by a shell.
    quote() { printf "'%s'" "$(printf %s "$1" | sed "s/'/'\\\\''/g")"; }

    events() {
      case $1 in
      codex) echo SessionStart SessionEnd UserPromptSubmit PreToolUse PermissionRequest Stop Interrupt ;;
      claude) echo SessionStart SessionEnd UserPromptSubmit PreToolUse PermissionRequest Stop StopFailure Notification Elicitation ElicitationResult ;;
      esac
    }

    # Late PostToolUse hooks can revive an idle session, so setup removes earlier registrations.
    retired_events=PostToolUse

    translate='
      (.hook_event_name // "") as $event
      | if $event == "Notification" then
          if (.notification_type | IN("permission_prompt", "elicitation_dialog", "elicitation_url_dialog", "agent_needs_input"))
          then "needsInput" else empty end
        elif $event == "PreToolUse" and (.tool_name | IN("AskUserQuestion", "request_user_input")) then "needsInput"
        else {SessionStart: "idle", SessionEnd: "unknown", UserPromptSubmit: "working",
              PreToolUse: "working", PermissionRequest: "needsInput",
              Elicitation: "needsInput", ElicitationResult: "working",
              Stop: "idle", StopFailure: "failed", Interrupt: "interrupted"}[$event] // empty
        end'

    hook() {
      local payload state session key
      payload=$(cat)
      state=$(jq -r "$translate" <<<"$payload")
      [[ -n $state ]] || return 0
      session=$(jq -r '.session_id | strings' <<<"$payload")
      [[ -n $session ]] || fail 'Missing session_id'
      if [[ $(jq -r '.hook_event_name' <<<"$payload") == SessionEnd ]]; then
        # An ended session leaves the bar instead of lingering as unknown.
        "$sbar" agents dismiss --socket "$socket" --source "$source" --session "$session" >/dev/null
        return
      fi
      # Only identifiers and display metadata enter this cache, never the hook payload.
      mkdir -p "$cache"
      chmod 700 "$cache"
      key=$(printf %s "$source$session" | shasum -a 256 | cut -d' ' -f1)
      # Serialize each session's stream, even when the harness runs hooks concurrently.
      lockf -k -t 1 "$cache/$key.lock" "$script" locked-hook --source "$source" --socket "$socket" \
        --cache "$cache" --sbar "$sbar" --state "$state" --session "$session" --key "$key" <<<"$payload"
    }

    locked_hook() {
      local payload path old incoming run current report
      payload=$(cat)
      path=$cache/$key.json
      old=$(cat "$path" 2>/dev/null || echo '{}')
      incoming=$(jq -r --arg source "$source" \
        '(if $source == "codex" then .turn_id else .prompt_id end) | strings' <<<"$payload")
      if [[ -n $incoming ]] && jq -e --arg run "$incoming" '(.retired // []) | index($run)' <<<"$old" >/dev/null; then
        # A delayed completion must never claim a newer run.
        return 0
      fi
      run=${incoming:-$(jq -r '.run | strings' <<<"$old")}
      run=${run:-$(uuidgen | tr '[:upper:]' '[:lower:]')}
      current=$("$sbar" agents list --socket "$socket")
      report=$(jq -nc --argjson old "$old" --argjson current "$current" --arg source "$source" \
        --arg session "$session" --arg run "$run" --arg state "$state" \
        --arg project "$(jq -r '.cwd | strings' <<<"$payload")" '
        ($current.value // [] | map(select(.report.source == $source and .report.session == $session))
          | first | .report.run) as $previous
        | {version: 1, source: $source, session: $session, run: $run,
           sequence: (($old.sequence // -1) + 1), state: $state,
           agent: $source, identity: "\($source):\($session)"}
        + (if $project != "" then {project: $project} else {} end)
        + (if $previous and $previous != $run then {replaces: $previous} else {} end)')
      "$sbar" agents report --socket "$socket" --json - <<<"$report" >/dev/null
      jq -c --arg run "$run" --argjson sequence "$(jq .sequence <<<"$report")" '
        {run: $run, sequence: $sequence,
         retired: (((.retired // []) + (if .run and .run != $run then [.run] else [] end))[-32:])}' \
        <<<"$old" >"$path.tmp"
      chmod 600 "$path.tmp"
      mv "$path.tmp" "$path"
    }

    setup() {
      local path settings installed command temporary mode template
      mkdir -p "$root"
      root=$(cd -- "$root" && pwd -P)
      if [[ $source == pi ]]; then
        path=$root/extensions/$marker.ts
        if ((remove)); then
          if [[ -f $path ]] && grep -q "$marker" "$path"; then rm "$path"; fi
          return
        fi
        mkdir -p "$root/extensions"
        if [[ -f $path ]] && ! grep -q "$marker" "$path"; then fail 'Refusing to replace unowned extension'; fi
        template=$(<"$(dirname -- "$script")/pi.ts")
        printf '%s\n' "${template//__SOCKET__/$(jq -n --arg socket "$socket" '$socket')}" >"$path"
        return
      fi
      if [[ $source == codex ]]; then settings=$root/hooks.json; else settings=$root/settings.json; fi
      installed=$root/$marker.sh
      if ((remove)) && [[ ! -f $settings ]]; then
        if [[ -f $installed ]] && grep -q "$marker" "$installed"; then rm "$installed"; fi
        return
      fi
      if ((!remove)) && [[ -f $installed ]] && ! grep -q "$marker" "$installed"; then
        fail 'Refusing to replace unowned hook script'
      fi
      command="$(quote "$installed") hook --source $(quote "$source") --socket $(quote "$socket")"
      command+=" --sbar $(quote "$sbar") --quiet"
      temporary=$settings.sbar-tmp
      jq --arg prefix "$(quote "$installed") hook " --arg command "$command" \
        --arg events "$(events "$source") $retired_events" --arg retired "$retired_events" \
        --argjson remove "$remove" '
        .hooks = reduce ($events | split(" ")[]) as $event (.hooks // {};
          ((.[$event] // [])
            | map(.hooks = ((.hooks // []) | map(select((.command // "") | startswith($prefix) | not))))
            | map(select(.hooks | length > 0))
            | . + (if $remove == 1 or ($retired | split(" ") | index($event)) then []
              else [{hooks: [{type: "command", command: $command, timeout: 1}]}] end)
          ) as $groups
          | if ($groups | length) > 0 then .[$event] = $groups else del(.[$event]) end)' \
        "$([[ -f $settings ]] && echo "$settings" || echo /dev/stdin)" <<<'{}' >"$temporary"
      mode=600
      if [[ -f $settings ]]; then mode=$(stat -f %Lp "$settings"); fi
      chmod "$mode" "$temporary"
      mv "$temporary" "$settings"
      if ((remove)); then
        if [[ -f $installed ]] && grep -q "$marker" "$installed"; then rm "$installed"; fi
      else
        cp "$script" "$installed"
        chmod 700 "$installed"
        echo 'Review the installed hooks in /hooks before activation. Trust remains under your control.'
      fi
    }

    doctor() {
      local executable version baseline pid
      executable=$(command -v "$source" || true)
      echo "Executable: ${executable:-missing}"
      [[ -n $executable ]] || fail "Could not find $source in PATH."
      version=$(
        "$executable" --version 2>/dev/null &
        pid=$!
        (sleep 3 && kill "$pid") >/dev/null 2>&1 &
        wait "$pid"
      ) || fail 'Version check failed or took longer than 3 seconds.'
      echo "Installed version: $version"
      case $source in
      codex) baseline=0.166.0 ;;
      claude) baseline=2.1.314 ;;
      pi) baseline=1.4.0 ;;
      esac
      echo "Hooks checked against version $baseline. Older versions are untested."
      echo "Socket: $socket"
      "$sbar" agents list --socket "$socket" >/dev/null
      echo 'Connected to sbar.'
      echo "Review your agent's hooks, then run a session and check the bar."
    }

    action=${1:-}
    shift || true
    source='' socket=$HOME/.config/sbar/control.sock root='' cache=$HOME/.cache/sbar/agents
    sbar=sbar state='' session='' key='' quiet=0 remove=0
    while (($#)); do
      case $1 in
      --source) source=$2 && shift 2 ;;
      --socket) socket=$2 && shift 2 ;;
      --root) root=$2 && shift 2 ;;
      --cache) cache=$2 && shift 2 ;;
      --sbar) sbar=$2 && shift 2 ;;
      --state) state=$2 && shift 2 ;;
      --session) session=$2 && shift 2 ;;
      --key) key=$2 && shift 2 ;;
      --quiet) quiet=1 && shift ;;
      --remove) remove=1 && shift ;;
      *) fail "Unknown argument: $1" ;;
      esac
    done
    case $source in
    codex | claude | pi) ;;
    *) fail 'Expected --source codex, claude or pi.' ;;
    esac

    case $action in
    hook)
      if ((quiet)); then
        # Hook failures must never become harness decisions or model context.
        exec >/dev/null 2>&1
        trap 'exit 0' EXIT
      fi
      hook
      ;;
    locked-hook) locked_hook ;;
    setup)
      [[ -n $root ]] || fail '--root is required; setup never chooses a config directory implicitly'
      setup
      ;;
    doctor) doctor ;;
    *) fail 'Expected hook, setup or doctor.' ;;
    esac
    """#

  static let pi = #"""
    // sbar-agent-activity-v1. Requires pi 1.4.0 lifecycle and UI prompt events.
    import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
    import { createConnection } from "node:net";
    import { randomUUID } from "node:crypto";

    export default function (pi: ExtensionAPI) {
      const socketPath = __SOCKET__;
      let run = randomUUID(), sequence = 0, session = "", project = "";
      let state = "idle", outcome = "completed", timer: ReturnType<typeof setInterval> | undefined;
      let queue = Promise.resolve();
      function request(arguments_: string[], value?: unknown): Promise<any> {
        return new Promise((resolve, reject) => {
          const socket = createConnection(socketPath);
          let data = "";
          socket.setTimeout(500, () => socket.destroy(new Error("sbar timeout")));
          socket.on("error", reject);
          socket.on("close", () => { if (!data.includes("\n")) reject(new Error("sbar closed without acknowledgement")); });
          socket.on("connect", () => socket.write(JSON.stringify({ command: "agents", arguments: arguments_, value }) + "\n"));
          socket.on("data", chunk => {
            data += chunk;
            if (data.length > 4000000) socket.destroy(new Error("Oversized response"));
            if (!data.includes("\n")) return;
            socket.end();
            try { const result = JSON.parse(data.split("\n")[0]); result.ok ? resolve(result.value) : reject(new Error(result.error)); }
            catch (error) { reject(error); }
          });
        });
      }
      function publish() {
        const report: any = { version: 1, source: "pi", agent: "pi", session, run, sequence: ++sequence, state, project, identity: `pi:${session}`, heartbeatSeconds: 30 };
        queue = queue.then(async () => {
          const entries = await request(["list"]);
          const old = entries.find((entry: any) => entry.report.source === "pi" && entry.report.session === report.session);
          if (old && old.report.run !== report.run) report.replaces = old.report.run;
          await request(["report"], report);
        }).catch(() => {});
      }
      function end() {
        clearInterval(timer);
        const ended = session;
        if (ended) queue = queue.then(() => request(["dismiss", "pi", ended])).catch(() => {});
      }
      pi.on("session_start", (_event, ctx) => {
        const next = ctx.sessionManager.getSessionId();
        if (next !== session) { end(); state = "idle"; } else clearInterval(timer);
        session = next; project = ctx.cwd;
        publish(); timer = setInterval(publish, 10000); timer.unref();
      });
      pi.on("before_agent_start", () => { run = randomUUID(); state = "working"; outcome = "completed"; publish(); });
      pi.on("turn_end", event => { outcome = event.outcome; });
      pi.on("agent_settled", event => { state = event.aborted ? "interrupted" : outcome === "error" ? "failed" : "idle"; publish(); });
      pi.on("ui_prompt_start", () => { state = "needsInput"; publish(); });
      pi.on("ui_prompt_end", (_event, ctx) => { state = ctx.isIdle() ? "idle" : "working"; publish(); });
      pi.on("session_shutdown", () => { end(); });
    }
    """#
}
