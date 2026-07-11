///|
test "calendar validates and formats leap day" {
  let dt = DateTime::new(2024, 2, 29, 23, 59)
  inspect(dt.to_string(), content="2024-02-29T23:59Z")
  inspect(dt.next_day().to_string(), content="2024-03-01T00:00Z")
}

///|
test "calendar weekday uses cron sunday zero" {
  let sunday = DateTime::new(2025, 1, 5, 0, 0)
  assert_eq(sunday.weekday(), 0)
}
