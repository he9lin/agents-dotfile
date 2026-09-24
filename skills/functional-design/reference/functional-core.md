# Guideline: Functional Core, Imperative Shell, and Mock-Minimal Testing

Applies to Elixir and TypeScript/Effect code. Follow these rules when designing modules and writing tests.

**Scope.** This guideline has two parts with different rules:

- **Core design and unit tests** (sections 1–4, and the "core" rows in section 5): how to structure business logic so it is pure, and how to unit test it. Unit tests target the core and use **no mocks**.
- **Full-flow / integration tests** (section 5, "shell" rows): tests that exercise the outermost layer end to end. Here, mocking external boundaries is **expected and allowed**, including `expect`-style call assertions.

The no-mocks rule applies to unit tests of the core, not to full-flow tests.

## 1. Core principle

Separate **deciding** from **doing**.

- The **core** decides: pure functions that take data and return data. No I/O, no DB, no HTTP, no clock, no randomness, no process messaging, no logging.
- The **shell** does: fetches inputs, calls the core, performs the effects the core asked for, persists results.

Push side effects as far out to the edges as possible. The shell should be thin and boring; the core should hold all business logic.

## 2. Pass values, not services

Core functions receive **states and results**, never collaborators that can perform effects.

```elixir
# BAD: core receives a service it must call
def process(order_id, repo, gateway), do: ...

# GOOD: core receives data the shell already fetched
def reserve(order, inventory_state), do: ...
```

If a function needs to "call something" to make a decision, that is a signal to split it: the shell performs the call, then passes the result into the next pure step.

## 3. When effects and decisions interleave

Do NOT solve interleaving by passing all effect results in up front if that changes ordering semantics (e.g. charging a card before inventory is reserved). Use one of these instead:

**A. Split into pure steps**, with the shell performing effects between them:

```elixir
with {:ok, inv, order} <- Order.Core.reserve(order, inventory),   # pure
     {:ok, charge}     <- gateway().charge(order.total, order.card), # effect
     {:ok, order}      <- Order.Core.finalize(order, charge) do    # pure
  ...
end
```

**B. Return commands (preferred for multi-effect flows).** The core returns a description of effects as data; the shell interprets them.

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

Commands make "which effects happen, in what order" pure and testable.

In Effect-TS, keep decision logic in plain functions returning data; use `Effect` only in the shell, and model external systems as `Context.Tag` services provided via `Layer`.

## 4. Boundaries

- Every external system (payment, SMS, email, third-party APIs, LLM calls) sits behind an **explicit contract**: an Elixir `@behaviour` or an Effect service interface.
- Select the implementation via config (Elixir) or `Layer` (Effect). Never hardcode an external client inside core code.
- Your own database is NOT an external boundary for testing purposes (see below).

## 5. Testing strategy

| Layer | Test type | Doubles allowed |
|---|---|---|
| Core (pure) | Unit tests: input → output assertions | None. Construct data directly. |
| Core returning commands | Unit tests asserting on emitted commands | None. |
| Shell / wiring | Integration tests through the public entry point | Only at external boundaries |
| Database | Real Postgres (Ecto SQL Sandbox / test DB) | Do not mock the repo |
| External HTTP services | Mox against the behaviour, Bypass for HTTP, or a test `Layer` | Yes, at this boundary only |

### 5a. Unit tests (core)

- Put the bulk of test coverage, including all edge cases and error branches, in core unit tests.
- No mocks, stubs, or `expect`-style call assertions. Construct input data, call the function, assert on the output.
- If a unit test seems to need a mock, the code under test is not pure yet. Refactor it (section 3) instead of adding a mock.

### 5b. Full-flow tests (outermost layer)

- Test the whole flow through its public entry point (context function, controller, job, Effect program).
- Use the real database. Mock only external systems, through their explicit contract (Mox behaviour, Bypass, or a test `Layer`).
- `expect`-style assertions on external boundaries **are allowed here**, and are often the right tool: "a charge request was sent with 100", "a confirmation SMS was sent to this number", "no charge was made when stock ran out".
- Keep these tests few: happy path plus one test per distinct failure-handling path (e.g. compensation/rollback after a failed charge).

```elixir
# Full-flow test: expect-style mocks at the external boundary are fine
test "successful order charges the card and sends confirmation" do
  order = insert(:order, total: 100)          # real DB
  insert(:inventory, items: order.items)

  expect(PaymentGatewayMock, :charge, fn 100, _card -> {:ok, %{id: "ch_1"}} end)
  expect(NotifierMock, :send_confirmation, fn _email -> :ok end)

  assert {:ok, %{status: :paid}} = Orders.process(order.id)
  assert Repo.get!(Order, order.id).status == :paid
end
```

### 5c. Rules for both

- Mocks are **nouns, not verbs**: every mock implements an explicit contract. Never create ad-hoc doubles with no behaviour/interface behind them.
- Never mock internal modules, structs, pure functions, or your own database.
- Beyond external-boundary expectations, assert on outcomes (returned values, persisted state, emitted commands), not on internal call sequences.

## 6. Anti-patterns to avoid

- A **unit test** that is mostly `expect(x).to receive(...)` lines: the design is wrong, not the test. Refactor toward a pure core. (In full-flow tests, expectations on external boundaries are fine; expectations on internal collaborators are not.)
- Constructors or functions taking five collaborator services.
- Core modules calling `Repo`, `Logger`, `DateTime.utc_now/0`, HTTP clients, or `Effect` services directly. Pass time and IDs in as arguments.
- Mocking the database to test business logic.
- Changing effect ordering to make code "look pure" (see section 3).

## 7. Checklist before finishing a change

- [ ] Is new business logic in pure functions with no effects?
- [ ] Do core functions take values/states rather than services?
- [ ] Are external systems behind an explicit behaviour/service?
- [ ] Are core unit tests free of mocks?
- [ ] Is effect ordering preserved (e.g. no charging before reservation)?
- [ ] Do full-flow tests use the real DB and mock only external boundaries (with `expect` where the call is the behaviour)?
- [ ] Are full-flow tests limited to wiring and failure-handling paths?
