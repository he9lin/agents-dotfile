---
name: functional-design
description: Hunt for places to apply functional design while planning or reviewing a feature, project, or codebase. Use when planning a subsystem or internal DSL; modeling a domain with types; or reviewing for ADTs, combinators, composability, orthogonality, and interpreters. Trigger on retry/schedules, parsers, validators/filters/rules, streams/ETL, polling/workers, state machines, workflows, or symptoms like primitive obsession, god services, void operators, DateTime.Now in domain logic, duplicated run-vs-explain logic. Covers TypeScript, Elixir, Rust, and F#.
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
| **Models** | immutable data describing solutions | sum + product types |
| **Constructors** | build solutions to simple problems | module / factory / companion functions |
| **Operators / combinators** | transform & combine solutions | functions on the model type |

Your global rules ("make illegal states unrepresentable", ADT modeling, translate at boundaries) are the **constitution**; this skill is the **playbook**.

## Hunt first (required in both modes)

Before writing a plan or a review comment, **scan the feature, spec, or codebase for candidate domains**. A candidate is a place with **many solutions you want to combine** — policies, grammars, pipelines, rules, schedules, queries, workflows — not a procedure you will write once.

Do not skip this scan. Do not assume the whole app is one domain. Do not force a DSL onto thin CRUD, hot-loop numerics, or one-off glue.

For every candidate (and every skip), produce the fields in [Output](#output). Use the catalog in `reference/spotting.md` as the hunt list. Typical hits: **scheduler**, **parser**, **validator/filter/rules**, **stream/pipeline**, **polling/worker with time**, **lifecycle ADT**, **optics**, **formula**, **workflow**.

**Look-for (code and specs):** `retry`, backoff, cron, `setTimeout` chains; regex / `split` / hand-rolled grammars; `if` trees for "match this AND that"; `InputStream` / file concat / ETL steps; `DateTime.Now` / `new Date()` inside business logic; stringly status flags (`"ready"|"received"|...` as `string` or booleans that can contradict); methods that return `void` and mutate; the same rule implemented once to run and again to explain or serialize.

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

Complete every step. Do not approve a plan without the hunt output and, for each candidate you keep, the eight design outputs.

0. **Hunt** — scan spec + existing code with `reference/spotting.md`. List candidates and skips.
1. **Name the domain** and the problems it solves.
2. **Sketch the model** — sum types for alternatives, product types for composites; no raw primitives for domain concepts. Encapsulate behavior in the type when the "thing" is a policy, grammar, pipeline, or program — not only when it is a noun.
3. **Choose the encodings** (tables above) and state why.
4. **List primitives** — constructors + operators (combinators). Every operator takes the domain type in and returns the domain type out. Tag primitive vs derived; demote anything expressible in terms of others.
5. **Test the primitives** — composable, expressive, orthogonal (no overlaps) → minimal. Check that real business sentences become composition (`primary.orElse(fragments).buffered`, `exponential.andThen(fixed)`, `username + char('@') + server`).
6. **Plan interpreters** — each execution concern (`run`, `describe`, `validate`, `preview`, `toJson`) as its own total function over the model. Effects (`DateTime.Now`, I/O) live only here.
7. **Constrain with types** — encode which operations are legal, at the strongest level the language allows.
8. **Put effects at the boundary** — translate into the effect domain (`ZIO` / `IO` / `Promise`) last, at the edge.

## Review Mode

Scan in two passes. Report every finding with **name, severity, location, and fix**.

**Pass A — missed domains.** Walk `reference/spotting.md`. For each hit, if the code is a class/service/loop instead of model + constructors + combinators + interpreter, report **Missed domain** (not a style nit). Propose the type, constructors, combinators, and interpreters.

**Pass B — malformed domains.** If a functional domain already exists (or should), scan for named violations:

| Violation | Symptom | Fix |
|---|---|---|
| Primitive obsession | raw `string`/`number` for a concept | wrap in a domain type |
| Open inheritance taxonomy | class hierarchy with "don't extend both" rules | closed ADT |
| Void operator | returns `void`/`Unit`/`nil` | return a model value |
| God service | one class does six jobs | model + interpreters |
| Runtime check types could own | `throw` on a forbidden state | type-level constraint |
| Opaque AST node | function embedded in a data model | keep models pure data |
| Overlapping primitives | two primitives do the same job | keep one, derive the other |
| Effect in domain logic | I/O or clock inside the model | move to interpreter / boundary |
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
- Interpreters (`run`, `describe`, …)
- Severity if review: missed vs malformed

## Skip
Places that are CRUD, glue, or one-shot — one line each, why least power applies.

## Plan or fixes
Only for candidates you keep. Planning: the eight design outputs. Review: violation name, location, fix.
```

## Common Mistakes

- Jumping to services/classes before hunting for a domain
- Treating the whole application as one DSL
- Modeling nouns (User, Order) and skipping behavior-as-values (retry policy, filter, parser, pipeline)
- Leaving either encoding choice implicit
- Adding convenience functions as new primitives instead of deriving them
- Validating with `if`/`throw` what a type could forbid
- Executing inside the model instead of writing an interpreter
- Exposing a mutable/loop implementation as the combinator's public contract

## Reference

- `reference/spotting.md` — where to look (scheduler, parser, validator, stream, …)
- `reference/patterns.md` — patterns with code templates
- `reference/language-mapping.md` — TypeScript / Elixir / Rust / F# mappings
