# Agent activity

`agentActivity` shows which agents are working or waiting for input. Click the item to see each session's agent, host, title, project, state, elapsed time and last report time. You can dismiss rows from the popup.

All items and displays share one session store in memory. Reports go through the control socket, and sbar confirms whether it accepted each report.

```json
{"id":"agents","type":"agentActivity","agentActivity":{"finishedRetention":30,"staleAfter":300,"hideWhenEmpty":true}}
```

## Reports and ordering

```fish
sbar agents report --source custom --session conversation --run turn-one --sequence 0 --state working --title Build --project /work/project
sbar agents report --source custom --session conversation --run turn-one --sequence 1 --state needsInput
sbar agents report --source custom --session conversation --run turn-two --replaces turn-one --sequence 0 --state working
sbar agents list
sbar agents dismiss --source custom --session conversation
```

Every command accepts `--socket`. `report --json FILE`, or `--json -` for stdin, accepts this object:

```json
{"version":1,"source":"custom","session":"conversation","run":"turn-one","sequence":0,"state":"working","agent":"codex","title":"Build","project":"/work/project"}
```

`session` identifies a conversation; `run` identifies a response attempt. IDs can contain up to 256 UTF-8 bytes and cannot contain colons. sbar treats them as identifiers, not sortable values.

`sequence` is a nonnegative integer that increases within a run. Sending the same report again is safe. sbar rejects older sequences and reports that reuse a sequence with different contents.

To start a new run, set `replaces` to the current run ID. This prevents a late report from a replaced run from overwriting newer work. Use `agents list` to find the current run when reconnecting. After a bar restart, omit `replaces` from the first report. Send reports one at a time for each source/session pair.

Omitting `title`, `project`, `agent`, `host` or `identity` keeps its previous value. Display metadata is limited to 1024 bytes and cannot contain control characters. Never send prompts, transcripts, credentials or tool arguments.

Reporting requires an active `agentActivity` item. The store keeps up to 4096 sessions, including dismissed entries needed to check ordering. When full, it removes the session with the oldest report.

### States and retention

States are `working`, `needsInput`, `idle`, `finished`, `failed`, `interrupted` and `unknown`. `idle` means the agent is ready for input. `finished` means the response has ended with no continuation pending; it says nothing about whether the task succeeded. Use `needsInput` only for an actual question or approval request waiting for the user. Waiting for a background job does not qualify.

For adapters that send regular updates, `heartbeatSeconds` sets a deadline between 1 and 3600 seconds. A missed deadline changes the state to `unknown`. Hooks that report only on events keep their last state and timestamp. The popup marks reports stale after `staleAfter`, which defaults to 300 seconds. Silence never produces `finished` or `failed`.

Finished rows hide after `finishedRetention`, which defaults to 30 seconds from the state change. Heartbeats do not extend that period. Other rows remain until updated or dismissed. Unchanged heartbeats leave a dismissed row hidden; a new run or state change shows it again.

Removing the last provider item or shutting down sbar clears the store, including ordering data. A persistent adapter can send its current state again. An event-only hook must wait for its next event.

## Writing an adapter for another harness

Use `agents report` with a stable source name such as `my-harness`. Custom sources need no sbar plugin or provider changes. Install the hook through your harness and test it with the reporting commands below. `agents setup` and `agents doctor` support only the bundled adapters.

Register the adapter with the harness's documented hooks or extension API so normal agent use sends reports automatically. The model should not need instructions to report progress. Report only states supported by those events; do not guess from silence or conversation text.

### Map events to states

| Event | State |
| --- | --- |
| A response starts or execution resumes | `working` |
| A question or approval request waits for the user | `needsInput`; return to `working` when execution resumes |
| The agent is ready for input, including at session start | `idle` |
| The response ends with no continuation pending | `finished` |
| The response ends with a fatal error | `failed` |
| The harness confirms cancellation of the response | `interrupted` |
| The agent is present but its state is unclear | `unknown` |

Do not treat an idle prompt, queued task or background wait as a request for input. A recoverable tool error does not mean the response failed. Stop hooks can cause the agent to continue, so report `idle` until a later event confirms what happened.

Use identifiers, event types and metadata meant for display. Omit `title` if the harness has no separate display title. Never extract titles from prompts or state from transcripts.

### Keep reports in order

