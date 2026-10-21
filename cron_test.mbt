///|
test "cron supports ranges steps and named weekdays" {
  let cron = @schedule.Cron::parse("*/15 9-17 * * MON-FRI")
  let monday = @schedule.DateTime::new(2025, 1, 6, 9, 30)
  let sunday = @schedule.DateTime::new(2025, 1, 5, 9, 30)
  assert_true(cron.matches(monday))
  assert_false(cron.matches(sunday))
}

///|
test "cron finds the next matching minute" {
  let cron = @schedule.Cron::parse("0 0 1 JAN *")
  let after = @schedule.DateTime::new(2024, 12, 31, 23, 59)
  inspect(cron.next_after(after).to_string(), content="2025-01-01T00:00Z")
}

///|
test "cron combines day of month and weekday with OR" {
  let cron = @schedule.Cron::parse("0 9 15 * MON")
  assert_true(cron.matches(@schedule.DateTime::new(2025, 1, 6, 9, 0)))
  assert_true(cron.matches(@schedule.DateTime::new(2025, 1, 15, 9, 0)))
  assert_false(cron.matches(@schedule.DateTime::new(2025, 1, 14, 9, 0)))
}

///|
test "cron accepts seven as the sunday alias" {
  let cron = @schedule.Cron::parse("0 0 * * 7")
  assert_true(cron.matches(@schedule.DateTime::new(2025, 1, 5, 0, 0)))
}
