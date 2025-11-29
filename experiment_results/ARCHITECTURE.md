# PAT→PRISM Transformation System — Architecture Overview (English)

## System Overview

The conversion pipeline follows these stages:

1. Lexing (ANTLR-generated lexer)
2. Parsing (ANTLR-generated parser)
3. AST construction (visitor-based AST builder)
4. IR construction (process-centric intermediate representation)
5. PRISM rendering (Jinja2 templates)

Input: PAT specification (*.pat)
Output: PRISM model file (*.prism) — default semantics: MDP

## Core Components

- `src/pat2prism/pat_visitor.py` — AST visitor and IR builder
- `src/pat2prism/ir.py` — IR definitions (Spec, ProcessModule, Transition)
- `src/pat2prism/prism_generator_v2.py` — Template renderer that populates `prism_model.jinja2`
- `src/pat2prism/templates/prism_model.jinja2` — PRISM model template (defaults to `mdp` header)
- `webui/` — Flask-based interactive frontend
- `tools/` — Batch scripts for experiments and example conversions

## Data Model

IR captures:
- Processes as modules (states, transitions)
- Channels as global variables with integer-encoded messages
- Guards and updates as literal expressions to be refined manually when needed

## Design Rationale

- Separation of concerns enables auditable, testable transformation steps.
- Templates are parameterized to allow `mdp` vs `dtmc` output and to inject configurable attack/channel parameters.
- Manual refinement is preserved where domain knowledge is essential (crypto semantics, attack models).

## Testing Strategy

Unit tests for AST→IR and IR→template stages; integration tests validate that generated PRISM files contain expected module counts and labels.

## How to Extend

- Add new AST node handlers in `pat_visitor.py` and map them to IR constructs.
- Create or modify Jinja2 templates for alternative PRISM encodings (DTMC, CTMC, or POMDP).

## Reproducibility Notes

- The project includes sample PRISM models and property files in `paper/` and `experiment_results/` used to reproduce figures in the paper.
- Use the included plotting scripts to regenerate figures from either PRISM outputs or provided derived CSV arrays.

---

This document provides an English description of the architecture and is intended for reviewers and other developers.