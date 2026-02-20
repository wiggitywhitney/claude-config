# Testing Decision Guide

How to choose a testing strategy based on what you're building. This guide maps project types to concrete testing approaches — what to test, how to test it, and what pitfalls to avoid.

## How to Use This Guide

1. Identify your project type (or combination) from the table below
2. Read the detailed section for your type
3. Apply the recommended strategy, adapting coverage targets and tools to your stack
4. Use the cross-cutting concerns section for patterns that apply everywhere

---

## Quick Reference

| Project Type | Primary Strategy | Coverage Target | Key Challenge |
|---|---|---|---|
| [LLM-Calling Code](#llm-calling-code) | Unit tests for logic, contract tests for LLM boundaries, fixture-based regression | 80% business logic | Non-determinism in LLM responses |
| [Agent Frameworks](#agent-frameworks) | Workflow/state machine tests, node-level unit tests, end-to-end scenario tests | 80% state transitions | Complex state transitions, multi-step flows |
| [K8s/Infrastructure](#k8sinfrastructure-interaction) | Integration tests against real infrastructure, API contract tests | Integration coverage of critical paths | Heavy infrastructure setup, slow feedback loops |
| [Script-Orchestrated Tools](#script-orchestrated-tools) | Input/output tests, CLI argument validation, file operation verification | 80-90% line coverage | Deterministic behavior, filesystem side effects |
| [Pure Utilities](#pure-utilities) | Standard unit tests, property-based testing, high coverage | 90%+ line coverage | Straightforward — just do it |

---

## LLM-Calling Code

Code that sends prompts to LLMs and processes their responses. Examples: commit-story (narrative generation), AI-powered CLI tools, chatbot applications.

### What to Test

**Deterministic logic (unit tests):**
- Prompt construction and template rendering
- Response parsing and extraction (JSON parsing, regex matching, field mapping)
- Token counting and cost calculation
- Input validation and sanitization before sending to LLM
- Error handling for malformed responses, rate limits, timeouts

**LLM boundaries (contract tests):**
- Request format matches API schema (correct fields, types, required parameters)
- Response handling covers the full range of possible outputs (success, refusal, truncation, error)
- Retry logic behaves correctly for transient failures
- Model-specific behavior differences (if supporting multiple models)

**Regression (fixture-based):**
- Capture real LLM responses as fixtures; test that parsing logic handles them correctly
- When parsing breaks on a new response format, add the response as a fixture and fix

### What NOT to Test

- Whether the LLM produces "good" output — that's evaluation, not testing
- Exact LLM response content (non-deterministic by nature)
- Prompt quality (use evals for this, not unit tests)

### Key Patterns

**Separate deterministic from probabilistic.** Structure code so all deterministic logic (parsing, formatting, validation, scoring) is isolated from LLM calls. Test the deterministic parts exhaustively. For the LLM interaction layer, test the contract (correct request shape, correct response handling) not the content.

```text
# Good structure:
build_prompt(context) → prompt string        # Unit testable
call_llm(prompt) → raw response              # Contract testable (mock the API)
parse_response(raw) → structured data        # Unit testable
validate_output(data) → result               # Unit testable

# Bad structure:
generate_narrative(context) → final output   # Untestable monolith
```

**Helper factories for test data.** LLM responses are complex nested structures. Create factory functions that produce valid defaults with overridable fields.

```text
# Pattern: helper factory with sensible defaults
_make_response(content="default", finish_reason="stop", tokens=100)
_make_session(model="sonnet", input_tokens=5000, cost=0.05)
```

**Score range assertions over exact values.** When testing analytics or scoring derived from LLM interactions, assert relative ordering rather than exact numbers.

```text
# Good: relative assertion
assert good_result.score >= poor_result.score

# Bad: brittle exact assertion
assert result.score == 0.847
```

**Eval-driven development for LLM quality.** Use pass@k metrics (at least k successes in k attempts) to validate that LLM-dependent features are robust across multiple generations. This is a complement to testing, not a replacement. Source: Affaan Mustafa's eval harness approach.

### Recommended Tools

- **Test framework**: Vitest (TypeScript), pytest (Python)
- **Fixtures**: Captured real API responses stored as JSON files
- **Contract testing**: Mock the HTTP layer, not the LLM client library
- **Eval framework**: Custom eval harness or Braintrust for pass@k metrics

### Coverage Targets

| Category | Target |
|---|---|
| Prompt construction | 90% |
| Response parsing | 90% |
| Business logic / scoring | 80% |
| Error handling | 80% |
| LLM call layer | Contract coverage (not line coverage) |

---

## Agent Frameworks

Multi-step AI workflows with state management, tool use, and conditional branching. Examples: LangGraph pipelines, custom agent loops, multi-agent coordination systems.

### What to Test

**State machine correctness (workflow tests):**
- State transitions follow defined graph edges
- Each node produces the expected output state given an input state
- Conditional edges route to the correct next node
- Terminal states are reached correctly
- Cycles and loops terminate (if applicable)

**Node-level logic (unit tests):**
- Individual node functions produce correct output for given input
- Tool call formatting is correct
- State reduction/accumulation works as expected

**End-to-end scenarios (integration tests):**
- Full workflow execution from input to final output
- Error propagation through the graph
- Timeout handling for long-running nodes
- Tool integration with real (non-mocked) tools where feasible

**Failure modes:**
- What happens when a tool is unavailable or returns an error
- What happens when the LLM refuses a request mid-workflow
- What happens when state grows beyond expected bounds
- Stub detection: verify implementations are substantive, not placeholder responses

### What NOT to Test

- Exact LLM output at each node (same non-determinism principle as LLM-calling code)
- Framework internals (LangGraph's checkpointing, message passing — trust the framework)

### Key Patterns

**TDD for state transitions.** Define expected state transitions before implementing nodes. This is where TDD pays off most — the state machine is deterministic even if individual nodes use LLMs.

```text
# Define transitions first:
START → gather_context (always)
gather_context → analyze (if context.complete)
gather_context → ask_user (if context.incomplete)
analyze → generate_output (always)
generate_output → END (always)

# Then test each transition with known state
```

**Test the graph structure separately from node behavior.** Verify that the graph is wired correctly (edges, conditions) as a unit test. Test node behavior independently.

**Integration tests with real tools.** For agent frameworks that call external tools (file system, APIs, databases), prefer real integration over mocks. Mocking tool responses provides false confidence that the agent handles real-world behavior correctly. Source: Viktor Farcic's integration-first approach.

**Three-level verification for agent output.** Borrowed from TACHES: (1) Exists — did the agent produce output? (2) Substantive — is it real content, not a stub? (3) Wired — is it integrated with the rest of the system?

### Recommended Tools

- **Test framework**: Vitest (TypeScript), pytest (Python)
- **State machine visualization**: LangGraph Studio (for debugging, not automated testing)
- **Integration testing**: Real tool execution in isolated environments
- **Fixture isolation**: Per-test temporary directories and fresh state

### Coverage Targets

| Category | Target |
|---|---|
| State transitions | 80% branch coverage |
| Node logic (deterministic parts) | 80% |
| Error/failure paths | 70% |
| End-to-end happy paths | All critical user journeys |

---

## K8s/Infrastructure Interaction

Code that provisions, manages, or interacts with Kubernetes clusters, cloud resources, or infrastructure APIs. Examples: cluster-whisperer, operators, controllers, IaC tools.

### What to Test

**Integration tests against real infrastructure:**
- Deploy to a fresh Kind cluster per test run
- Verify resource creation, modification, and deletion
- Test full lifecycle workflows (CREATE → GET → LIST → UPDATE → DELETE)
- Validate controller reconciliation loops
- Test operator behavior with real CRDs

**API contract tests:**
- Kubernetes API request/response shapes
- Custom Resource Definition validation
- Webhook admission logic
- API versioning compatibility

**Configuration validation:**
- Helm chart rendering with different value sets
- Kustomize overlay application
- Environment-specific configuration resolution
- Secret reference validation (references exist, formats correct)

### What NOT to Test

- Kubernetes itself — trust the platform
- Cloud provider API behavior — test your interaction with it
- Helm/Kustomize template engines — test your inputs and outputs, not the tool

### Key Patterns

**Integration-first, unit tests optional.** For infrastructure-heavy systems, the value lies in integrating real components. Unit tests with mocked Kubernetes clients provide false confidence — the mock doesn't behave like a real cluster. Invest the time in real infrastructure testing instead. Source: Viktor Farcic's approach in dot-ai (zero unit tests, comprehensive Kind-based integration tests).

```text
# Good: test against real Kind cluster
beforeAll: create Kind cluster → install operators → deploy app → wait for readiness
test: interact with real cluster, validate real state
afterAll: delete cluster

# Risky: mock everything
test: mock K8s client → call function → assert mock was called with right args
# This passes even if real K8s API rejects your request
```

**Full environment provisioning.** Create fresh clusters per test run with all dependencies installed (operators, controllers, databases, ingress). This eliminates state leakage between tests and catches integration issues early.

**Lifecycle tests over atomic tests.** One test that covers CREATE → verify → UPDATE → verify → DELETE → verify is more valuable than three separate tests. It catches state transition bugs that atomic tests miss. Source: Viktor Farcic's workflow pattern.

**Reasonable timeouts.** Infrastructure tests are inherently slower. Set appropriate timeouts (5-20 minutes) and run them less frequently (pre-push or CI, not pre-commit). Don't try to make them fast — make them reliable.

### Recommended Tools

- **Cluster provisioning**: Kind (Kubernetes in Docker)
- **Test framework**: Vitest with extended timeouts, pytest
- **Deployment**: Helm, Kustomize
- **CI integration**: GitHub Actions with Kind setup action
- **Parallel execution**: Fork-based isolation with unique test IDs (`Date.now()` suffixes)

### Coverage Targets

| Category | Target |
|---|---|
| Critical lifecycle paths | Full integration coverage |
| Configuration rendering | All environment variants |
| Error handling | Major failure modes (unavailable cluster, invalid CRDs, timeouts) |
| Unit tests | Only for pure utility functions (if any) |

---

## Script-Orchestrated Tools

CLI tools, automation scripts, and orchestration utilities that coordinate other tools. Examples: deployment scripts, build tools, developer workflow CLIs, file processors.

### What to Test

**Input/output correctness (unit tests):**
- CLI argument parsing (valid, invalid, defaults, combinations)
- Configuration file reading and validation
- Output formatting (JSON, table, markdown, CSV)
- Exit codes for success, failure, and edge cases

**File operations (integration tests):**
- File creation, modification, and deletion
- Directory structure creation
- Path resolution (relative, absolute, edge cases)
- Permission handling

**Command orchestration:**
- Correct commands are invoked with correct arguments
- Error propagation from child processes
- Timeout handling for long-running commands
- Partial failure handling (some commands succeed, some fail)

**Data parsing and transformation:**
- Malformed input handling (corrupt files, unexpected formats)
- Boundary conditions (empty input, very large input)
- Character encoding edge cases

### What NOT to Test

- The behavior of external tools you're orchestrating — test your invocation and response handling
- Performance benchmarks in unit tests — profile separately

### Key Patterns

**Script-first for determinism.** All CLI operations should be deterministic and testable without AI. If you're using AI in a CLI tool, isolate it behind a clear boundary so the rest can be tested conventionally. Source: TACHES gsd-tools.js pattern (all deterministic operations in scripts, AI reserved for semantic analysis).

**Fixture-based isolation.** Create temporary directories for each test. Populate with known file structures. Clean up after. Never test against real user directories.

```text
# Pattern: isolated test environment
beforeEach: create tmp_dir → populate with known files → set config to use tmp_dir
test: run CLI command → assert output and side effects
afterEach: clean up tmp_dir
```

**Test the full CLI surface.** Every command, every flag, every output format. CLI tools have a contract with users — breaking changes in argument handling are bugs.

**Contradiction detection for configuration.** If your tool reads configuration from multiple sources (global + project), test for conflicts between them. Source: Forrester's llm-coding-workflow drift analyzer, which detects when project rules contradict global rules.

### Recommended Tools

- **Test framework**: Vitest (TypeScript), pytest (Python), Node.js built-in test runner (lightweight CLIs)
- **CLI testing**: Direct invocation with captured stdout/stderr
- **Fixture management**: `tmp_path` (pytest), `mkdtemp` (Node.js)
- **Snapshot testing**: For output format validation (use sparingly — only for stable output)

### Coverage Targets

| Category | Target |
|---|---|
| Argument parsing | 90% |
| Data parsing / transformation | 90% |
| Business logic | 80% |
| File operations | 80% |
| Output formatting | 80% |
| Error handling | 70% |

---

## Pure Utilities

Libraries, helper functions, and standalone modules with no external dependencies. Examples: date formatters, string processors, math utilities, data structure helpers.

### What to Test

**Everything.** Pure utilities have no excuse for low coverage. They're deterministic, fast to test, and have clear input/output contracts.

- All public functions with representative inputs
- Edge cases: null, undefined, empty strings, empty arrays, zero, negative numbers
- Boundary conditions: max/min values, off-by-one, overflow
- Type coercion edge cases (if dynamically typed)
- Error cases: invalid input types, out-of-range values

### Key Patterns

**TDD is natural here.** Pure utilities are the ideal TDD use case — define the expected behavior, write the test, then implement. The red-green-refactor cycle works perfectly for deterministic functions.

**Property-based testing for mathematical operations.** Instead of testing specific inputs, define properties that must hold for all inputs.

```text
# Property: reversing a list twice returns the original
for any list L: reverse(reverse(L)) == L

# Property: sorting is idempotent
for any list L: sort(sort(L)) == sort(L)
```

**Exhaustive edge case coverage.** Use a systematic approach — for each parameter, test: valid typical, valid boundary, invalid type, null/undefined, empty.

**No mocks.** Pure utilities by definition have no external dependencies. If you need mocks, your utility isn't pure — refactor to extract the dependency.

### Recommended Tools

- **Test framework**: Vitest (TypeScript), pytest (Python)
- **Property-based testing**: fast-check (TypeScript), Hypothesis (Python)
- **Coverage**: Istanbul/c8 (TypeScript), pytest-cov (Python)
- **Mutation testing**: Stryker (TypeScript) — optional but valuable for critical utilities

### Coverage Targets

| Category | Target |
|---|---|
| Public API | 95%+ |
| Edge cases | Exhaustive |
| Error handling | 90% |
| Internal helpers | 80% |

---

## Cross-Cutting Concerns

These patterns apply regardless of project type.

### Separate Deterministic from Probabilistic

The single most important architectural decision for testability. Structure your code so deterministic logic (parsing, validation, formatting, scoring, file I/O) is isolated from non-deterministic operations (LLM calls, network requests, user input). Test the deterministic parts exhaustively. Test the non-deterministic boundaries with contracts and fixtures.

This principle appears independently in every source researched:
- Viktor Farcic: integration tests for real infrastructure, no mocks
- Michael Forrester: TDD for logic, coverage tiers by category
- Affaan Mustafa: eval harness for AI, unit tests for logic
- TACHES: script-first for deterministic operations, AI for semantic analysis
- Forrester (llm-coding-workflow): 175 deterministic tests, zero LLM calls in test suite

### Test Organization

**Co-locate tests with source.** `tests/` directory mirrors `src/` structure. Test file names match source file names (`tokens.py` → `test_tokens.py`).

**Class-based grouping for related assertions.** Group tests by the function or feature they're testing. Method names describe the specific behavior being verified.

```text
class TestCalculateCost:
    def test_returns_zero_for_no_tokens(self): ...
    def test_sums_input_and_output_costs(self): ...
    def test_applies_cache_discount(self): ...
```

**Helper factories over raw constructors.** Create `_make_*()` functions that produce valid test objects with overridable defaults. This eliminates boilerplate and makes tests focus on the variation that matters.

### Coverage Tiers by Code Category

Not all code deserves equal coverage investment. Adapted from Michael Forrester's tiered approach:

| Category | Coverage Target | Rationale |
|---|---|---|
| Security-critical code | 100% branch | Bugs here have outsized impact |
| Business logic | 80% line | Core value; worth thorough testing |
| Pure utilities | 90% line | Easy to test, no excuse for gaps |
| API/integration layer | Contract coverage | Line coverage is misleading for I/O code |
| Configuration/glue code | 50% line | Low complexity, high change frequency |
| UI components | 70% line | Test behavior, not rendering details |

### When TDD Pays Off vs When It Doesn't

**Use TDD for:** Business logic, state machines, pure utilities, parsing/validation, security-critical code, any function where you can define expected output before writing the implementation.

**Skip TDD for:** Exploratory prototyping, UI layout, configuration/glue code, infrastructure provisioning scripts, one-off migration scripts. Write tests after implementation for these. Source: TACHES' pragmatic TDD approach.

### Stub Detection

Verify that implementations are real, not placeholders that pass tests trivially. Watch for:
- `return <div>Component</div>` (empty component)
- `return Response.json({ message: "Not implemented" })` (fake success)
- `// TODO: implement` with a passing test
- Functions that exist but aren't called from anywhere

Source: TACHES' three-level verification (Exists → Substantive → Wired).

### Anti-Patterns to Avoid

1. **Mocking what you should be integrating.** If the value of your system is in how components interact, mocking those interactions defeats the purpose. Mock at system boundaries, not internal seams.

2. **Generic assertions.** `expect.any(Object)` and `expect.objectContaining({})` hide bugs. Assert against specific, known expected values.

3. **Fragmented lifecycle tests.** Separate CREATE/GET/UPDATE/DELETE tests miss state transition bugs. One test covering the full lifecycle is more valuable.

4. **Testing after the fact.** "I'll add tests later" usually means "I won't add tests." For critical code, write tests first or alongside.

5. **Hardcoded test data that should be parameterized.** When you copy-paste a test and change one value, use parameterized tests instead.

6. **Testing framework internals.** Trust your frameworks. Test your code's interaction with them, not their behavior.

---

## Choosing Your Strategy

If your project spans multiple types (common), prioritize by risk:

1. **What breaks worst?** Test that most thoroughly
2. **What changes most?** That needs the most regression coverage
3. **What's hardest to debug?** That benefits most from test isolation

Start with the project type that represents your core risk, then layer on patterns from secondary types as needed.
