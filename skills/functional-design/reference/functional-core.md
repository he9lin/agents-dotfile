# Functional Core, Imperative Shell

Reference for functional design reviews. Applies to ZIO (Scala), Effect-TS, Elixir, and ZIO-style effect systems in other languages.

## Best practice

Separate **deciding** from **doing**.

- The **functional core** decides: pure functions, data in, data or commands out. No I/O, no database, no HTTP, no clock, no randomness, no logging, no effect type in the signature. Every domain rule lives here — thresholds, status changes, "should we notify?", which API call to make.
- The **imperative shell** does: fetch inputs, call the core, perform commanded effects, persist results. It is the only code that knows about databases, HTTP, clocks, and SDKs. Code that performs an effect makes only a **dumb decision**: it matches the core's result and carries that choice out. It does not re-decide.

**Unit tests of the functional core use no mocks.** Construct values, call the function, assert on the result. If the test needs a mock, I/O has leaked into the core.

**The imperative shell may mock external dependencies.** Payment gateways, SMS, email, third-party HTTP, and similar systems are mocked through an explicit contract (Elixir `@behaviour` + Mox, Bypass, or a test `Layer`), including `expect`-style assertions. Use the real database. Do not mock the core, internal modules, pure functions, or your own repo to test business rules.

Sections 1–6 say where, inside that shell, effects are orchestrated (service) versus performed for real (adapters). Sections 7–9 say how to test each ring without breaking the two rules above.

## 1. Precise rule

"Push effects to the edges" does **not** mean "only the outer layer may do I/O."

It means: **only the edge knows concretely that a database, API, clock, or SDK exists.**

> Effects are orchestrated in the service layer through interfaces. Concrete I/O lives only in the adapters at the edge. The domain layer is pure and tested without effects.

Older notes call the outside the **shell**. That shell is two rings: the **service** (orchestration) and the **adapters** (concrete I/O). The **domain** is the core. Services may sequence effects. Banning I/O from the service produces awkward plumbing; that misreading is a defect, not a stricter design.

Pushing the effect out is only half the rule. The code that performs it — service or adapter — does not contain the domain decision. It dispatches on the core's choice (§3a).

## 2. The three rings

| Ring | Contains | Effects? | Knows about infrastructure? | Tested with |
|---|---|---|---|---|
| **Domain (pure core)** | Rules, validation, state transitions, decisions | None. No `ZIO` / `Effect` / `Task` in signatures | No | Plain unit tests, property tests |
| **Service (orchestration)** | Use cases: fetch → pure decide → dumb dispatch | Yes, sequenced | Only via interfaces (`trait ApptRepo`, `Context.Tag`, Elixir `@behaviour`) in the environment | In-memory fakes, `TestClock` / `TestRandom` |
| **Adapters / edge** | Live layers: DB pool, HTTP clients, SDKs, `main` | Yes, real I/O | Yes, concretely | Integration tests (Testcontainers, Ecto SQL Sandbox, recorded HTTP) |

| Ring | ZIO | Effect-TS | Elixir |
|---|---|---|---|
| Domain | plain functions, `Either` | plain functions | modules with no `Repo` |
| Service | `ZIO` with traits in `R` | `Effect` with `Context.Tag` | context function calling behaviours |
| Adapter | `ZLayer` live, wired with `provide` | `Layer` | `Repo`, HTTP client, impl selected in config |

## 3. Service shape: the sandwich

Fetch (effect) → decide (pure) → dumb dispatch (effect).

```scala
def reschedule(id: ApptId, t: Instant) =
  for {
    appt <- ZIO.serviceWithZIO[ApptRepo](_.get(id))          // effect
    now  <- Clock.instant                                     // effect
    next <- ZIO.fromEither(Appt.reschedule(appt, t, now))     // PURE
    _    <- ZIO.serviceWithZIO[ApptRepo](_.save(next))        // effect
    _    <- ZIO.foreachDiscard(next.events)(Notify.send)      // effect
  } yield next
```