Keep reports in order for each source/session pair, even when the harness starts a new process for every hook:

1. Use the conversation ID as `session` and the response or turn ID as `run`. If the harness has no turn ID, create one at a confirmed turn-start event and pass it through that turn's callbacks. Convert IDs containing colons or control characters to stable safe IDs, such as hashes. Never use titles as identities.
2. Start `sequence` at zero and increase it for each new report. Retry an event with the same sequence and metadata. A new heartbeat needs a higher sequence; resending an identical report does not renew its deadline.
3. Process callbacks one at a time for each session. Prefer the harness's ordered event stream. Separate hook processes need a per-session lock and a private state file with the current run, sequence, previous run and pending report. Write the file atomically and set timeouts for the lock and reporting calls. A lock cannot fix events that arrive out of order. Use the harness's event IDs or ordering information to sort them, and reject events whose order you cannot determine.
4. Save a pending report before sending it. Mark it delivered only after sbar acknowledges it. If the acknowledgement is lost, retry the identical report. Set a retry limit so a hook cannot wait forever.
5. Replace a run only after a confirmed new-turn event. Put the previous run ID in `replaces`; do not sort run IDs as strings or timestamps. Keep the original run ID on late completion events so sbar can reject them.

On reconnect, call `agents list --socket PATH`. The JSON response has an `ok` flag and a `value` array. Each entry contains a `report` with source, session, run and sequence. Match by source and session. The list includes dismissed and retained entries, even when their rows are hidden.

If the store is empty after a restart or provider removal, send the current state and display metadata without `replaces`. Discard queued events from old runs first.

If the store has a different run, check which run the harness is actually using before replacing it. Copying the listed run into `replaces` on every ordering error would let delayed events overwrite newer work. Persistent adapters can resend their current state on reconnect; event-only hooks must wait until they next run.

### Minimal hook command

Save this wrapper as `sbar-agent-hook.sh` and make it executable. It uses macOS's built-in Bash, `/usr/bin/jq` and an installed sbar binary. Your harness or adapter must supply the mapped state and ordering fields described above. Register it using your harness's documented hook format.

```bash
#!/bin/bash
set -euo pipefail

diagnostic=0 source=my-harness session='' run='' sequence='' state=''
replaces='' title='' project=''
while (($#)); do
  case $1 in
  --diagnostic) diagnostic=1 && shift ;;
  --source) source=$2 && shift 2 ;;
  --session) session=$2 && shift 2 ;;
  --run) run=$2 && shift 2 ;;
  --sequence) sequence=$2 && shift 2 ;;
  --state) state=$2 && shift 2 ;;
  --replaces) replaces=$2 && shift 2 ;;
  --title) title=$2 && shift 2 ;;
  --project) project=$2 && shift 2 ;;
  *) echo "Unknown argument: $1" >&2 && exit 1 ;;
  esac
done

if ((!diagnostic)); then
  # Errors and acknowledgements must not become harness decisions or context.
  exec >/dev/null 2>&1
  trap 'exit 0' EXIT
fi

if [[ -z $session || -z $run || ! $sequence =~ ^[0-9]+$ ]]; then
  echo 'Expected --session, --run and a numeric --sequence.' >&2
  exit 1
fi
case $state in
working | needsInput | idle | finished | failed | interrupted | unknown) ;;
*) echo 'Expected a valid --state.' >&2 && exit 1 ;;
esac

report=$(jq -nc --arg source "$source" --arg session "$session" --arg run "$run" \
  --argjson sequence "$sequence" --arg state "$state" --arg replaces "$replaces" \
  --arg title "$title" --arg project "$project" '
  {version: 1, source: $source, agent: $source, session: $session, run: $run,
   sequence: $sequence, state: $state}
  + ({replaces: $replaces, title: $title, project: $project}
    | with_entries(select(.value != "")))')

"${SBAR_BIN:-sbar}" agents report \
  --socket "${SBAR_SOCKET:-$HOME/.config/sbar/control.sock}" --json - <<<"$report"
```

In normal mode, the wrapper exits with code zero even if reporting fails. If you add saved pending reports, mark them delivered only after checking sbar's acknowledgement inside the wrapper. The wrapper's exit code cannot confirm delivery.

The wrapper sends metadata to sbar on stdin and discards its output in normal mode. An unavailable bar or rejected report does not produce an approval decision or failure exit code. Set a hook timeout in the harness to limit how long the call can take.

