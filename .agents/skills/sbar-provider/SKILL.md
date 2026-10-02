---
name: sbar-provider
description: Add, extend, or review built-in sbar data providers in this repository, including configuration, collection, lifecycle, presentation, templates, tests, documentation, and runnable examples. Use existing provider conventions rather than introducing a separate framework.
---

# Sbar provider

Read the current implementation before changing a provider. Paths below are relative to the repository root. Apply only the parts of this workflow affected by the request; a lifecycle fix does not require redesigning configuration or adding an example.

## Choose an existing model

Inspect repository instructions, the Makefile, and working-copy changes. Preserve unrelated edits and follow the user's requested bookmark and delivery scope.

Choose the closest provider by how it collects and shares data:

- `Runtime/Providers/Calendar/` uses an injected async reader, notifications, polling, and activation guards. Read its provider tests for queued callbacks across stop and restart.
- `Runtime/Providers/VPN/` uses native notifications and exposes multiple entries with aggregate status and per-entry template values.
- `Runtime/Providers/Disk/` and `Runtime/Providers/Weather/` show data keyed by path or location. Sampled metrics also use `SystemMetricsSampler.swift`.

These directories are under `Sources/SbarCore/`. Read the matching configuration, provider docs, and tests as well. Follow the selected provider's shape without copying unrelated states, settings, polling intervals, or abstractions.

## Wire the provider into sbar

For a new provider, trace these integration points. For an existing provider, revisit the affected contracts.

| Area | Files and responsibilities |
| --- | --- |
| Item configuration | `Sources/SbarCore/Configuration/Configuration.swift`: ItemType, Item properties, coding keys, initializer, decoding, and validation. Reject provider settings on the wrong item type. |
| Provider settings | `Sources/SbarCore/Configuration/<Name>Configuration.swift`: defaults, data selection, bounds, symbols, tints, and visibility rules. Keep provider-specific validation here. |
| JSON schema | `Sources/SbarCore/Resources/config.schema.json`: item type, settings property, and definitions matching decoding and validation. |
| Collection and state | `Sources/SbarCore/Runtime/Providers/<Name>/`: system access, collection lifecycle, state, and presentation. Keep substantial types in separate files. |
| State dispatch | `Sources/SbarCore/Runtime/Providers/WidgetState.swift`: state case, default text, and WidgetPresentation dispatch. |
| Template values | `Sources/SbarCore/Runtime/Providers/WidgetState+Text.swift`: scalar values and list entries. |
| Template validation | `Sources/SbarCore/Configuration/TextTemplate.swift`: supported fields, loops, and conditional status values. |
| Runtime | `Sources/SbarCore/Runtime/Providers/ProviderRuntime.swift`: activation, configuration changes, updates, shared or keyed state, refresh snapshots, and cleanup. |
| Permissions | `Sources/Sbar/Info.plist`: usage descriptions only when the chosen macOS API requires them. Inspect existing linker and bundle metadata wiring before adding anything else. |

Use `WidgetPresentation` and the existing views for ordinary provider output. Add view-specific handling only when the presentation cannot express the requested behavior.

## Configuration and presentation

Use top-level `text` for configurable labels. Do not reintroduce removed provider label maps or separate show-label and show-value options. Omitted `text` keeps the default presentation; an empty string hides the label. Keep CLI values and subscription events independent of display templates.

Expose useful fields through the shared template machinery. Define what each field contains when data is missing, and keep allowed fields and status comparisons consistent with runtime values. Add list loops only when the provider needs them.

Match comparable providers' visual options. Reuse WidgetSymbol and ItemSymbol for SF Symbols and font glyphs, including shared font and size defaults. Preserve top-level symbol overrides, showSymbol behavior, state tints, common item styling, and meaningful accessibility labels. Apply hide rules to confirmed empty or disconnected states; keep permission and read failures visible unless the user requests otherwise.

## Collection and lifecycle

Share collection across items and displays when the source supports it. Aggregate relevant settings across active items, including popup children, and restart collection only when its effective inputs change. Preserve other providers' state during reconfiguration. Key independent data sources by their actual input, such as path or location.

Define loading, empty, denied, and unavailable behavior where those states apply. Use native notifications when suitable, and choose polling or retries based on the source's behavior. Verify unfamiliar macOS APIs against current primary documentation before implementing them.

Make start and stop safe to repeat. Cancel owned tasks, remove observers or callbacks, and prevent updates after stop. For async reads and queued notifications, check cancellation and the active generation before starting work and after suspension. A callback from an earlier activation must not read or publish into a new activation. Use a separate refresh generation when overlapping reads could finish out of order.

Integrate event, interval, and manual item refresh through ProviderRuntime's existing snapshots. Check both text and presentation use the same selected snapshot, and that removing the last item stops collection and clears obsolete state.

## Tests, docs, and examples

Add regression coverage for the changed behavior. For a new provider, cover configuration defaults and invalid values, schema agreement, state selection, presentation overrides, templates, and refresh snapshots as applicable. Use injected readers or callbacks for lifecycle tests. Cover repeated activation, queued callbacks after stop or restart, stale async completions, and preservation of unrelated providers when those paths exist. Keep async waits bounded with the existing `waitUntil` helper.

Name suites for the production type, label tests with the member and condition, and order tests by the production declarations. Keep blank lines between logical setup, action, polling, and assertion blocks. Avoid production helpers whose only purpose is supporting cosmetic test organization.

Document new providers in `docs/providers/<name>.md` and add them to `docs/index.md`. Describe defaults, options, template fields, states, permissions, refresh behavior, and source limitations. Update `docs/text-templates.md` and other shared docs when their contracts change. Match sibling documents and keep detailed provider instructions out of the README.

Provide a complete `examples/<name>/config.json` and README for a new provider, unless the user chooses an existing example or asks to omit one. Include build, validation, start, and stop commands, plus any permissions or external setup needed. Use a separate example control socket. Edit `examples/everyday/` only when requested or chosen as the demonstration configuration.

## Validate and report

Use the current Makefile for formatting, build, lint, and tests. Format only changed files and validate each changed example with the development binary:

```sh
make build
make lint
make test
.build/debug/sbar validate --config "$PWD/examples/<name>/config.json"
```

For live verification, use the example's start and stop commands and avoid disrupting a running bar. Check the relevant source transitions, configuration reloads, item removal, and manual refresh. Unit tests with injected data do not verify a macOS permission prompt, connected hardware, or live system behavior.

Report implementation and configuration changes, checks performed, and remaining manual checks. Provide the runnable development-binary and configuration paths when manual testing is needed. Commit, push, or open a PR only within the user's requested scope.