`Appt.reschedule` never sees a repo, clock, or effect type. The service passes it data, including "now," and it returns a new value plus events or commands describing what should happen. Saving `next` and sending `next.events` are dumb: the service does not inspect the appointment and decide whether to notify.

Same shape in Elixir. `DateTime.utc_now/0` stays in the service; the domain receives `now`:

```elixir
def reschedule(id, new_time) do
  with {:ok, appt} <- Appointments.get(id),
       now = DateTime.utc_now(),
       {:ok, next} <- Appt.reschedule(appt, new_time, now),
       :ok <- Appointments.save(next) do
    Enum.each(next.events, &Notify.send/1)
    {:ok, next}
  end
end
```

## 3a. Dumb dispatch at the effect edge

Push every domain decision into the core. Anything that evolves an effect — a database write, an event post, an HTTP call, an external API — makes only a dumb decision from the pure result. It matches a choice the core already returned and performs the corresponding effect. It does not ask a new business question.

Two legal shapes:

1. **Uniform.** The core returns the new state plus events or commands. The edge saves the state and runs each command. No branch inspects business data. The reschedule sandwich above is this shape.
2. **Choice match.** The core returns a closed sum. The edge has one branch per case. Each branch is a straight-line effect, or nothing.

```elixir
def pay_invoice(command) do
  unpaid = Invoices.load_unpaid!(command.invoice_id)

  case Invoice.apply_payment(unpaid, command.payment) do
    :fully_paid ->
      Invoices.mark_fully_paid!(command.invoice_id)
      Events.post_invoice_paid!(command.invoice_id)

    {:partially_paid, updated} ->
      Invoices.update!(updated)
  end
end
```

`Invoice.apply_payment` decides fully versus partially paid. The handler does not re-check the amount, the status, or a threshold. A branch that asks "is this too large?", "should we notify?", or "is the customer overdue?" is a domain rule sitting on the effect edge. Move that rule into the core and return another choice (`:overdue_warning_needed` or `:no_action_needed`). The edge then sends the message, or does nothing.

The same rule covers every effect, not only the database. The core names the effect as data (`Charge(amount, card)`, `SendWarning(customerId)`). The edge performs that effect. When a later pure step needs the outcome (a charge id, the row just written), the edge passes that outcome back in as data. It does not invent the next business step.

## 4. Design practices

1. **Pass data into the core, not dependencies.** If a domain function takes a repo, client, or effect, it is not core.

   ```elixir
   # BAD: core receives a service it must call
   def process(order_id, repo, gateway), do: ...

   # GOOD: core receives data the service already fetched
   def reserve(order, inventory_state), do: ...
   ```

2. **Inject time, IDs, and randomness as inputs** (`now: Instant`, `newId: ApptId`). Never call `Instant.now()`, `DateTime.utc_now/0`, `new Date()`, UUID generators, or random inside the core.
3. **Return decisions, don't perform them.** The core returns values, `List[Event]`, or commands like `SendSms(to, msg)`, or a choice such as `:fully_paid | {:partially_paid, invoice}`. The edge matches that result and performs it. Branches stay dumb (§3a).
4. **When the core needs data mid-decision,** fetch it first in the service, or have the core return a command (for example `NeedCustomerTier`) that the service executes and feeds back. Do not query the database from inside a validation function.
5. **Services depend on interfaces, never concrete clients.** Concrete infrastructure appears only in live layers wired at startup (`provide` / `Layer`, or Elixir config). Never hardcode an HTTP client, pool, or SDK inside the service or the domain.
6. **Don't mock what you don't own.** Wrap third-party SDKs (Google Ads, Twilio, Stripe) in your own narrow trait (`AdsGateway.createCampaign`). Fake the trait; integration-test the wrapper.
7. **Keep interfaces narrow and domain-shaped** (`findDueReminders(date)`, not `query(sql)`), so fakes stay small.

Your own database is a port you own (`ApptRepo`), not a vendor SDK. The service depends on that port. The Postgres implementation is an adapter.

## 5. When effects and decisions interleave