Use this wrapper only for hooks that can observe events without making decisions. Check how the harness handles stdout, stderr, exit codes and timeouts; some treat hook output as instructions or approvals. Use `--diagnostic` for manual checks only.

Configure the harness to call the script with real IDs, sequence and state, plus the previous run ID when a new turn starts. Preserve existing hooks and trust or approval settings.

Use an absolute script path. If the harness has a restricted PATH, set `SBAR_BIN` to the absolute path of the sbar binary. `SBAR_SOCKET` selects the bar instance. These environment variables belong to this wrapper.

Start the separate example bar, then run these fish commands from the repository root. Use a new session ID for each test:

```fish
set -lx SBAR_BIN "$PWD/.build/debug/sbar"
set -lx SBAR_SOCKET "$PWD/examples/agent-activity/control.sock"
set session (uuidgen)

/absolute/path/sbar-agent-hook.sh --diagnostic \
    --session "$session" --run turn-one --sequence 0 \
    --state working --title "Custom harness demo" --project "$PWD"
/absolute/path/sbar-agent-hook.sh --diagnostic \
    --session "$session" --run turn-one --sequence 1 --state needsInput
/absolute/path/sbar-agent-hook.sh --diagnostic \
    --session "$session" --run turn-one --sequence 2 --state finished
/absolute/path/sbar-agent-hook.sh --diagnostic \
    --session "$session" --run turn-two --replaces turn-one \
    --sequence 0 --state working

"$SBAR_BIN" agents list --socket "$SBAR_SOCKET"
```

Persistent extensions should set `heartbeatSeconds` and send updates more often than that deadline. Stop the timer and dismiss the session on shutdown. Send the current state again after reconnecting. The wrapper above omits heartbeats because event hooks cannot guarantee regular updates.

If a host and its underlying agent both report the same work, give both reports the same `identity` and set `host` only on the host report. For example, both can use `identity="my-harness:CONVERSATION_ID"`. The host sends its own source/session and `host="my-host"`. Unlike session and run IDs, `identity` is metadata and may contain a colon.

Use one reporter for the conversation unless you can map the identities explicitly. Never match by title or project.

Before enabling a custom adapter, test a normal response, a question or approval wait, a second turn, duplicate delivery and a delayed completion from an old run. Also test with sbar stopped and after restarting it. Check that hook failures leave approvals and response continuation unchanged. Use `--diagnostic` for these checks, then register normal hook mode for everyday use.

## Configuration and templates

`sources` and `projects` filter by exact match. Omit an array to select everything; use an empty array to select nothing. `finishedRetention` and `staleAfter` accept 1...86400 seconds. `hideWhenEmpty` and `showSymbol` default to true.

`symbols` and `tints` map state names to widget symbols and colors. Set symbol `font` and `size` defaults inside `agentActivity`. Top-level symbol, text and style overrides also apply. The symbol and tint follow this priority: `needsInput`, `failed`, `interrupted`, `working`, `unknown`, `idle`, `finished`.

Templates provide `total`, `status` and a count for each state, named after that state. For example, `{{working}} working · {{needsInput}} needs input` shows those two counts.

Inside a `sessions` loop, use `source`, `session`, `run`, `agent`, `host`, `title`, `project`, `status`, `elapsed` in seconds and `lastReported` as an ISO timestamp, plus the usual loop fields. Source and project filters apply to counts, template entries, labels and popup rows.

## Setup and diagnostics

Setup requires a config directory in `--root` and uses macOS's built-in Bash, `/usr/bin/jq` and `lockf`. It keeps unrelated settings and hooks. `--remove` deletes only sbar's integration.

Installed hooks call the sbar binary that ran setup. Rerun setup if that path changes. The following commands modify agent settings; review the generated files before enabling the hooks:

```fish
sbar agents setup --source codex --root "$HOME/.codex"
sbar agents setup --source claude --root "$HOME/.claude"
sbar agents setup --source pi --root "$HOME/.pi/agent"
sbar agents doctor --source codex
sbar agents setup --source codex --root "$HOME/.codex" --remove
```

Pass `--socket` during setup to use a different bar. Review and trust Codex hooks through `/hooks`; setup leaves trust and approval settings unchanged. Review Claude hooks through `/hooks` too. For pi, review the extension, then restart or reload pi.

