///|
test "rrule honors count and weekday filters" {
  let rule = RRule::parse("FREQ=DAILY;COUNT=3;BYDAY=MO,WE,FR")
  let start = DateTime::new(2025, 1, 6, 9, 0)
  let end = DateTime::new(2025, 1, 12, 9, 0)
  let values = rule.occurrences_between(start, end)
  assert_eq(values.length(), 3)
  inspect(values[2].to_string(), content="2025-01-10T09:00Z")
}

///|
test "rrule monthly clamps end of month" {
  let rule = RRule::parse("FREQ=MONTHLY;COUNT=2")
  let start = DateTime::new(2024, 1, 31, 8, 0)
  let end = DateTime::new(2024, 3, 31, 8, 0)
  let values = rule.occurrences_between(start, end)
  inspect(values[1].to_string(), content="2024-02-29T08:00Z")
}
