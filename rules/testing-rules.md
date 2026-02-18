# Testing Rules

Always/Never patterns for AI-assisted development. Add these to a project's CLAUDE.md or load as Claude Code rules.

---

## Always

- **Write tests for new functionality before marking a task complete.** Tests are the definition of done. No tests, not done.
- **Run all tests before committing.** Don't rely on CI to catch what you could have caught locally.
- **Check for regressions when modifying existing code.** Run the existing test suite, not just new tests.
- **Separate deterministic logic from non-deterministic operations.** Parsing, validation, formatting, and scoring should be testable without LLM calls, network requests, or user input.
- **Use real implementations when feasible; mock only at system boundaries.** Mocking internal seams provides false confidence. Mock external APIs, databases, and third-party services — not your own modules.
- **Write integration tests for cross-component interactions.** Unit tests prove individual pieces work. Integration tests prove they work together.
- **Test edge cases: null, empty, zero, boundary values, malformed input.** The happy path works until it doesn't. Edge cases are where bugs hide.
- **Use helper factories for test data instead of raw constructors.** `_make_session(cost=0.05)` is clearer than 15 lines of object construction.
- **Assert against specific expected values, not generic matchers.** `expect.any(Object)` hides bugs. Assert what you know.
- **Verify implementations are substantive, not stubs.** A function that exists but returns a placeholder passes tests trivially. Check: Exists → Substantive → Wired.

## Never

- **Skip tests for "simple" changes.** Simple changes break things too. If it's worth committing, it's worth testing.
- **Commit with failing tests.** Fix the tests or revert the change. Red tests in the repo erode trust in the entire suite.
- **Mock when real integration testing is feasible.** If you can test against a real database, real filesystem, or real API in a reasonable time, prefer that over mocks.
- **Claim work is done without running the test suite.** "It compiles" is not "it works."
- **Hardcode test data that should be generated or parameterized.** When tests differ by one value, use parameterized tests.
- **Test framework internals or third-party library behavior.** Trust your frameworks. Test your interaction with them.
- **Use generic assertions that pass regardless of content.** `toMatchObject({})` matches everything. Be specific.
- **Write tests that depend on execution order or shared state.** Each test should set up its own state and clean up after itself.
- **Leave test infrastructure as an afterthought.** Fixtures, factories, and helpers are first-class code. Invest in them early.
- **Treat LLM output testing like deterministic testing.** LLM responses are non-deterministic. Test the contract (request shape, response handling), not the content. Use evals for quality assessment.
