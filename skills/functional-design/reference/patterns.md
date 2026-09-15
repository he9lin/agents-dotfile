# Functional Design Patterns

Nine patterns. Examples are TypeScript; see `language-mapping.md` for Elixir, Rust, and F#.

The running example is an e-commerce **promotion engine** (discounts applied to a cart).

---

## 1. Models + Constructors + Operators

A functional domain is **models** (immutable data), **constructors** (build simple solutions), and **operators** (combine solutions into larger ones). Done well, a small set of primitives describes every solution in the domain.

```ts
// MODELS — immutable data describing solutions
type Discount =
  | { kind: "percent"; percent: number }
  | { kind: "fixed"; cents: number }
  | { kind: "freeShipping" };

type Promotion = {
  readonly id: PromotionId;
  readonly conditions: Conditions;
  readonly discount: Discount;
};

// CONSTRUCTORS — build simple solutions (name them as verbs)
const percentOff = (id: PromotionId, percent: number): Promotion => ...
const freeShipping = (id: PromotionId): Promotion => ...

// OPERATORS — take the domain type in, return the domain type out
const stack = (a: Promotion, b: Promotion): Promotion => ...
```

Every domain concept that could be a raw primitive gets a **wrapper type** (`PromotionId`, not `string`; `Cents`, not `number`).

---

## 2. Choose the Encoding

Two ways to represent a model. Choose deliberately; the trade-off never disappears.

**Executable** — a function or interface that *executes* the solution. Open to new operations; opaque to introspection.

```ts
type Predicate<T> = (value: T) => boolean;

const subjectContains = (phrase: string): Predicate<Email> =>
  (email) => email.subject.includes(phrase);

const and = <T>(a: Predicate<T>, b: Predicate<T>): Predicate<T> =>
  (value) => a(value) && b(value);
```

**Declarative** — pure data that *describes* the solution; an interpreter executes it. Closed to new operations; open to new ways to execute.

```ts
type Filter =
  | { kind: "always" }
  | { kind: "and"; left: Filter; right: Filter }
  | { kind: "not"; filter: Filter }
  | { kind: "subjectContains"; phrase: string };

const and = (left: Filter, right: Filter): Filter => ({ kind: "and", left, right });
```

Summary: **executable = unbounded constructors/operators, fixed ways to execute. Declarative = fixed constructors/operators, unbounded ways to execute.**

Never embed a function inside a declarative model — that node becomes opaque and can no longer be serialized, optimized, or described.

This choice is independent of **how a combinator is implemented**. A combinator can often be implemented with different encodings depending on performance or language constraints:

1. **The Declarative/Recursive Way:** Defining combinators purely by composing other higher-order functions or using recursion (e.g., defining `filter` using `reduce`).
2. **The Imperative/Loop Way:** Writing a combinator using internal mutable loops for maximum execution speed while keeping the external API clean and declarative.

```ts
const filter = <A>(pred: (a: A) => boolean, xs: readonly A[]): A[] =>
  xs.reduce((acc, x) => (pred(x) ? [...acc, x] : acc), [] as A[]);

const filterFast = <A>(pred: (a: A) => boolean, xs: readonly A[]): A[] => {
  const out: A[] = [];
  for (const x of xs) if (pred(x)) out.push(x);
  return out;
};
```

Same type, same callers. Default to composition/recursion; use an internal loop when recursion hurts. Never leak mutation.

---

## 3. Operators Close Over the Type

An operator accepts and returns the *same* domain type, which is what allows repeated composition (`a + b + c`). If it returns `void` / `Unit` / `nil`, nothing can be built from it.

```ts
const and   = (a: Filter, b: Filter): Filter => ...   // ✓ composable
const merge = (a: Schedule, b: Schedule): Schedule => ... // ✓ composable
const log   = (f: Filter): void => ...                // ✗ dead end
```

Reuse a standard vocabulary so DSLs feel familiar:

| Operator | Meaning |
|---|---|
| `++` / `then` | sequential composition |
| `&&` / `and` | parallel/and — both must hold |
| `\|\|` / `orElse` | fallback — try left, then right |
| `zip` / `both` | combine results into a tuple |
| `either` | whichever succeeded |
| `map` | transform the output of a solution |
| `flatMap` | next step depends on the previous output |

---

## 4. Primitive vs. Derived — Orthogonality → Minimalism

Operators and constructors are **primitive** (not expressible in terms of others) or **derived** (defined using primitives). The best primitive set is **composable**, **expressive**, and **orthogonal** — no primitive does another's job. Orthogonality implies **minimalism**: the smallest orthogonal set that exists.

