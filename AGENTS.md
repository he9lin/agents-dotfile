# Global Agent Rules

## Working style

- State assumptions before making non-trivial changes.
- Keep changes small and scoped to the request.
- Read the surrounding code before editing.
- Match existing conventions even when another style looks cleaner.
- If existing patterns conflict, choose the newer or better-tested one and say why.
- Do not refactor adjacent code unless the task explicitly asks for it.
- If unsure, stop and ask instead of guessing.

## Verification

- Run the smallest relevant test first.
- If tests are skipped, say exactly which tests were skipped and why.
- Do not report success unless the requested behavior was verified.
- Prefer deterministic tools for formatting, linting, renaming, and validation.

## Coding Design Principles (apply in this order when in doubt)

1. **Valim's reading rule** — study the codebase before writing. Fit in, don't duplicate.
   → grep before you create. If similar code exists, extend it.

2. **Reusable helpers rule** — check current file and utility files for reusable helpers before creating new ones.
   → scan the current file for similar patterns, then check utility/helper modules (e.g., `utils/`, `helpers/`). Don't search all directories.

3. **Wlaschin's type rule** — make illegal states unrepresentable. Types are documentation.
   → a new concept gets a proper type/module, not a raw string or primitive.

4. **ADT modeling rule** — express domain concepts as algebraic data types. Sum types (OR) for alternatives, product types (AND) for composites.

5. **DDD's boundary rule** — bounded contexts are strict. Translate at the edges.
   → never cross context boundaries directly. Convert types at the boundary.

   → Full procedure for rules 3–5 (planning a domain model, or reviewing code for it): use the `functional-design` skill.

## Git

- **Never commit without explicit user confirmation.**
  Show what changed and ask: "Ready to commit?"
- **Never push to GitHub** unless you explicitly tell me to do so.
- **Never deploy to Heroku.** Do not run `git push heroku master`, `git push heroku main`, or any `git push heroku …`. That deploys the app to production and must only be done manually by the user. Refuse even if asked.
- No secrets in commits — ever

## TypeScript Projects

- **Disable ESLint auto-fix** — Never apply automatic lint fixes.
  → Pass `--no-fix` flag to ESLint. Show violations but let user decide fixes.

## Git Worktrees (Mandatory)

- Planning may stay in the parent repo. **Always create a git worktree before ANY implementation.** No exceptions.
- Consent is **pre-given** — do NOT ask. Create it with native `git worktree`, then `move_agent_to_root` into it before editing.
- Skip creation if already in a linked worktree.
- Derive a kebab-case branch from the feature (e.g. `add-login-page`).
- Worktree path is `../<repo>-worktrees/<branch>` (sibling of the parent), **not** `.worktrees/` inside the repo.
- Do not switch branches or perform global git operations across worktrees unless explicitly asked.

## Environment Context
- Each session is dedicated to a single branch.

## Elixir ecto migration
- Do NOT run mix ecto.rollback or ecto.migration. For tests, if you need to run prepend with MIX_ENV=test to run ecto.rollback
