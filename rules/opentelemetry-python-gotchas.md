---
paths: ["**/*telemetry*.py", "**/*tracing*.py", "**/*span*.py", "**/otel*.py", "src/languages/python/**"]
---

# OpenTelemetry Python SDK Gotchas

Verified against `opentelemetry-api`/`opentelemetry-sdk` 1.35.0 source (`opentelemetry/trace/__init__.py`'s `use_span()`, which backs `start_as_current_span()`), 2026-09-18.

## `start_as_current_span()` auto-records exceptions and sets ERROR status by default — unlike JavaScript

`tracer.start_as_current_span(...)` (and the lower-level `use_span()` it's built on) defaults to `record_exception=True` and `set_status_on_exception=True`. Any exception that propagates out of the `with` block is automatically recorded as an exception event on the span, and the span's status is automatically set to `ERROR` — with no manual call needed.

This is different from JavaScript's `tracer.startActiveSpan()`, which has no equivalent automatic behavior and always requires a manual `span.recordException(e)` + `span.setStatus({ code: SpanStatusCode.ERROR })` in every `catch` block. Do not port JavaScript's "every catch block needs manual recording" assumption into Python code or prompts without checking this first — it produces a **duplicate exception event** on the span (one from the manual call, one from the SDK's own automatic handling).

**Concretely:**
- An `except` block that **re-raises** (bare `raise`, or `raise NewError(...) from e`) is already covered — the exception still propagates out of the `with` block, so it's recorded automatically. Do NOT add manual `record_exception`/`set_status` calls here.
- An `except` block that **swallows** the exception (returns a fallback value, logs and continues, does not re-raise) is NOT covered automatically — the SDK's automatic handling only fires for exceptions that actually leave the `with` block. Manual `span.record_exception(e)` + `span.set_status(Status(StatusCode.ERROR, str(e)))` calls ARE needed here, or the error goes completely unrecorded on the span.

Verify directly if this ever needs re-checking: `python3 -c "import opentelemetry.trace, os; print(os.path.dirname(opentelemetry.trace.__file__))"`, then read `use_span()`'s source in that file.

## `use_span()`'s `end_on_exit` defaults to `False` — the opposite of what its sibling defaults suggest

`use_span(span, end_on_exit=False, record_exception=True, set_status_on_exception=True)` — verified directly against the real signature in `opentelemetry/trace/__init__.py`. Unlike `record_exception`/`set_status_on_exception` (both default `True`, see above), `end_on_exit` defaults to **`False`**: `with use_span(span):` does **not** close `span` when the `with` block exits — the span must still be ended manually (`span.end()`) unless the caller explicitly passes `end_on_exit=True`.

It's easy to assume all three parameters share the same "safe by default" `True` pattern, since two of them do — this was a real, shipped mistake (spinybacked-orbweaver PRD #373, CDQ-001 checker, caught by a CodeRabbit review round after the wrong assumption passed code review, typecheck, and a full test suite once). Never assume a Python OTel SDK parameter's default without checking its real signature — analogy from a sibling parameter in the same call is not verification.

`start_as_current_span()` itself internally calls `use_span()` with `end_on_exit=True` explicitly — that's why `with tracer.start_as_current_span(...):` *does* close the span automatically, while a bare `with use_span(span):` does not. The two context managers are not interchangeable defaults.
