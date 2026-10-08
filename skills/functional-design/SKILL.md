---
name: functional-design
description: Hunt for places to apply functional design while planning or reviewing a feature, project, or codebase. Use when planning a subsystem or internal DSL; modeling a domain with types; reviewing for ADTs, combinators, composability, orthogonality, and interpreters; or designing tests (functional core, imperative shell, effects at the edges). Trigger on retry/schedules, parsers, validators/filters/rules, streams/ETL, polling/workers, state machines, workflows, Mox/expect in unit tests, core functions taking services, DateTime.Now or Repo in domain logic, ZIO/Effect in domain signatures, concrete DB or SDK clients in services, mocks inside functional-core unit tests, duplicated run-vs-explain logic, business rules inside I/O and external-API branches, or real-world data left as raw string/number or as a status plus optional fields. Covers TypeScript, Elixir, Effect, ZIO, Rust, and F#. Functional-core unit tests use no mocks. The imperative shell may mock external dependencies. Effect edges only make dumb decisions by matching a pure choice; split a layer cake of alternating I/O and logic into mini-workflows.
---

# Functional Design

## Overview

In Functional Design, a functional domain consists of three things:

1. **MODELS.** A functional model, which is an immutable data type that models a solution to problems in the domain of interest. And we're often using ADTs (algebraic data types) to also enforce that invalid state should not be representable.

2. **CONSTRUCTORS.** Constructors that allow constructing solutions to simple problems.

3. **OPERATORS.** Operators that solve more complex problems by transforming and combining solutions for subproblems.

Operators are also called **combinators**. A small, composable set of primitives can describe *all* solutions in the domain. Treat the domain as an internal DSL.

That is also an **abstract data type**: a type plus the operations that construct and combine it. Callers compose values; they do not reach into the representation. The representation may be a function that runs now, or pure data interpreted later. Then **run / execute / interpret** the finished value. Behavior is something you can hold, pass, test, and describe — not only something you can fire.

| Part | Role | Lives as |
|---|---|---|
| **Models** | immutable data describing solutions, and real-world values | single-case wrapper, discriminated union (OR; cases may carry data), or record (AND) |
| **Constructors** | build solutions to simple problems | module / factory / companion functions |
| **Operators / combinators** | transform & combine solutions | functions on the model type |

Your global rules ("make illegal states unrepresentable", ADT modeling, translate at boundaries) are the **constitution**; this skill is the **playbook**.

Real-world data follows the same rule, even when it is a noun and not a combinator DSL. Always model it as an abstract data type or a discriminated union: a single-case wrapper (`CheckNumber of int`, `PaymentAmount of decimal`), an OR whose cases may carry data (`Cash | Check of CheckNumber | Card of CreditCardInfo`), or an AND record built only from those types (`Payment` is amount and currency and method). A raw `string` / `number` / `decimal`, or a status string plus optional fields, is not a domain type. See `reference/patterns.md` §1, "Real-world data".

## Functional core, imperative shell

Separate **deciding** from **doing**. Full rules: `reference/functional-core.md` (ZIO, Effect-TS, Elixir).

- The **functional core** decides. Pure functions take data and return data or commands. No I/O, no database, no HTTP, no clock, no randomness, no process messaging, no logging, no effect type in the signature. Pass `now` and ids in. If the core needs another fact mid-decision, the shell fetches it or the core returns a command (`NeedCustomerTier`) and the shell feeds the result back. Thresholds, status changes, and "should we call this API?" all live here.
- The **imperative shell** does. It fetches inputs, calls the core, performs the effects the core asked for, and persists results. It is the only place that talks to databases, HTTP, clocks, and SDKs. Anything that evolves an effect — I/O or an external API — makes only a **dumb decision** from the pure result: match the choice (`FullyPaid` → mark paid and post the event, `PartiallyPaid` → save the invoice, `NoActionNeeded` → do nothing) and carry it out. A business rule inside that branch has leaked out of the core. Full rule: `reference/functional-core.md` §3a.
- **Dependencies stay on the outermost edge**, so a core test never stubs them. With `ZIO` or Effect-TS, return the effect value and provide the dependencies when you run it. Without that library, pass them as arguments of the outermost function (`pay_invoice(command, invoices, events)`). Do not pass them into the pure function, and do not call `Invoices` or `Repo` directly from the edge.

**Unit tests of the functional core use no mocks.** Construct data, call the function, assert on the output, including emitted commands. No stubs, no `expect` / `to receive`, no test doubles. If a core unit test seems to need a mock, the code is not pure yet — move the I/O to the shell instead of mocking.

