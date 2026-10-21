# Changelog

## 0.2.0 — proposed, unreleased maintenance contribution

- Correct anchored RFC 5545 period expansion and skip invalid calendar dates.
- Add WKST, negative monthdays, ordinal weekdays, BYSETPOS and strict rule validation.
- Preserve DTSTART/global COUNT across moving-window and next-occurrence queries.
- Add explicit query budgets and checked, nonrecursive calendar arithmetic.
- Add 200 independently generated reference vectors plus targeted regressions.
- Fix Node CLI argument normalization; require DTSTART for RRULE next queries.
- Document breaking changes, upstream attribution and reproducible cross-backend checks.

This branch is not an upstream acceptance or published Mooncakes release.

## 0.1.0

- Added deterministic UTC `DateTime` with validation, arithmetic and formatting.
- Added five-field Cron parser, matcher and next-occurrence search.
- Added RFC 5545 RRULE subset parser and occurrence enumeration.
- Added a runnable CLI simulator and cross-target CI.
