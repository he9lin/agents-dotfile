# Language Mapping — TypeScript · Elixir · Rust · F#

The principles are language-agnostic; the mechanics and the **enforcement strength** are not. Match your ambition to what the language can prove.

## Enforcement Spectrum

| | Sum type (OR) | Product type (AND) | Exhaustive match | Illegal states |
|---|---|---|---|---|
| **F#** | discriminated union | record | `match` — compiler warning | compile-time; closest 1:1 to the FP original |
| **Rust** | `enum` | `struct` | `match` — compiler error | compile-time; ownership shapes operators |
| **TypeScript** | discriminated union | `type`/`interface` | `switch` + `never` check | compile-time *if* you add the `never` trick |
| **Elixir** | tagged tuple / struct + `@type` union | struct | `case` / function clauses — runtime | typespecs + crash-fast; weakest statically |

**Consequence:** in Elixir, lean harder on declarative models, interpreters, and pipelines (which need no static types) and validate in constructors. In F#/Rust/TS, push constraints into the type system.

---

## TypeScript

```ts
// Sum type — discriminated union
type Shape =
  | { kind: "circle"; r: number }
  | { kind: "rect"; w: number; h: number };

// Product type
type Promotion = {
  readonly id: PromotionId;
  readonly conditions: Conditions;
  readonly discount: Discount;
};

// Exhaustive interpreter — the never check is your compiler guard
function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.r ** 2;
    case "rect":   return s.w * s.h;
    default: {
      const impossible: never = s;
      throw new Error(`Unhandled: ${JSON.stringify(impossible)}`);
    }
  }
}

// Executable encoding — function values
type Predicate<T> = (value: T) => boolean;
const and = <T>(a: Predicate<T>, b: Predicate<T>): Predicate<T> =>
  (v) => a(v) && b(v);

// Declarative encoding — union + interpreter
type Filter = { kind: "and"; left: Filter; right: Filter } | { kind: "always" };
```

- **Illegal states:** branded types (`number & { __brand: "Cents" }`), `NonEmpty<T> = [T, ...T[]]`, discriminated unions, `never` exhaustiveness. Parse with a schema (e.g. Zod) into precise types at the boundary — *parse, don't validate*.
- **Operators:** named functions (TS has no operator overloading) or methods.
- **Caveats:** structural typing erodes nominal intent — brand types. No built-in pattern matching; use `switch`. Recursive models need explicit types.

---

## Elixir

```elixir
# Sum type — tagged tuples, or structs with a :type tag + @type union
@type shape :: {:circle, number()} | {:rect, number(), number()}

def area({:circle, r}), do: :math.pi() * r * r
def area({:rect, w, h}), do: w * h
def area(other), do: raise ArgumentError, "unknown shape: #{inspect(other)}"  # fail fast

# Product type — struct with enforced keys
defmodule Promotion do
  @enforce_keys [:id, :conditions, :discount]
  defstruct [:id, :conditions, :discount]
  @type t :: %__MODULE__{id: PromotionId.t(), conditions: Conditions.t(), discount: Discount.t()}
end

# Declarative model + interpreter (multi-clause = exhaustive-by-hand)
defmodule Filter do
  def matches(:always, _email), do: true
  def matches({:and, l, r}, email), do: matches(l, email) and matches(r, email)
  def matches({:subject_contains, phrase}, email), do: String.contains?(email.subject, phrase)
end
```

- **Illegal states:** `@enforce_keys`, struct typespecs, validate in constructors, pattern-match and raise on anything unexpected ("let it crash"). Dialyzer catches some but not all — the type layer is advisory.
- **Executable encoding is the language default:** a module with functions, or a `behaviour` + callbacks.
- **Operators:** no overloading — use named functions (`and_then/2`, `or_else/2`) and the pipe `|>` for composition.
- **Caveat:** because tags are conventions, keep the tag vocabulary small and centralized, and make interpreters total by raising on unknown tags rather than silently returning a default.

---

## Rust

