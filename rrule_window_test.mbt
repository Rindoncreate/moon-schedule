///|
test "window queries retain DTSTART phase and global COUNT" {
  let rule = @schedule.RRule::parse("FREQ=DAILY;INTERVAL=2;COUNT=3")
  let start = @schedule.DateTime::new(2025, 1, 1, 9, 0)
  let from = @schedule.DateTime::new(2025, 1, 4, 0, 0)
  let end = @schedule.DateTime::new(2025, 1, 12, 9, 0)
  assert_eq(
    rule.occurrences_window(start, from, end).map(dt => dt.to_string()),
    ["2025-01-05T09:00Z"],
  )
}

///|
test "next query uses an explicit anchor and does not reset count" {
  let rule = @schedule.RRule::parse("FREQ=DAILY;COUNT=3")
  let start = @schedule.DateTime::new(2025, 1, 1, 9, 0)
  let after = @schedule.DateTime::new(2025, 1, 2, 10, 0)
  assert_eq(
    rule.next_after_from(start, after).map(dt => dt.to_string()),
    Some("2025-01-03T09:00Z"),
  )
  assert_eq(
    rule.next_after_from(start, @schedule.DateTime::new(2025, 1, 3, 9, 0)),
    None,
  )
}

///|
test "maximal interval cannot wrap the period arithmetic" {
  let rule = @schedule.RRule::parse("FREQ=WEEKLY;INTERVAL=2147483647")
  let start = @schedule.DateTime::new(2025, 1, 6, 9, 0)
  assert_eq(
    rule
    .occurrences_between(start, @schedule.DateTime::new(9999, 12, 31, 0, 0))
    .length(),
    1,
  )
}

///|
test "budget exhaustion raises instead of returning partial results" {
  let rule = @schedule.RRule::parse("FREQ=DAILY")
  let start = @schedule.DateTime::new(2025, 1, 1, 9, 0)
  let end = @schedule.DateTime::new(2025, 1, 3, 9, 0)
  try rule.occurrences_window(start, start, end, period_limit=2) catch {
    @schedule.InvalidRule(_) => ()
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("period budget must fail explicitly")
  }
  try rule.occurrences_window(start, start, end, result_limit=2) catch {
    @schedule.InvalidRule(_) => ()
    _ => fail("unexpected error kind")
  } noraise {
    _ => fail("result budget must fail explicitly")
  }
  assert_eq(
    rule
    .occurrences_window(start, start, start, period_limit=1, result_limit=1)
    .length(),
    1,
  )
}

///|
test "empty windows and the upper calendar boundary terminate" {
  let rule = @schedule.RRule::parse("FREQ=DAILY")
  let start = @schedule.DateTime::new(9999, 12, 31, 23, 59)
  assert_eq(rule.next_after_from(start, start), None)
  assert_eq(rule.occurrences_between(start, start).length(), 1)
  assert_eq(
    rule
    .occurrences_window(
      start,
      start,
      @schedule.DateTime::new(9999, 12, 30, 0, 0),
    )
    .length(),
    0,
  )
}
