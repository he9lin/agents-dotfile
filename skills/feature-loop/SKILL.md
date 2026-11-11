---
name: feature-loop
description: Plan and implement a feature with functional-design, then iterate on independent review-design feedback from a different model. Use when the user requests feature implementation with an automatic implementer/reviewer loop or invokes feature-loop.
---

# Feature Loop

Coordinate feature delivery using the existing functional-design and review-design skills. The main agent is the sole point of contact for the user. It owns planning, decisions, verification, and delivery, and delegates implementation, repairs, and independent review to worker agents. Workers report results and blockers to the main agent, which handles all user questions and approvals. This skill explicitly requests delegation for implementation and review.

## Setup

- Read applicable AGENTS.md and repository instructions. Preserve their worktree, permissions, verification, commit, and push requirements. This workflow grants no additional external-action permissions.
- Locate and read functional-design and review-design from the available skill catalog. Follow their referenced procedures where applicable rather than reproducing or weakening them here. If either dependency is missing, stop and report it.
- Default to two review passes; accept an explicit limit of one to three. A pass means one review of the current change, not one finding or repair.
- Resolve the implementer's model and an explicitly selected, different reviewer model from the request or a documented project setting. If the reviewer choice is missing, the implementer identity cannot be verified, or the requested reviewer cannot be launched, ask for the missing choice or report the limitation. Do not silently substitute models or claim model independence merely because a fresh agent was created. Continue independent repository exploration while awaiting a choice, but do not start the review loop without it.
- Use the available delegation mechanism that supports the selected model. If the user selects a different agent product/provider, follow the applicable orchestration skill instead of treating an unrelated local model as equivalent.

## Multiple repositories and worktrees

Support both a feature spanning several repositories and unrelated feature loops running concurrently. Keep each loop's requirements, rounds, findings, and reports separate; related repositories may share one coordinated plan and review pass limit.

Before editing, establish a repository map. For each participating repository record a unique label, absolute original checkout and selected worktree paths, Git common directory, branch, starting HEAD SHA, initial tracked/staged/untracked status, applicable instructions, owned scope, worker/pane IDs, dependencies on other repositories, and verification commands. Inspect `git rev-parse --show-toplevel`, `git rev-parse --git-common-dir`, `git worktree list --porcelain`, and `git status --short` from each checkout. Resolve paths before comparing them: two worktrees of the same Git common directory are not independent repositories. Ask for repository paths only when the requested scope cannot be established from the workspace or user-provided context; do not search or modify unrelated repositories.

Follow the user's worktree rules separately for each repository. Reuse an existing linked worktree only when its task/branch matches the requested work and its initial changes are understood. Never implement on main/master, even in a linked worktree. If no suitable linked worktree exists, create a new feature branch with native `git worktree` at `../<repo>-worktrees/<feature-branch>` relative to the parent repository. Resolve collisions without reusing another task's branch. Use `move_agent_to_root` when available; otherwise disclose its absence and explicitly set every operation's working directory. Never switch an occupied checkout's branch, stash/discard unrelated edits, or clean/remove another task's worktree.

Assign one writer to each worktree at a time. Independent writers use different worktrees; do not treat that isolation as automatic integration. Coordinate any later integration explicitly within the authorized task. For features spanning repositories, partition edits by repository and document API/schema/artifact dependencies and execution order. Use explicit local paths/configuration to connect the selected worktrees; do not accidentally test against an original checkout or deployed service. Preserve each repository's domain boundaries and translate shared contracts at its adapters.

Launch every worker with an explicit working directory and the repository map relevant to its assignment. Include repository label and role in worker labels; scope temporary report paths by task, repository, and review pass so concurrent loops cannot overwrite each other. Before edits, tests, and reviews, confirm the expected worktree/branch. If another process changes HEAD, branch, or the reviewed files, reassess the baseline and invalidate stale review evidence.

Capture the feature baseline per repository before implementation. Review feature changes against that baseline plus staged, unstaged, and new files, while distinguishing pre-existing edits from this task's changes. A clean status alone does not prove the feature diff is empty. Do not expose unrelated edits as task work or reset them to simplify review.

A review pass covers all participating repository changes and their cross-repository contracts. The reviewer may traverse multiple roots using explicit paths; identify every finding by repository and file. Where separate reviewers are needed, combine their results as one coordinated pass and require all relevant reports before counting it complete. Verify each repository separately, then run the relevant cross-repository flow when feasible. Report exactly which worktree versions participated and any integration checks that could not run. Never infer end-to-end success from isolated repository checks.

## Model preferences and host client

Treat workflow, host client, implementer model, and reviewer model as separate choices. A skill provides instructions; it cannot change the model already serving a GUI conversation.

Precedence: explicit task choice, explicit project configuration, host-specific preference, then task-size preference.

- Only when the user is working in the Cursor GUI app, prefer the user's Grok 4.7 selection for implementation, for both small and large work. Keep implementation in Cursor rather than moving it to Codex or Claude merely to satisfy the general task-size preference. If Grok 4.7 is not selected or available, explain the mismatch and ask the user to select it or authorize an alternative. Do not claim to switch a GUI model through skill text.
- The Grok 4.7 preference is exclusive to work performed in the Cursor GUI app. Do not select it for Codex, Claude, Cursor CLI, or external terminal workers/reviewers, even when their terminal is embedded in Cursor or their parent coordinator runs in Cursor. Being in a repository used by Cursor is not evidence of running in the Cursor app. If the host is unclear, ask before applying this override. A later explicit user instruction may override this restriction.
- Outside that Cursor app override, prefer Sol for small fixes and updates. Small means a bounded behavioral change with established architecture, not merely a small diff.
- For big features, prefer Opus or Astra. Big includes new domain behavior, architectural decisions, or substantial cross-module changes. Use an explicit user/project choice first; otherwise use the already-selected model if it is one of these preferred families. If neither is selected and both are available, ask which to use. Do not invent a preference between Opus and Astra.
- If the active model does not match the preference, disclose it. A supported visible worker may perform implementation on the preferred model; otherwise ask for a client model switch or an authorized alternative before implementation. Do not silently label the current model as the preferred one.
- These are user-provided model names, not verified provider IDs or availability claims. Resolve exact selectable IDs from the actual client/CLI before launch; never invent model flags or assume cross-provider access.
- Choose the reviewer separately using the Setup requirements: an explicitly selected different model is still required. Cursor's implementation preference does not extend to external reviewers; do not select Grok 4.7 for them. Visible review workers may run through Rex or Herdr if the environment supports control; otherwise report the limitation and ask how to proceed.

