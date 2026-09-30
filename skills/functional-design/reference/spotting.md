# Where to apply functional design

Hunt list for planning and review. A hit is a place with **many combinable solutions**. For each hit, the shape is the same: **model** (ADT) + **constructors** + **combinators** + **interpreter(s)**. Skip thin CRUD, one-shot glue, and hot numeric loops.

Combinator vocabulary that keeps showing up: `++` / `andThen` (sequence), `&&` (both), `||` / `orElse` (fallback), `merge` / `zip` (combine), `map` / `flatMap`, unary decorators (`buffered`, `jittered`, `negate`).

---

## Scheduler / retry / calendar

**Problems:** backoff, poll cadence, "fetch every Wednesday at 6 and 12, and Thursday at :30", cron-like policies, meeting-slot intersection.

**Look for:** `retry` loops, `sleep` / `setTimeout` chains, scattered `cron` strings, `if (day === 3 && hour === 6)` calendars, copy-pasted backoff.

**Model:** `Schedule` — a solution to "when does this recur?" or "should I run *now*?"

**Constructors:** `exponential`, `fixed`, `recurs`, `weeks`, `daysOfTheWeek`, `hoursOfTheDay`.

**Combinators:** `andThen`, `&&` / `intersection`, `union`, `whileOutput`, `jittered`, `negate`.

**Interpreters:** `retry(effect, schedule)`, `occursAt(instant)`, test against a fake clock.

**Review smell:** policy baked into a worker loop; cannot combine two policies without a new function.

---

## Parser / grammar

**Problems:** email/URL/config/protocol text → structured values; files with repeating records.

**Look for:** regex soup, `split`/`indexOf` towers, recursive-descent functions that cannot be reused as pieces, `JSON.parse` plus ad-hoc string slicing.

**Model:** `Parser<A>` — consume input, produce `A` or fail.

**Constructors:** `char`, `string`, `succeed`, `fail`, `anyChar`.

**Combinators:** `andThen` / `~` / `+` (sequence), `orElse` / `\|` (fallback), `many` / `repeatedly`, derived `choice` = reduce `orElse`.

**Interpreters:** `run(parser, input)`. Optional: pretty-print the grammar (needs declarative encoding).

**Review smell:** one mega-`parseFile`; no way to compose "username" with "server".

---

## Validator / filter / rules

**Problems:** email folder rules, JSON-before-store, CSV schema mapping, feature flags as predicates, "subject contains X AND NOT to Y".

**Look for:** long `if/else` or boolean soup; a `*Service` that both decides and persists; a rule implemented twice (once to execute, once to show the user).

**Model:** `Filter` / `Validation` / `SchemaMapping` — a solution to "does this value match / reshape?"

**Constructors:** `senderIs`, `subjectContains`, `field("name").string(regex)`, `rename`, `delete`.

**Combinators:** `&&`, `||`, `!`; sequential `+`; `orElse`; `protect`.

**Interpreters:** `matches`, `describe`, `validate` (errors as data), `optimize`.

**Review smell:** cannot dump an English explanation without re-reading the `if`s; `senderIsNot` as a separate primitive instead of `not(senderIs(...))`.

---

## Stream / pipeline / ETL

**Problems:** files, FTP, S3, JDBC; concat fragments; failover; column rename/coerce; merge sources.

**Look for:** `InputStream` plumbing in business code; `try open A catch open B`; manual byte loops to glue files; a `PipelineService` with a method per step.

**Model:** `IStream` / `Pipeline` / `DataStream` — a source or a row flow, as a value.

**Constructors:** `empty`, `extract(repo)`, `suspend`.

**Combinators:** `++` (concat), `orElse` (failover), `merge` (both), `buffered`, `rename` / `coerce` / `delete` / `replaceNulls`.

**Interpreters:** `open` / `foreach` / load-to-sink. Optional: render the graph.

**Review smell:** concat and failover are one-off helpers that return `void` or mutate a shared buffer.

---

## Polling / worker / time

**Problems:** poll a queue, handle, idle, stop before a deadline. Tests cannot fake "now".

**Look for:** `DateTime.Now` / `new Date()` / `Time.now` inside transitions; I/O mixed into `switch (state)`.

**Model:** lifecycle ADT (`Ready | Received | NoMessage | Stopped`) **and** an instruction ADT (`CurrentTime | Poll | Handle | Idle`).

**Constructors:** `currentTime`, `poll`, `handle`, `idle`.

**Combinators:** `map` / `bind` (sequence instructions). Transitions: `State -> Program<State>`.

**Interpreters:** `interpret` in IO; test interpreter with a fake clock and queue.

**Review smell:** effects in the state machine; cannot replay a run.

---

## Real-world data

**Problems:** money, ids, payment methods, addresses — domain nouns left as `string` / `number` / `decimal`, or as a status plus optional fields.

**Look for:** `cardNumber: string`, `amount: number`, `method: "cash" | "check" | "card"` next to `checkNumber?` and `card?`.

**Model:** a distinct value (single-case wrapper), a discriminated union whose cases carry data (`Cash | Check of CheckNumber | Card of CreditCardInfo`), or a record built only from those types.

**Review smell:** the primitive leaks across the boundary; a new case is an extra optional field instead of a new union case. Full rule: `patterns.md`, "Real-world data".