```ts
// BEFORE — overlapping primitives: both directions are new cases
type Filter =
  | { kind: "senderIs"; address: Address }
  | { kind: "senderIsNot"; address: Address }      // redundant
  | { kind: "bodyContains"; phrase: string }
  | { kind: "bodyNotContains"; phrase: string };   // redundant

// AFTER — minimal primitives, plus derived helpers
type Filter =
  | { kind: "always" }
  | { kind: "not"; filter: Filter }
  | { kind: "and"; left: Filter; right: Filter }
  | { kind: "senderIs"; address: Address }
  | { kind: "bodyContains"; phrase: string };

const senderIsNot    = (a: Address): Filter => not(senderIs(a));     // derived
const bodyNotContains = (p: string): Filter => not(bodyContains(p)); // derived
```

Rule: **if B can be written in terms of A, B is not a primitive.** Demote it to a derived helper in the module/companion object. This is the single-responsibility principle expressed as orthogonality.

---

## 5. One Model, Many Interpreters

A declarative model is executed by an **interpreter**: a total function that pattern-matches every case. The same model yields many interpreters — that is the whole payoff of declarative encoding.

```ts
// Interpreter 1: execute against data
const matches = (filter: Filter, email: Email): boolean => {
  switch (filter.kind) {
    case "always":          return true;
    case "and":             return matches(filter.left, email) && matches(filter.right, email);
    case "not":             return !matches(filter.filter, email);
    case "senderIs":        return email.sender === filter.address;
    case "bodyContains":    return email.body.includes(filter.phrase);
  }
};

// Interpreter 2: human-readable description
const describe = (filter: Filter): string => { /* ... */ };

// Interpreter 3: serialize / dry-run / test double
```

Interpreters must be **total** (no wildcard `default:` that swallows new cases). For stateful recursion, thread an accumulator through an inner loop function.

---

## 6. Make Illegal States Unrepresentable

Start untyped; add type precision when you catch yourself writing a runtime check or a cast.

```ts
// A non-empty list cannot be empty — enforced by the type
type NonEmpty<T> = readonly [T, ...T[]];

// Money and ids are branded, not raw
type Cents = number & { readonly __brand: "Cents" };
type PromotionId = string & { readonly __brand: "PromotionId" };

// Parse at the boundary; the core only ever sees valid data
const parsePromotion = (raw: unknown): Result<Promotion, ValidationError[]> => ...
```

Exhaustiveness is compile-time enforcement of the closed ADT:

```ts
switch (discount.kind) {
  case "percent":      return total - Math.round(total * discount.percent / 100);
  case "fixed":        return total - discount.cents;
  case "freeShipping": return total;
  default: {
    const impossible: never = discount; // compile error when a case is added
    throw new Error(`Unhandled: ${JSON.stringify(impossible)}`);
  }
}
```

Prefer **parse, don't validate**: convert untrusted input into the precise type once, at the boundary, then trust it.

---

## 7. Structural Idioms

- **`readonly` fields** and immutable updates; never mutate inputs.
- **Pure data models.** No I/O, clocks, or randomness inside a model.
- **Lazy fields for recursion** so recursive schemas don't blow the stack: `{ element: () => Schema }`, with a by-name/thunk constructor.
- **Constructors in the module/companion**, named as verbs (`senderIs`, `column`, `range`).
- **Smart constructors return primitives** so callers build from the smallest pieces.
- **Errors as data**, not exceptions: `Result<T, E>` / `Either<E, A>`; accumulate warnings and errors together when validating.
- **Explicit results**, never in-place mutation of a shared object.
- **Optics/lenses** for deep updates instead of nested copy chains.

---

## 8. Integrate Domains by Translation

When two domains must combine, interpret each into a **common, more powerful domain** — in practice an effect domain (`ZIO` / `IO` / `Promise`). Do it **at the boundary**, last.

In the larger domain, solutions are less constrained: fewer guarantees, fewer reasoning and testing benefits. That cost is the reason to push translation as far out to the edges as possible.

```
domain model ──interpreter──► effect domain ──► the world
   (pure)                       (ZIO/IO)          (I/O)
```

This is the FP counterpart of the DDD boundary rule: never cross contexts directly; convert types at the edge.

---

## Checklist

- [ ] Every domain concept is an ADT or wrapper type — no raw primitives
- [ ] Candidate domains were hunted (scheduler, parser, filter, stream, worker, …) and skips named
- [ ] The encodings were chosen deliberately (model + combinator) and stated
- [ ] Operators close over the domain type (no void/Unit/nil returns)
- [ ] Primitives are minimal and orthogonal; the rest are derived
- [ ] Each execution concern is a separate interpreter
- [ ] Illegal states are prevented at the strongest level the language allows
- [ ] Effects live only at the boundary
