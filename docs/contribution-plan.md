# RFC 5545 recurrence compatibility maintenance

This is a maintenance contribution to [100kkk/moon-schedule](https://github.com/100kkk/moon-schedule), based on upstream commit `1d35dc9f150f9cb8f4f891f7ac98a284621afdc1`. Original author: 100kkk. This branch's maintenance contributor: Rindoncreate, with AI assistance. The original MIT license is preserved.

## Why maintain this project

The published package already provides a portable UTC Cron/RRULE foundation. Creating another scheduling library would duplicate existing MoonBit packages. This work instead fixes correctness problems in the API's existing declared RFC 5545 subset and adds reproducible independent compatibility tests.

The baseline's 12 tests pass. Adding `rrule_regression_test.mbt` to the baseline produced five real failures: monthly invalid dates, weekly BYDAY expansion, monthly BYMONTHDAY expansion, yearly BYMONTH expansion, and leap-day recurrence. The upstream test explicitly expecting month-end clamping is intentionally changed: RFC 5545 recurrence ignores invalid dates instead of moving them to a different date. This is a behavioral compatibility change requiring maintainer review, not a claim that the maintainer has approved this contribution.

## This contribution's scope

- Replace increment-and-filter recurrence with anchored frequency-period expansion.
- Preserve DTSTART and lifetime COUNT across window and next-occurrence queries.
- Add WKST, negative BYMONTHDAY, ordinal BYDAY, and BYSETPOS within the UTC/minute subset.
- Reject duplicate/contradictory rule parts and unsupported fields rather than guessing.
- Raise explicit errors on query-budget exhaustion instead of returning a partial set.
- Replace per-minute recursive arithmetic with checked Gregorian ordinal arithmetic.
- Add independent reference vectors, cross-backend checks, CLI validation and three runnable consumer examples.

## Explicit exclusions

No timezone/DST engine, seconds precision, HOURLY/MINUTELY/SECONDLY, BYHOUR/BYMINUTE/BYSECOND, BYWEEKNO/BYYEARDAY, EXDATE/RDATE collections, full ICS parser, daemon, notification delivery or business UI. This is not a claim of complete RFC 5545 compliance.

## Acceptance evidence and attribution

Only commits after the upstream base above are this contribution. Generated test code is labeled and is not counted as hand-written production complexity. The reference outputs come from python-dateutil 2.9.0.post0 and Python datetime; no dateutil implementation source is copied. Python is a development-only dependency.

The local branch is not proof of upstream acceptance, a new Mooncakes release or contest approval. Version 0.2.0 is a proposed unreleased compatibility update. Do not publish under the upstream author's namespace. An upstream PR, maintainer review and registry publication are separate external steps.

## Contest alignment

The charter permits maintaining or extending existing ecosystem projects and prefers such contributions when similar projects already exist. The contest website also explicitly allows maintenance of projects created by others. This work therefore belongs to the existing-project maintenance direction; prior code and upstream commits must not be represented as new work, and new-project startup incentives must not be assumed.

This is an AI-assisted technical plan, not the participant's required manually written formal application.