---

## Lifecycle / state machine (nouns with illegal combos)

**Problems:** orders, jobs, connections, robots, polling states — flags that can contradict.

**Look for:** `status: string`; booleans `isReady && isStopped`; comments "don't extend both"; `if (msg == null)` on a "received" state.

**Model:** closed sum type. A received state *carries* the message. Stopped is not Ready with a flag.

**Constructors:** one per legal state (or smart constructors that return `Result`).

**Combinators / transitions:** total functions `State -> …` that pattern-match; no wildcard that hides a new case.

**Interpreters:** `step`, `render`, serialize.

**Review smell:** runtime checks for combinations the type should forbid.

---

## Optics / deep update

**Problems:** nested immutable records (`user.address.street`).

**Look for:** copy chains, scattered `spread` of the same path, mutable in-place nested edits.

**Model:** `Lens<S, A>` (or traversal). **Constructors:** `User.address`, `Address.street`. **Combinator:** `>>>`. **Interpreter:** `get` / `set` / `update`.

---

## Formula / spreadsheet / calculated value

**Problems:** user-defined calculations, typed expressions, "cell at (0,0) + cell at (1,0)".

**Look for:** `eval(string)`, untyped expression trees, `"1" + 2` slipping through.

**Model:** `CalculatedValue<A>`. **Constructors:** `const`, `at(col, row)`. **Combinators:** `+`, `-`, `map`. **Interpreter:** `evaluate`. Type parameter makes illegal ops unrepresentable.

---

## Workflow / quiz / conditional sequence

**Problems:** onboarding, quizzes, "if they fail the bonus, fall back to an easier one", turtle drawings, CMS components.

**Look for:** `void` step methods; a director class that calls other classes in order; UI listeners registered imperatively with no composition.

**Model:** `Quiz` / `Program` / `Drawing` / `Component` / `Listener`. **Combinators:** `+` (append), `orElse`, `check(pred)(pass, fail)`, `both`. **Interpreter:** `run`, `render`.

**Review smell:** steps cannot be reordered or reused without editing the director.

---

## Event / history patterns

**Problems:** "added to cart, then abandoned"; marketing sequences; audit queries.

**Look for:** ad-hoc loops over event lists; copy-pasted sequence detectors.

**Model:** `HistoryPattern` (`Event` | `Sequence` | `Repeat`). **Combinators:** `*>` (then), `atLeast`, `between`. **Interpreter:** `matches(history, pattern)`; optional `describe`.

---

## Resource acquire / release

**Problems:** files, pools, locks that must compose (zip two resources, orElse a fallback).

**Look for:** try/finally copied at every call site; a manager object with open/close `void` methods.

**Model:** `Resource<A>`. **Combinators:** `map`, `zip`, `orElse`. **Interpreter:** `use` that guarantees release.

---

## Integration of two domains

**Look for:** a parser that does I/O; a schedule that sends HTTP; a filter that writes to the DB.

**Fix:** keep each domain pure; interpret both into an effect type (`Promise` / `IO` / `ZIO` / `Effect`) in the service, and keep concrete I/O in adapters. Crossing contexts with the same type is a DDD boundary miss.

---

## Functional core vs imperative shell (and tests)

Not a domain of its own — a split every candidate must have. Full rules: `functional-core.md`.

- **Functional core** decides: values in, values or commands out. No I/O. Every domain rule lives here.
- **Imperative shell** does: fetch, call the core, perform effects, persist. Anything that evolves an effect (I/O, an external API) only matches the pure choice and carries it out — dumb dispatch, no second decision. Inside a larger shell, the service orchestrates through interfaces and the adapter knows the concrete database, API, clock, or SDK. One workflow is one sandwich; a layer cake splits into mini-workflows. Full rule: `functional-core.md` §3a and §5.

**Look for:** core functions taking `repo` / `gateway` / five collaborators; `Repo`, `Logger`, `DateTime.utc_now/0`, `Instant.now()`, HTTP, `Effect`, or `ZIO` inside decision logic; a business `if` inside the handler after the pure call (threshold, status, "should we email / charge / call this API?"); a pattern-match branch on an effect edge that does more than perform the choice; one function that alternates I/O and pure steps until it is a layer cake; a core unit test that constructs a mock; a shell test that calls a real payment or SMS vendor; a shell test that mocks the core, an internal module, or `Repo`; a service field that is a concrete client or SDK; `query(sql)` ports; business rules tested only through a fake repo; charging (or similar) before reserve so one function can stay "pure".

**Review smell:** the bulk of tests mock internals; the happy-path integration test is the only place edge cases live; the service was stripped of effects and the plumbing is awkward.

**Tests:** functional-core unit tests have **no mocks**. Imperative-shell tests **may mock external dependencies** (Mox, Bypass, test `Layer`) and use the real database. Fakes and a test clock for state you own. One shared contract suite for the fake and the live adapter. One smoke test.

---

## Least power — when not to hunt further

| Leave it | Because |
|---|---|
| Thin CRUD pass-through | One solution, not a family of combinable ones |
| One-off glue | A DSL used once is more cost than value |
| Hot inner numeric loop | Combinators belong at the API; the body may be an imperative loop |

If a candidate fails this table, list it under **Skip**, not under **Candidate domains**.
