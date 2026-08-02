# Engineering Standards

Treat every change as production work. Prefer the smallest coherent change that
fully improves behavior, correctness, maintainability, or test quality. Preserve
unrelated work.

These standards are language- and framework-neutral. Use the idioms and tools of
the current project to fulfill their intent.

## Default Working Method

1. Inspect existing architecture, public APIs, tests, and conventions before adding code.
2. Reuse an existing owner when its semantics match; do not create duplicates.
3. Place code in the narrowest owner of the concept.
4. Add or improve tests for observable behavior and important failure paths.
5. Run relevant formatting, static analysis, type or contract validation, tests,
   and build commands.
6. Review the complete diff before finishing.

Do not make superficial cleanup-only churn. Prefer meaningful refactors that
reduce duplication, branching complexity, invalid states, or cognitive load.

## Readability And Control Flow

Optimize for code that is easy to understand on first read.

- Use named intermediate values for meaningful decisions.
- Prefer early returns and sequential guard clauses.
- Do not combine several unrelated Boolean checks into one long expression.
- Write runtime validation and type checks as explicit checks with early returns.
- Resolve asynchronous work into a named result before using it in control flow.
- Do not hide asynchronous decisions inside conditions or conditional expressions.
- Use a conditional expression only for a very small, local scalar choice. Do not
  use one for policy, structured data construction, multiple branches, nested
  logic, or returned domain decisions.
- Break complex collection pipelines into named stages when they include
  business logic, grouping, branching, or multiple transformations.
- Extract a function only when its name explains a real domain decision.

Do not create vague `helpers`, `common`, `misc`, or catch-all `utils` modules.
A utility's name and location must explain the behavior it owns.

## Data Models And Contracts

- Do not use coercion, casting, unchecked conversion, or suppression to make
  incomplete data appear to satisfy a domain model or contract.
- Prefer a real valid value, a valid builder, a narrower input contract, or
  explicit validation at the boundary.
- Keep domain models valid by construction.
- Deliberately invalid API or validation-test input must remain raw input and go
  through the real validation boundary. Do not disguise it as a valid entity.
- Avoid escape hatches that disable the language's safety mechanisms unless they
  are narrowly justified, documented, and tested.

## Test Fixtures And Builders

Use builders for recurring valid domain data. Follow a `buildX(overrides)`
convention where it fits the language and test framework.

Builder requirements:

- Defaults are complete, valid, deterministic, representative, and fresh.
- Mutable values must not be shared between builder calls or tests.
- Builders accept focused overrides for fields relevant to the test.
- Preserve cross-field and parent/child invariants.
- Name plain-data builders, executable mocks, stateful scenarios, and UI render
  harnesses differently so their purpose is obvious.

Fixture ownership:

- Cross-domain fixtures belong in a shared testing module.
- Backend request, response, middleware, or service harnesses belong in backend
  testing infrastructure.
- UI, browser, or rendering harnesses belong in frontend testing infrastructure.
- Domain-specific fixtures belong in that domain's testing module.
- One-suite-only setup may remain local with a behavior-specific name.

Organize reusable fixtures by entity or concept rather than collecting all test
data in one large file. Do not duplicate ad hoc entity objects throughout tests.

## Modules, Public APIs, And Ownership

- Expose APIs directly from the conceptual owner's public module.
- Do not add proxy modules that only re-export another local module.
- Do not create compatibility re-export shims between packages or modules.
- Keep production code and test infrastructure separate.
- Avoid circular dependencies and imports into another module's private internals.

## Comments

Comments explain why: constraints, surprising business rules, external behavior,
or non-obvious tradeoffs.

Do not narrate code that should instead have a better name, smaller function,
or clearer control flow.

## Tests

Tests must prove behavior, not implementation details or mock configuration.

Cover relevant happy paths, boundaries, invalid input, authorization, data
isolation, failure handling, and concurrency or ordering risks.

Prefer realistic builders and focused fakes over broad permissive mocks.
Unexpected calls in shared fakes should fail clearly.

## Enforce Objective Rules

When a quality concern is objectively detectable and recurring, enforce it with
automation and tests.

At minimum, configure equivalent enforcement for:

- asynchronous work hidden in control-flow conditions;
- nested or redundant conditional expressions;
- incomplete test data disguised as valid domain data;
- shared mutable fixture defaults;
- dependency and module-boundary rules;
- public API and import/export architecture rules.

For legacy code, prefer a changed-line ratchet: new violations fail continuous
integration while existing debt is fixed when touched.

Do not add noisy automated rules for judgment calls that require context;
document those decisions and enforce them in review.

Every custom static-analysis rule or quality gate needs positive and negative
tests.

## Completion Checklist

Before declaring work complete:

- Review the full diff for correctness, duplication, ownership, readability,
  fixture reuse, and unintended scope.
- Run applicable formatting, static analysis, contract validation, tests, and
  build commands.
- Report exact commands run and any warnings or omissions.
- Do not commit, push, open a pull request, merge, delete branches, or change
  external systems unless explicitly requested.
