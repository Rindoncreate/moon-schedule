# Supported semantics and migration

References: [RFC 5545 section 3.3.10](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.10), [RRULE examples](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.5.3), [dateutil reference](https://dateutil.readthedocs.io/en/stable/rrule.html).

## Supported subset

| Rule part | Semantics |
| --- | --- |
| FREQ | DAILY, WEEKLY, MONTHLY, YEARLY |
| INTERVAL | Positive ASCII integer up to Int32 maximum; phase stays relative to DTSTART |
| COUNT | Counts matching occurrences over the complete anchored set, including those before the query window |
| UNTIL | Inclusive UTC boundary; RFC basic `YYYYMMDDTHHMM00Z` and the original ISO minute form are accepted |
| BYMONTH | 1..12; expands YEARLY and filters other frequencies |
| BYMONTHDAY | 1..31 and -31..-1; zero rejected; invalid calendar dates skipped; forbidden with WEEKLY |
| BYDAY | Plain weekdays; signed 1..53 weekday ordinals only for MONTHLY/YEARLY |
| WKST | Default MO; controls weekly period boundaries and alternating-week phase |
| BYSETPOS | Signed positions 1..366 in each full filtered frequency period; requires another BY part |

Dates use the proleptic Gregorian calendar, years 1..9999, UTC and minute precision. The recurrence keeps DTSTART's hour and minute. A DTSTART that does not satisfy the filters is not forcibly inserted into the result; RFC recurrence with mismatched DTSTART is undefined, and this library follows the explicitly tested filtering behavior of the reference oracle. Applications needing strict RFC recurrence-set behavior should ensure DTSTART matches the rule.

Each full period is filtered and BYSETPOS is selected **before** cutting off DTSTART, UNTIL or the query window. This prevents the first Monday after a mid-month query from incorrectly replacing the first Monday of that month. Duplicate positions and duplicate matching rules produce one chronological occurrence, not duplicate timestamps.

## API migration from 0.1.0

- Month-end recurrence changes intentionally: January 31 produces March 31 next, not February 28/29. Leap-day YEARLY recurrences skip non-leap years.
- `occurrences_between(start, end)` remains an inclusive query anchored at `start`, but now raises `ScheduleError` on budget exhaustion.
- Use `occurrences_window(dtstart, from, end, period_limit=..., result_limit=...)` for a moving window. Never replace DTSTART with the window start.
- Use `next_after_from(dtstart, after)` for strict next-occurrence queries. The legacy `next_after(after)` is deprecated: without a DTSTART argument it cannot recover the original phase or previous COUNT consumption.
- `DateTime::add_minutes` and `next_day` now raise on calendar-domain overflow; callers must handle `ScheduleError`.
- `RRule.weekdays` now exposes `WeekdaySpec` values, including optional ordinals. New `week_start` and `positions` fields are readable.
- Duplicate keys, COUNT+UNTIL, illegal field combinations and nonzero UNTIL seconds now fail explicitly.
- RRULE `next` CLI syntax now requires both DTSTART and `after`. Invalid CLI input returns a nonzero status.

## Resource and compatibility boundaries

Default query budgets: 20,000 visited frequency periods and 10,000 returned occurrences. Explicit budgets must be 1..1,000,000. Exceeding a budget raises `InvalidRule`; it does not mean no occurrence exists. Uncounted rules seek to the query period. COUNT rules must account for earlier matching dates and may need a larger period budget for a distant window.

Rules are limited to 4,096 UTF-16 code units. Unknown fields are errors. This branch does not implement a full RFC 5545 or timezone engine.