Do not fetch every effect result up front if that changes ordering (charging a card before inventory is reserved). Use one of these instead. Either way, each effect line is still dumb dispatch (§3a): it performs the choice the previous pure step returned. It does not insert a new policy between steps ("also waive the fee if the customer is gold").

**A. Split into pure steps**, with the service performing effects between them. The pure step returns the command; the edge only runs it, then feeds the receipt back as data:

```elixir
with {:reserved, _inv, charge} <- Order.Core.reserve(order, inventory), # pure choice
     {:ok, receipt} <- gateway().charge(charge.amount, charge.card),    # dumb: run it
     {:ok, order} <- Order.Core.finalize(order, receipt) do              # pure, given the receipt
  ...
end
```

**B. Return commands (preferred for multi-effect flows).** The core returns a description of effects as data; the service interprets them. The interpreter is a straight loop or a total match — run this command, then the next — not a place for business rules.

```elixir
def decide(order, inventory) do
  case Inventory.reserve(inventory, order.items) do
    {:ok, inv} ->
      {:ok, inv, [{:charge, order.total, order.card}, {:notify, order.email}]}
    {:error, :insufficient_stock} ->
      {:error, :out_of_stock, []}
  end
end
```

Commands make "which effects happen, in what order" pure and testable. `NeedCustomerTier` is the same idea when the next pure step needs data the core does not have yet.

**Layer cake.** One workflow is one sandwich: I/O → pure → I/O. Stacking several decisions in one function (I/O → pure → I/O → pure → I/O) turns that sandwich into a layer cake. A short stack is fine when each effect is dumb dispatch and effect order must be preserved, as in A and B above. When the function keeps growing, or business conditionals show up between the effects, break it into shorter mini-workflows. Each one is a small sandwich: load what that decision needs, call one pure function, match the choice, perform the effects. The next workflow loads whatever the previous one persisted.

Paying an invoice and warning on a large balance are two sandwiches, not two layers of `pay_invoice`:

```elixir
def warn_if_balance_too_large(customer_id) do
  amounts = Invoices.load_unpaid_amounts!(customer_id)

  case Balance.assess(amounts) do
    :overdue_warning_needed -> Notifier.send_warning!(customer_id)
    :no_action_needed -> :ok
  end
end
```

`Balance.assess` decides. `warn_if_balance_too_large` only sends, or does nothing. Folding that decision into `pay_invoice` would mix a second policy into the payment edge.

## 6. Referential transparency

Effect values (`ZIO`, `Effect`, `IO`) are referentially transparent until run, so in the strict FP sense the whole program is "pure." The core/shell split is a stricter, practical discipline on top: an **effect-free** core, not merely a referentially transparent one. A domain function that returns `ZIO` is still in the service ring.

## 7. Testing strategy

Two rules, in this order:

1. **Functional-core unit tests have no mocks.** No stubs, no `expect`, no test doubles. Data in, data or commands out.
2. **Imperative-shell tests may mock external dependencies**, and only those. Real database. The mock implements your contract for that external system.

"Unit tests should not have effects" means the core tests have no real I/O and no nondeterminism. It does not ban effect types in shell tests, and it does not ban mocking an external dependency from the shell.

| Layer | Where | Test type | Doubles allowed |
|---|---|---|---|
| Domain (pure) | Functional core | Unit and property tests: input → output | **None.** |
| Domain returning commands | Functional core | Unit tests asserting on emitted commands | **None.** |
| Service | Imperative shell | Orchestration: fetch → pure decide → dumb dispatch | In-memory fakes of your ports, `TestClock` / `TestRandom`. Mock an external dependency when the shell test is checking that call. |
| Adapters | Imperative shell | Integration test of one adapter | Real Postgres (Testcontainers, Ecto SQL Sandbox) or recorded HTTP (WireMock, Bypass). |
| Wiring | Imperative shell | One smoke test: the layer graph builds and one request runs end to end | Real DB. External dependencies mocked through your ports. |
| External HTTP / SDK | Imperative shell | Shell test of the integration, plus a wrapper test | Mock or fake the port you own (`PaymentGateway`, `AdsGateway`). Do not mock the vendor SDK type itself. |

