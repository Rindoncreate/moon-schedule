///|
test "cron supports ranges steps and named weekdays" {
  let cron = Cron::parse("*/15 9-17 * * MON-FRI")
  let monday = DateTime::new(2025, 1, 6, 9, 30)
  let sunday = DateTime::new(2025, 1, 5, 9, 30)
  assert_true(cron.matches(monday))
  assert_false(cron.matches(sunday))
}

///|
test "cron finds the next matching minute" {
  let cron = Cron::parse("0 0 1 JAN *")
  let after = DateTime::new(2024, 12, 31, 23, 59)
  inspect(cron.next_after(after).to_string(), content="2025-01-01T00:00Z")
}
