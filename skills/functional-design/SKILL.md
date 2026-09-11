---
name: functional-design
description: Use when planning a new feature, project, subsystem, or internal DSL; when modeling a business domain with types; or when reviewing code for domain-modeling quality and functional-design conformance (ADTs, composability, orthogonality, interpreters). Trigger symptoms include primitive obsession, a class/service doing too many jobs, runtime checks for states types could prevent, operations returning void/Unit/nil, and logic that must run, be explained, serialized, or tested in multiple ways. Covers TypeScript, Elixir, Rust, and F#.
---

# Functional Design

## Overview

Model a domain as **immutable data** plus a **small set of primitives** that build and combine it. Every functional domain has three parts:

| Part | Role | Lives as |
|---|---|---|
| **Models** | immutable data describing solutions | sum + product types |
| **Constructors** | build solutions to simple problems | module / factory / companion functions |
| **Operators** | transform & combine solutions | functions on the model type |

A small, composable set of primitives can describe *all* solutions in the domain. Treat the domain as an internal DSL.

Your global rules ("make illegal states unrepresentable", ADT modeling, translate at boundaries) are the **constitution**; this skill is the **playbook** that operationalizes them.

## When to Use

- Planning a new feature, project, subsystem, or DSL
- Modeling a business domain in types
- Reviewing code for domain-modeling quality
- **Symptoms:** raw primitives where a domain type belongs; one class/service doing six jobs; a runtime `throw` for a state types could forbid; operators returning `void`/`Unit`/`nil`; the same logic needing to run, be explained, serialized, or tested in more than one way

**When NOT to use:** thin CRUD pass-throughs, hot-loop numerics, one-off glue. Least power cuts both ways — don't build a DSL for a problem solved once.

## Choose the Encoding

Decide this **before** writing any behavior.

| | Executable | Declarative |
|---|---|---|
| Model is | function/interface that executes | pure data (ADT) |
| New constructors/operators | open | fixed |
| New ways to execute | fixed | open |
| Introspectable | no | yes |
| Pick when | operations must stay open | you need run / explain / serialize / test |

Default to **declarative** (data + interpreters). Go executable only when openness of operations outweighs introspectability. Tagless-final = executable with polymorphic solutions.

## Planning Mode

Complete every step; each has a required output. Do not approve a plan without them.

1. **Name the domain** and the problems it solves.
2. **Sketch the model** — sum types for alternatives, product types for composites; no raw primitives for domain concepts.
3. **Choose the encoding** (table above) and state why.
4. **List primitives** — constructors + operators. Every operator takes the domain type in and returns the domain type out. Tag each as primitive or derived; demote anything expressible in terms of others.
5. **Test the primitives** — composable, expressive, orthogonal (no overlaps) → minimal.
6. **Plan interpreters** — each execution concern (`run`, `describe`, `validate`, `preview`, `toJson`) as its own total function over the model.
7. **Constrain with types** — encode which operations are legal, at the strongest level the language allows.
8. **Put effects at the boundary** — translate into the effect domain (`ZIO` / `IO` / `Promise`) last, at the edge.

## Review Mode

Scan for every named violation. Report each with its name, severity, and fix.

| Violation | Symptom | Fix |
|---|---|---|
| Primitive obsession | raw `string`/`number` for a concept | wrap in a domain type |
| Open inheritance taxonomy | class hierarchy with "don't extend both" rules | closed ADT |
| Void operator | returns `void`/`Unit`/`nil` | return a model value |
| God service | one class does six jobs | model + interpreters |
| Runtime check types could own | `throw` on a forbidden state | type-level constraint |
| Opaque AST node | function embedded in a data model | keep models pure data |
| Overlapping primitives | two primitives do the same job | keep one, derive the other |
| Effect in domain logic | I/O inside the model | move to interpreter / boundary |
| Non-exhaustive interpreter | wildcard default hides cases | total match, no catch-all |
| DSL for a one-shot problem | elaborate DSL used once | plain code (least power) |

## Common Mistakes

- Jumping to services/classes before modeling the data
- Leaving the encoding choice implicit
- Adding convenience functions as new primitives instead of deriving them
- Validating with `if`/`throw` what a type could forbid
- Executing inside the model instead of writing an interpreter

## Reference

- `reference/patterns.md` — the nine patterns with code templates and rationale
- `reference/language-mapping.md` — TypeScript / Elixir / Rust / F# mappings and enforcement strengths