**Rough ratio.** Many domain tests > moderate service tests with fakes > a handful of adapter integration tests > one smoke test.

### 7a. Functional core: no mocks

Most tests live here. A unit test of the core has no mocks, stubs, or `expect`-style call assertions. If it needs one, I/O has leaked into the core.

```scala
test("can't reschedule into the past") {
  val appt = Appt(id, start = t0, status = Booked)
  assert(Appt.reschedule(appt, newTime = t0.minusHours(1), now = t0))(
    isLeft(equalTo(RescheduleError.InPast)))
}
```

No mocks, stubs, or `expect`-style call assertions. Construct input data, call the function, assert on the output (including emitted commands).

### 7b. Service: fakes for state you own

These shell tests are effectful, deterministic, and fast. For ports whose outcome you can see (a saved appointment, a recorded notification), use an in-memory fake and assert on **resulting state**, not "`save` called once with X".

Mocking is for **external dependencies** in the shell (section 7e), not for the core and not for your own database.

```scala
final case class InMemoryApptRepo(ref: Ref[Map[ApptId, Appt]]) extends ApptRepo {
  def get(id: ApptId) = ref.get.map(_(id))
  def save(a: Appt)   = ref.update(_ + (a.id -> a))
}

test("reschedule persists and notifies") {
  for {
    _     <- TestClock.setTime(t0)
    _     <- reschedule(id, t1)
    saved <- ZIO.serviceWithZIO[ApptRepo](_.get(id))
    sent  <- ZIO.serviceWithZIO[FakeNotify](_.sent)
  } yield assertTrue(saved.start == t1, sent.size == 1)
}.provide(InMemoryApptRepo.layer, FakeNotify.layer)
```

Business rules do not belong in these tests. If the only test of a rule drives a fake repo, move the rule to the domain and test it with values. The fake covers orchestration: the decision was persisted and the notification was recorded.

In Elixir, a context that calls `Repo` directly is tested through the public entry point against SQL Sandbox (section 7e). That is the smoke path. Do not add Mox on `Repo` to test rules. Extract a behaviour when you want a fast in-memory fake or when the dependency is a third party; then share a contract suite with the `Repo`-backed impl (section 7d).

### 7c. Adapters: few, real integration tests

- DB adapters against real Postgres (Testcontainers or Ecto SQL Sandbox).
- External API clients against recorded responses (WireMock, Bypass), plus occasional sandbox runs.
- This is the only place SQL and wire formats are verified.

### 7d. Keeping fakes honest

Run one shared contract suite against both the fake (`InMemoryApptRepo`) and the live adapter (`PostgresApptRepo`) so the fake cannot drift. Same suite, two implementations.

### 7e. Imperative shell: mock external dependencies

One smoke test: the full layer graph builds and one request runs end to end. In Elixir that is the public context function against the real test DB.

The shell may mock external dependencies. That is the normal way to test a charge, an SMS, or a third-party HTTP call without leaving the process. Put the mock on the contract you own (`PaymentGateway`, `Notifier`), not on the vendor SDK class and not on the functional core.

`expect`-style assertions belong here: "a charge of 100 was sent", "a confirmation SMS was sent to this number", "no charge was made when stock ran out". They do not belong on internal modules, the domain, or your database. When the effect lands in state you own, assert on that state instead of the call count.

```elixir
# The charge and SMS are the requirement; the paid status is owned state
test "successful order charges the card and sends confirmation" do
  order = insert(:order, total: 100)
  insert(:inventory, items: order.items)

  expect(PaymentGatewayMock, :charge, fn 100, _card -> {:ok, %{id: "ch_1"}} end)
  expect(NotifierMock, :send_confirmation, fn _email -> :ok end)

  assert {:ok, %{status: :paid}} = Orders.process(order.id)
  assert Repo.get!(Order, order.id).status == :paid
end
```

Keep smoke and failure-path tests few: happy path plus one test per distinct failure-handling path (for example compensation after a failed charge).

### 7f. Rules for doubles

