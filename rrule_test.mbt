///|
test "rrule honors count and weekday filters" {
  let rule = @schedule.RRule::parse("FREQ=DAILY;COUNT=3;BYDAY=MO,WE,FR")
  let start = @schedule.DateTime::new(2025, 1, 6, 9, 0)
  let end = @schedule.DateTime::new(2025, 1, 12, 9, 0)
  let values = rule.occurrences_between(start, end)
  assert_eq(values.length(), 3)
  inspect(values[2].to_string(), content="2025-01-10T09:00Z")
}

///|
test "rrule monthly skips invalid end of month" {
  let rule = @schedule.RRule::parse("FREQ=MONTHLY;COUNT=2")
  let start = @schedule.DateTime::new(2024, 1, 31, 8, 0)
  let end = @schedule.DateTime::new(2024, 3, 31, 8, 0)
  let values = rule.occurrences_between(start, end)
  inspect(values[1].to_string(), content="2024-03-31T08:00Z")
}

///|
test "rrule includes the until boundary" {
  let rule = @schedule.RRule::parse("FREQ=DAILY;UNTIL=2025-01-03T09:00Z")
  let start = @schedule.DateTime::new(2025, 1, 1, 9, 0)
  let end = @schedule.DateTime::new(2025, 1, 5, 9, 0)
  let values = rule.occurrences_between(start, end)
  assert_eq(values.length(), 3)
  inspect(values[2].to_string(), content="2025-01-03T09:00Z")
}

///|
test "rrule advances by the requested interval" {
  let rule = @schedule.RRule::parse("FREQ=WEEKLY;INTERVAL=2;COUNT=3")
  let start = @schedule.DateTime::new(2025, 1, 6, 9, 0)
  let end = @schedule.DateTime::new(2025, 2, 10, 9, 0)
  let values = rule.occurrences_between(start, end)
  assert_eq(values.length(), 3)
  inspect(values[2].to_string(), content="2025-02-03T09:00Z")
}