Installed hooks hide reporting errors and send no approval decisions or text to the model. If sbar is unavailable, agent approvals stay unchanged. To see errors, run the installed adapter manually with `hook --source codex --socket PATH`, pass sample event JSON on stdin and omit `--quiet`. The hook cache at `~/.cache/sbar/agents` stores only run IDs and sequence numbers.

`agents doctor` finds the agent executable, reads its version and checks the connection to sbar. Review hook trust in the agent, then run a session and check that its activity appears in the bar.

## Supported agents and limits

Hook and extension APIs were checked on 2026-10-31 against codex-cli 0.166.0, Claude Code 2.1.314 and pi 1.4.0. The earliest compatible releases are not yet known.

### Codex

The adapter uses [Codex hooks](https://learn.chatgpt.com/docs/hooks) to report `working` on prompt and pre-tool events, `needsInput` on permission requests and `interrupted` on `Interrupt`. `Stop` and `SessionStart` report `idle`; `SessionEnd` dismisses the session. The hook API checked here has no general event for a settled response or fatal error.

### Claude Code

The adapter uses [Claude hooks](https://code.claude.com/docs/en/hooks) with `prompt_id`, session and tool events, permission and elicitation events, and `StopFailure`. `AskUserQuestion` reports `needsInput`. It ignores idle notifications. `Stop` and `SessionStart` report `idle`; `SessionEnd` dismisses the session.

Claude has no hook for a cancelled turn in the API checked here. Pressing Esc can leave the session showing `working` until another event arrives. sbar does not read the terminal to correct it.

Both Codex and Claude adapters omit `PostToolUse` because a late callback could change an idle session back to working. Setup removes earlier sbar registrations for that event.

### pi

The adapter uses the [pi extension API](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md): `before_agent_start`, the `turn_end` outcome, `agent_settled`, blocking `ui_prompt_start`/`ui_prompt_end` events and session events. After a normal response, the session reports `idle` and stays visible while waiting for another prompt. Errors report `failed`; cancellations report `interrupted`. `agent_end` alone does not confirm that pi has stopped working.

The extension sends heartbeats every ten seconds with a 30-second expiry. It does not collect UI prompt titles or message content.

### Agents hosted by T3 Code

Use the Codex or Claude adapter for sessions inside T3. The agent sends the reports, so each session appears once. No T3 adapter, polling or thread mapping is needed.

Rows use the agent's native session ID. They do not include T3 thread titles, links or a `host` value. Custom adapters can still supply host and identity metadata through the reporting API.

The launch code checked on 2026-11-03 was T3 `v0.1.7-nightly.20261102.4093`, with codex-cli `0.166.0` and Claude Code `2.1.317`. T3 launches Codex through `codex app-server`, which [supports lifecycle hooks](https://learn.chatgpt.com/docs/app-server). Normal Claude sessions use the Agent SDK's default `settingSources`, which [loads user, project and local settings](https://code.claude.com/docs/en/agent-sdk/typescript#settingsource). T3 disables hooks for Claude capability checks and title generation, so those requests do not create tracked sessions.

Pass the T3 provider's config directory to `agents setup --root`. The defaults are `~/.codex` and `~/.claude`, but provider settings, `CODEX_HOME` or `CLAUDE_CONFIG_DIR` can select another directory. Hooks cannot report if launch arguments or settings disable them or exclude user settings.

For Codex, open `/hooks` in a CLI using that same config directory and review the installed hooks. Setup does not grant trust. Then start a new T3 session to check reporting without interrupting existing work.

The code inspection confirms how T3 loads hooks. To check delivery in your setup, test prompt start, an approval or question, response stop and a second turn in each agent. Only Codex or Claude events update sbar; T3 dialogs and background-job waits have no separate reporter. Hosted sessions have the same restart and stale-state limits as standalone event hooks.

## Testing

Swift tests cover report ordering, simultaneous sessions, expiry, retention, filtering and identity matching. A process test checks that setup and diagnostics reject unsupported sources without changing configuration. Event translation and preservation of supported agents' settings have no dedicated automated tests.

Use the [standalone example](../../examples/agent-activity/README.md) to check the popup. To test hooks, review their trust settings and run agent sessions through prompt start, input waits and response stop. Check both standalone and hosted sessions if you use both.