- **Core unit tests: no mocks.**
- **Shell tests: mocks only for external dependencies**, through a contract you own. Mox, Bypass, and a test `Layer` are the usual tools.
- Mocks are **nouns, not verbs**: every mock implements an explicit contract. Never create an ad-hoc double with no behaviour or interface behind it.
- Never mock the functional core, internal modules, structs, or pure functions.
- Never mock `Repo`, the SQL driver, or a connection pool. Use the real database in shell tests.
- Never mock a vendor SDK type directly. Wrap it (`AdsGateway.createCampaign`) and mock that port — the port is the external dependency.
- For state you own, assert on outcomes (returned values, persisted rows, emitted commands, the fake's recorded outputs) rather than internal call sequences.

## 8. Red flags

| Smell | Fix |
|---|---|
| Validation function queries the DB mid-way | Fetch first in the service, pass data in |
| `Instant.now()` / `DateTime.utc_now/0` / UUID inside a rule | Take `now` / `id` as parameters |
| Functional-core unit test needs a mock | Move I/O to the shell; pass data. Do not add the mock |
| Shell test has no seam for an external dependency | Add a contract and mock it (Mox, Bypass, test `Layer`). Do not call the real vendor |
| Shell test mocks the core, an internal module, or `Repo` | Mock only external dependencies. Use the real database |
| `ZIO` / `Effect` in a domain signature | Return data or commands; sequence effects in the service |
| Service holds a concrete HTTP, DB, or SDK client | Introduce a trait; provide the live impl at the edge |
| Port is `query(sql)` or a pass-through of the SDK | Narrow, domain-shaped methods |
| Tests verify "method X called with Y" | Use a fake and assert on resulting state, unless the call itself is the requirement |
| Mocking a vendor SDK directly | Wrap it in your own trait; fake that |
| Business rules tested only through a fake repo | Move the rules to the domain; keep the fake for orchestration |
| In-memory fake never run against the live adapter | One shared contract suite for both |
| "Services can't do I/O" leads to awkward plumbing | Services may orchestrate I/O via interfaces; only concrete I/O is edge-only |
| Charge-then-reserve (or similar) so one function can stay "pure" | Split steps or return commands; keep order |
| Business rule in an effect branch (threshold, status check, "should we email / charge / call this API?") | Return a choice from the core; the branch only performs the effect |
| One handler alternates I/O and decisions until it is a layer cake | Split into mini-workflows; each is one sandwich with dumb dispatch |
| Unit test is mostly `expect` / `to receive` on internals | Purify the core; assert input → output |
| Constructor takes five collaborator services | Pass the values those services would have fetched |

## 9. Checklist

**Domain layer**

- [ ] No effect types, repos, clients, or loggers-with-I/O in domain function signatures
- [ ] No hidden reads of time, randomness, env, or IDs
- [ ] Decisions returned as data (values, events, commands), not performed
- [ ] Illegal states unrepresentable in domain types
- [ ] Effect ordering preserved (no charging before reservation)

**Service layer**

- [ ] Follows fetch → pure decide → dumb dispatch
- [ ] Depends only on interfaces in the environment, not concrete clients
- [ ] Business rules are delegated to the domain, not inlined here
- [ ] Effect branches only match the pure choice and perform it — no threshold, status check, or "should we call?" in the branch
- [ ] No I/O in the middle of a decision; data fetched up front or requested via command
- [ ] A growing layer cake is split into mini-workflows, each one sandwich

**Adapters / edge**

- [ ] Third-party SDKs wrapped in narrow, domain-shaped interfaces
- [ ] Concrete infrastructure appears only in live layers and startup wiring

**Tests**

- [ ] Functional-core unit tests have no mocks
- [ ] Imperative-shell tests mock external dependencies only, through a contract, and use the real database
- [ ] Domain tests have no effects
- [ ] Service tests use in-memory fakes and a test clock/random, asserting on state
- [ ] No call-order or call-count assertions unless the call itself is the requirement
- [ ] Adapters have integration tests against real or recorded dependencies
- [ ] Fakes and live adapters share a contract test suite
- [ ] One smoke test builds the layer graph and runs one request end to end