## Plan and implement

1. Read the feature requirements, surrounding code, and nearby reusable helpers. State assumptions, acceptance criteria, exclusions, and the verification approach. Ask about material ambiguities rather than inventing requirements.
2. Apply functional-design Planning Mode, including the required candidate-domain hunt, skips, and design outputs for retained candidates. Preserve its least-power guidance for CRUD and one-off glue.
3. Proceed with implementation when authorized; do not invent a separate plan-approval gate. Establish the required branch/worktree before launching the implementation worker. Give it the approved scope, plan, acceptance criteria, and verification commands. Have it apply functional-design to the code and tests and report its changes and check results to the main agent.
4. Run the smallest relevant checks first. Have the implementation worker correct failures before requesting review. If checks cannot run, retain the exact limitation in the review packet and final report; do not label the change verified.

## Visible worker panes

Run delegated workers as visible terminal agent sessions. Read the installed Rex skill or `herdr --skill` for the terminal manager hosting the main agent. Herdr control requires `HERDR_ENV=1`. If visible launch is unavailable, report the limitation to the user.

In Rex, keep the main agent in its current tab. Start each new worker agent session in a new pane in that same tab, with an explicit worktree, descriptive label, and `--focus=false`. Use `rex session inspect "$REX_SESSION" --json` to find the tab containing the main agent's pane and inspect its tiled layout before each launch. Count all existing columns, including the main agent and completed workers, using the distinct left edges of tiled pane rectangles.

- Below three columns, use `rex split --split=right` only if the resulting layout stays within three columns. Otherwise use `--split=below`.
- At three columns or more, use `rex split --split=below` on an existing worker pane, or the main pane if there is no worker pane. This stacks the new pane in the same column. Never open another tab for a Rex worker.

Serialize pane creation and record each returned pane ID. Keep completed panes available for inspection. Use the selected agent/model's verified CLI options and preserve its approval and sandbox controls. For Rex workers, require a complete report at a task-specific temporary file path. Verify the worker process completed and read the report before proceeding. Captured terminal output is progress evidence.

In Herdr, preserve focus, record worker identifiers, and use its agent lifecycle and prompt/wait/read controls. Inspect blocked or unknown states and use the documented file-output fallback when needed.

## Independent review

Run reviews sequentially; never let the reviewer and implementer mutate the same files concurrently. Start a fresh reviewer context for each pass, with the explicitly selected different model. Do not pass the implementer's full conversational history or a desired verdict.

Give the reviewer:

- Original requirements, acceptance criteria, exclusions, and current plan.
- Repository map with absolute worktree locations, per-repository baselines and instructions, cross-repository contracts/dependencies, and paths to both dependency skills.
- A precise baseline and change scope covering the entire feature: tracked edits, staged edits, and untracked/new files. Never review only the latest repair when earlier feature changes still matter. Do not create commits merely to establish a baseline.
- Actual verification results and known limitations.
- On later passes, prior findings and their dispositions as claims to independently verify.

Instruct it to read the current files and surrounding code, apply review-design, and use functional-design Review Mode for relevant domain/type/effect/test concerns. Review without editing or performing externally mutating actions. It may run suitable read-only checks.

Require a concise report containing:

- Findings with stable IDs, severity, file/symbol location, concrete evidence, consequence, and a suggested fix.
- Whether prior findings are resolved, remain, or were superseded.
- Unmet acceptance criteria and verification gaps.
- An explicit statement when no actionable findings were found. Review approval is not human approval and does not establish correctness.

## Resolve and repeat

For every finding, record one disposition: fixed (with evidence), declined (with a concrete reason), or deferred (with impact and why it remains). Evaluate the evidence; do not automatically implement every reviewer preference. A bold redesign suggestion does not authorize adjacent refactoring. Escalate material scope or product decisions to the user.

Delegate fixes to an implementation worker. After fixes, rerun affected checks and request the next review on the complete updated feature. Declined findings may be challenged by the reviewer; do not hide them or treat them as resolved by assertion.

Stop early when the current pass has no actionable findings, prior material findings are resolved or explicitly dispositioned, and required verification passes. Otherwise continue until the configured pass limit.

At the limit, a final repair may be made and checked, but identify it as not re-reviewed. Do not start an extra review pass, relabel unresolved findings as clean, or continue an unbounded repair loop. Stop and report unresolved findings, conflicting advice, repeated failures, or required user decisions candidly. A reviewer timeout or launch failure is not a clean review and must not consume silent retries indefinitely.

## Deliver

Report each repository/worktree/branch and its changed scope, cross-repository integration status, implemented behavior, checks and actual results, implementer/reviewer model identities, number of completed review passes, important finding dispositions, and remaining risks or unreviewed final edits. Include screenshots/demo evidence when the feature or project requires it. Do not report success unless the requested behavior was verified. Follow existing human approval rules; never commit, push, or publish merely because the loop completed.