**The imperative shell may mock external dependencies.** Payment, SMS, email, third-party HTTP, and other systems outside your process are mocked through an explicit contract (`@behaviour` + Mox, Bypass, or a test `Layer`), including `expect`-style assertions when that call is what you are checking. Use the real database. Never mock the core, internal modules, pure functions, or your own repo to test business rules. Mocks are **nouns, not verbs**: every mock implements a contract.

When effects and decisions interleave, do **not** fetch every result up front if that changes ordering (charge before reserve). Split pure steps with the shell in between, or return commands and let the shell interpret them. Each effect step stays dumb dispatch. One workflow is one sandwich (fetch → pure decide → dispatch). If I/O and pure steps alternate until the function is a layer cake, split it into shorter mini-workflows so each stays a small sandwich (`reference/functional-core.md` §5).

Inside a larger shell, keep three rings. "Push effects to the edges" means **only the adapter knows concretely that a database, API, clock, or SDK exists.** The service may sequence effects through interfaces. A `ZIO` or `Effect` value is referentially transparent until run; a domain function that returns one is still shell, not core.

| Ring | Part of | Does | Tested with |
|---|---|---|---|
| **Domain** | Functional core | Rules and decisions. No effect type in the signature | Unit tests. **No mocks** |
| **Service** | Imperative shell | Fetch → pure decide → dumb dispatch, via interfaces | In-memory fakes of your ports, `TestClock`. Assert on state. Mock external dependencies here when a full-flow test is the right tool |
| **Adapters** | Imperative shell | Live DB, HTTP, SDKs, `main` | Real or recorded I/O. Mock only external dependencies, through a port you own |

Services depend on narrow, domain-shaped ports (`findDueReminders(date)`, not `query(sql)`). Wrap a vendor SDK in a port, then mock or fake that port — that is the external dependency. Concrete clients appear only in live layers (`provide` / `Layer` / config). Fakes and live adapters share a contract suite.

**Ratio.** Many core unit tests (no mocks) > moderate shell tests > a handful of adapter tests > one smoke test.

## Hunt first (required in both modes)

Before writing a plan or a review comment, **scan the feature, spec, or codebase for candidate domains**. A candidate is a place with **many solutions you want to combine** — policies, grammars, pipelines, rules, schedules, queries, workflows — not a procedure you will write once.

Do not skip this scan. Do not assume the whole app is one domain. Do not force a DSL onto thin CRUD, hot-loop numerics, or one-off glue.

