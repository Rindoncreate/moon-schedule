///|
test "RFC monthly recurrence skips invalid month days instead of clamping" {
  let rule = @schedule.RRule::parse("FREQ=MONTHLY;COUNT=3")
  let values = rule.occurrences_between(
    @schedule.DateTime::new(2025, 1, 31, 9, 0),
    @schedule.DateTime::new(2025, 5, 31, 9, 0),
  )
  assert_eq(values.map(dt => dt.to_string()), [
    "2025-01-31T09:00Z", "2025-03-31T09:00Z", "2025-05-31T09:00Z",
  ])
}

///|
test "RFC weekly BYDAY expands every requested weekday within a week" {
  let rule = @schedule.RRule::parse("FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4")
  let values = rule.occurrences_between(
    @schedule.DateTime::new(2025, 1, 6, 9, 0),
    @schedule.DateTime::new(2025, 1, 15, 9, 0),
  )
  assert_eq(values.map(dt => dt.to_string()), [
    "2025-01-06T09:00Z", "2025-01-08T09:00Z", "2025-01-13T09:00Z", "2025-01-15T09:00Z",
  ])
}

///|
test "RFC monthly BYMONTHDAY expands multiple days in each month" {
  let rule = @schedule.RRule::parse("FREQ=MONTHLY;BYMONTHDAY=1,15;COUNT=4")
  let values = rule.occurrences_between(
    @schedule.DateTime::new(2025, 1, 1, 9, 0),
    @schedule.DateTime::new(2025, 2, 28, 9, 0),
  )
  assert_eq(values.map(dt => dt.to_string()), [
    "2025-01-01T09:00Z", "2025-01-15T09:00Z", "2025-02-01T09:00Z", "2025-02-15T09:00Z",
  ])
}

///|
test "RFC yearly BYMONTH expands each month without changing the anchor day" {
  let rule = @schedule.RRule::parse("FREQ=YEARLY;BYMONTH=1,3;COUNT=4")
  let values = rule.occurrences_between(
    @schedule.DateTime::new(2025, 1, 10, 9, 0),
    @schedule.DateTime::new(2026, 3, 10, 9, 0),
  )
  assert_eq(values.map(dt => dt.to_string()), [
    "2025-01-10T09:00Z", "2025-03-10T09:00Z", "2026-01-10T09:00Z", "2026-03-10T09:00Z",
  ])
}

///|
test "RFC yearly leap day recurrence skips non leap years" {
  let rule = @schedule.RRule::parse("FREQ=YEARLY;COUNT=3")
  let values = rule.occurrences_between(
    @schedule.DateTime::new(2024, 2, 29, 9, 0),
    @schedule.DateTime::new(2032, 2, 29, 9, 0),
  )
  assert_eq(values.map(dt => dt.to_string()), [
    "2024-02-29T09:00Z", "2028-02-29T09:00Z", "2032-02-29T09:00Z",
  ])
}