```rust
// Sum type — enum (variants may carry data)
enum Shape {
    Circle { r: f64 },
    Rect { w: f64, h: f64 },
}

// Product type
struct Promotion {
    id: PromotionId,
    conditions: Conditions,
    discount: Discount,
}

// Exhaustive interpreter — compiler enforces every arm
fn area(shape: &Shape) -> f64 {
    match shape {
        Shape::Circle { r } => std::f64::consts::PI * r * r,
        Shape::Rect { w, h } => w * h,
    }
}

// Recursive declarative models need indirection
enum Filter {
    Always,
    And(Box<Filter>, Box<Filter>),
    SubjectContains(String),
}
```

- **Illegal states:** enums model alternatives, newtypes model domain primitives, typestate encodes lifecycle in the type. `Option`/`Result` instead of null/exceptions.
- **Operators:** implement `Add`, `BitAnd`, `BitOr`, `Mul` for the domain type, or provide methods; `Iterator` provides a large combinator vocabulary.
- **Caveats:** ownership and borrowing change operator signatures — decide whether operators **consume** (`self`), **borrow** (`&self`), or **clone**. Recursive AST nodes need `Box`/`Rc`. Prefer `&` for combinators that shouldn't consume.

---

## F#

```fsharp
// Sum type — discriminated union
type Shape =
    | Circle of r: float
    | Rect of w: float * h: float

// Product type — record
type Promotion = {
    Id: PromotionId
    Conditions: Conditions
    Discount: Discount
}

// Exhaustive interpreter — compiler warns on missing cases
let area shape =
    match shape with
    | Circle r -> System.Math.PI * r * r
    | Rect (w, h) -> w * h

// Single-case DU = zero-cost domain wrapper
type PromotionId = PromotionId of string
type CheckNumber = CheckNumber of int
type CardNumber = CardNumber of string
type PaymentAmount = PaymentAmount of decimal

type CardType = Visa | Mastercard
type CreditCardInfo = { CardType: CardType; CardNumber: CardNumber }

// OR whose cases carry data — not an enum plus optional fields
type PaymentMethod =
    | Cash
    | Check of CheckNumber
    | Card of CreditCardInfo
```

- **Illegal states:** DUs, single-case unions for wrappers, and **units of measure** (`[<Measure>] type usd`) — a distinctive strength for money, time, and quantities.
- **Operators:** define custom operators (`+`, `|>`, active patterns) freely; computation expressions model effects.
- **Caveats:** the closest 1:1 mapping to the Scala/FP original. Use `match` with no wildcard so adding a case produces a compiler warning; use `failwith` for genuinely impossible branches.

---

## Cross-Language Quick Map

| Concept | TypeScript | Elixir | Rust | F# |
|---|---|---|---|---|
| Sum type | discriminated union | tagged tuple / struct + `@type` | `enum` | discriminated union |
| Product type | `type` / `interface` | struct | `struct` | record |
| Exhaustive check | `switch` + `never` | `case` (runtime) | `match` | `match` |
| Wrapper type | branded type | struct / `@enforce_keys` | newtype | single-case DU / units |
| Executable encoding | function value / interface | module / `behaviour` | trait / closure | interface / function |
| Declarative encoding | union + interpreter | tuple struct + interpreter | `enum` + `match` | DU + `match` |
| Error as data | `Result<T, E>` union | `{:ok, v}` / `{:error, e}` | `Result<T, E>` | `Result<Ok, Err>` |
| Compose | `|>`-less, named/method | `\|>` pipes | method chaining | `\|>` pipes |

---

## Effect systems

Layering for ZIO, Effect-TS, and Elixir is in `functional-core.md`, not in the ADT tables above. The domain stays a plain function. The service sequences `ZIO` / `Effect` / a context function and names dependencies as interfaces. The adapter is the live `ZLayer`, Effect `Layer`, or config-selected impl.

| Ring | ZIO | Effect-TS | Elixir |
|---|---|---|---|
| Domain | plain function, `Either` | plain function | module with no `Repo` |
| Service | traits in `R` | `Context.Tag` | `@behaviour` |
| Adapter | `ZLayer` + `provide` | `Layer` | `Repo`, HTTP client, config |