For every candidate (and every skip), produce the fields in [Output](#output). Use the catalog in `reference/spotting.md` as the hunt list. Typical hits: **scheduler**, **parser**, **validator/filter/rules**, **stream/pipeline**, **polling/worker with time**, **lifecycle ADT**, **optics**, **formula**, **workflow**.

**Look-for (code and specs):** `retry`, backoff, cron, `setTimeout` chains; regex / `split` / hand-rolled grammars; `if` trees for "match this AND that"; `InputStream` / file concat / ETL steps; `DateTime.Now` / `DateTime.utc_now/0` / `new Date()` / `Instant.now()` inside business logic; stringly status flags (`"ready"|"received"|...` as `string` or booleans that can contradict); methods that return `void` and mutate; the same rule implemented once to run and again to explain or serialize; core functions taking `repo` / `gateway` / five collaborators; `Repo` / `Logger` / HTTP / `Effect` / `ZIO` inside the domain; a business `if` after the pure call, inside the branch that writes to the DB or calls an external API; one handler that alternates I/O and pure steps (a layer cake); a service holding a concrete HTTP, DB, or SDK client; `query(sql)` ports; unit tests that are mostly `expect(...).to receive` or "save was called once"; vendor SDK mocks; business rules tested only through a fake repo.

## Choose the encodings

Two independent decisions. Make both **before** writing behavior. State why.

### Model encoding — how the solution is represented

| | Executable | Declarative |
|---|---|---|
| Model is | function/interface that executes | pure data (ADT) |
| New constructors/operators | open | fixed |
| New ways to execute | fixed | open |
| Introspectable | no | yes |
| Pick when | operations must stay open | you need run / explain / serialize / test |

Default to **declarative** (data + interpreters). Go executable only when openness of operations outweighs introspectability. Tagless-final = executable with polymorphic solutions. Never embed a function inside a declarative model.

### Combinator encoding — how an operator is implemented

A combinator can often be implemented with different encodings depending on performance or language constraints:

1. **The Declarative/Recursive Way:** Defining combinators purely by composing other higher-order functions or using recursion (e.g., defining `filter` using `reduce`).
2. **The Imperative/Loop Way:** Writing a combinator using internal mutable loops for maximum execution speed while keeping the external API clean and declarative.

Callers still compose combinators; only the body changes. Default to declarative/recursive. Switch to an internal loop when recursion is a bottleneck. Never leak mutation into the API.

## Planning Mode

Complete every step. Do not approve a plan without the hunt output and, for each candidate you keep, design outputs 1–9.

0. **Hunt** — scan spec + existing code with `reference/spotting.md`. List candidates and skips.
1. **Name the domain** and the problems it solves.
2. **Sketch the model** — every real-world concept is a wrapper (distinct value), a discriminated union (OR; cases may carry data), or a record (AND) of those types. No raw primitives, no status string plus optional fields. Sum types for alternatives, product types for composites. Encapsulate behavior in the type when the "thing" is a policy, grammar, pipeline, or program — not only when it is a noun. See `reference/patterns.md`, "Real-world data".
3. **Choose the encodings** (tables above) and state why.
4. **List primitives** — constructors + operators (combinators). Every operator takes the domain type in and returns the domain type out. Tag primitive vs derived; demote anything expressible in terms of others.
5. **Test the primitives** — composable, expressive, orthogonal (no overlaps) → minimal. Check that real business sentences become composition (`primary.orElse(fragments).buffered`, `exponential.andThen(fixed)`, `username + char('@') + server`).
6. **Plan interpreters** — each execution concern (`run`, `describe`, `validate`, `preview`, `toJson`) as its own total function over the model. Effectful interpreters live in the service and depend on interfaces; concrete I/O stays in adapters. Multi-effect flows: the domain returns commands; the service interprets them.
7. **Constrain with types** — encode which operations are legal, at the strongest level the language allows.
8. **Put effects at the boundary** — service sandwich: fetch → pure decide → dumb dispatch. The edge matches the pure choice and performs it; domain rules stay in the core (§3a). The service depends on interfaces; concrete I/O is only in adapters (`provide` / `Layer`). Translate into the effect domain (`ZIO` / `IO` / `Promise` / `Effect`) in the service, not the domain. Preserve effect order. A layer cake of alternating I/O and logic becomes shorter mini-workflows, each one sandwich (see `reference/functional-core.md` §3a and §5).
9. **Plan tests** — functional-core unit tests with **no mocks**. Imperative-shell tests may mock external dependencies (Mox, Bypass, test `Layer`), use the real database, and must not mock the core or the repo to test rules. Inside the shell, prefer in-memory fakes and a test clock when asserting on state you own. A handful of adapter integration tests. One smoke test. Fakes and live adapters share a contract suite. Follow `reference/functional-core.md` §7–9.

## Review Mode

Scan in two passes. Report every finding with **name, severity, location, and fix**.

**Pass A — missed domains.** Walk `reference/spotting.md` and `reference/functional-core.md`. For each hit, if the code is a class/service/loop instead of model + constructors + combinators + interpreter, or if business logic lives in the service and is only tested with mocks, report **Missed domain** (not a style nit). Propose the type, constructors, combinators, interpreters, and the domain/service/adapter split.

**Pass B — malformed domains.** If a functional domain already exists (or should), scan for named violations:

| Violation | Symptom | Fix |
|---|---|---|
| Primitive obsession | raw `string`/`number`/`decimal` for a real-world concept, or a status string plus optional fields standing in for a choice | single-case wrapper, or a discriminated union whose cases carry the data; records compose those types only |
| Open inheritance taxonomy | class hierarchy with "don't extend both" rules | closed ADT |
| Void operator | returns `void`/`Unit`/`nil` | return a model value |
| God service | one class does six jobs | model + interpreters |
| Runtime check types could own | `throw` on a forbidden state | type-level constraint |
| Opaque AST node | function embedded in a data model | keep models pure data |
| Overlapping primitives | two primitives do the same job | keep one, derive the other |
| Effect in domain logic | I/O, clock, `Repo`, `Logger`, `Effect`, or `ZIO` inside the core, including an effect type in the signature | move orchestration to the service; pass time and IDs as values; return data or commands |
| Decision in the effect edge | an I/O or external-API branch contains a business rule (threshold, status check, "should we notify / charge / call?") | return a choice from the core; the branch only performs the effect |
| Layer cake | one handler alternates many I/O and pure steps, with policy between them | split into mini-workflows; each is fetch → pure decide → dumb dispatch |
| Core takes services | function args are `repo`, `gateway`, or a pile of collaborators | pass states and results; dependencies stay arguments of the outermost edge, or a `ZIO` / `Effect` environment provided at run |
| Hardcoded effect module | the edge calls `Invoices`, `Repo`, `Notifier`, or an SDK directly | pass that dependency as an argument of the outermost function, or return a `ZIO` / `Effect` and provide it at run |
| Concrete client in the service | service holds an HTTP client, pool, or SDK | depend on a trait; provide the live impl at the edge |
| Wide port | `query(sql)` or a pass-through of a vendor SDK | domain-shaped methods (`findDueReminders(date)`) |
| Mocked unit test | a functional-core unit test uses a mock, stub, or `expect` / `to receive` | purify the core; assert input → output. No mocks in core unit tests |
| Unmocked external dependency | a shell test calls a real payment, SMS, or third-party API | mock that external dependency through its contract (Mox, Bypass, test `Layer`) |
| Call-count test | assert "`save` called once with X" | fake and assert resulting state, unless the call itself is the requirement |
| Mocked database | business rules tested only through a fake or mocked repo | move the rules to the domain; fake the port only for service orchestration; hit real Postgres in adapter tests |
| Vendor SDK mocked directly | tests mock Stripe, Twilio, Google, or similar | wrap it in a narrow trait you own; fake that |
| Fake drifted from live | in-memory port never run against the live adapter | one shared contract suite for both |
| Services banned from I/O | plumbing exists only so the service stays effect-free | services may sequence effects through interfaces; only concrete I/O is edge-only |
| Reordered effects for purity | charge-then-reserve (or similar) so one function can stay "pure" | split steps or return commands; keep order |
| Non-exhaustive interpreter | wildcard default hides cases | total match, no catch-all |
| Leaky combinator | mutation or loop visible in the API | keep mutation inside; same declarative signature |
| Duplicated interpreters | run-logic copied into explain/serialize | one model, many interpreters |
| DSL for a one-shot problem | elaborate DSL used once | plain code (least power) |

## Output

Use this shape so hunt results cannot be skipped.

```
## Candidate domains
For each:
- Location (files, types, or spec section)
- Domain name (scheduler, parser, filter, stream, …)
- Evidence (what combinable solutions exist)
- Model / constructors / combinators (sketch)
- Encoding (model + combinator) and why
- Interpreters (`run`, `describe`, commands the service executes)
- Domain / service / adapter split; values in, choices or commands out; effect edge is dumb dispatch
- Tests: functional-core unit tests with no mocks; imperative shell may mock external dependencies only; real DB; fakes for state you own; shared contract suite; one smoke test
- Severity if review: missed vs malformed

## Skip
Places that are CRUD, glue, or one-shot — one line each, why least power applies.

## Plan or fixes
Only for candidates you keep. Planning: design outputs 1–9. Review: violation name, location, fix.
```

## Common Mistakes

- Jumping to services/classes before hunting for a domain
- Treating the whole application as one DSL
- Modeling nouns (User, Order) and skipping behavior-as-values (retry policy, filter, parser, pipeline)
- Leaving a real-world concept as `string`/`number`/`decimal`, or as a status plus optional fields, instead of a wrapper or a discriminated union
- Leaving either encoding choice implicit
- Adding convenience functions as new primitives instead of deriving them
- Validating with `if`/`throw` what a type could forbid
- Executing inside the model instead of writing an interpreter
- Exposing a mutable/loop implementation as the combinator's public contract
- Passing services into the core instead of values the service already fetched
- Calling `Invoices`, `Repo`, or an SDK directly from the edge instead of taking that dependency as an argument, or returning a `ZIO` / `Effect` and providing it at run
- Reading "push effects to the edges" as "the service may not do I/O"
- Treating a `ZIO` / `Effect` program as an effect-free core because the value is referentially transparent until run
- A functional-core unit test that needs a mock — the design is wrong, not the test
- Mocking the core, an internal module, or your own database from the shell
- Refusing to mock an external dependency in a shell test and hitting the real vendor instead
- Asserting call counts for an effect that shows up as state
- Mocking a vendor SDK instead of a port you own
- Testing business rules only through a fake repo
- Changing effect ordering so the code "looks pure"
- Putting a business rule in the branch that performs an effect (the edge re-decides instead of matching the pure choice)
- Letting one workflow grow into a layer cake instead of splitting it into mini-workflows

## Reference

- `reference/spotting.md` — where to look (scheduler, parser, validator, stream, …)
- `reference/functional-core.md` — effects at the edges: three rings, sandwich, dumb dispatch, layer cake, fakes, contract tests
- `reference/patterns.md` — patterns with code templates
- `reference/language-mapping.md` — TypeScript / Elixir / Rust / F# mappings
