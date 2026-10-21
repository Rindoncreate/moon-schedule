///|
test "calendar validates and formats leap day" {
  let dt = @schedule.DateTime::new(2024, 2, 29, 23, 59)
  inspect(dt.to_string(), content="2024-02-29T23:59Z")
  inspect(dt.next_day().to_string(), content="2024-03-01T00:00Z")
}

///|
test "calendar weekday uses cron sunday zero" {
  let sunday = @schedule.DateTime::new(2025, 1, 5, 0, 0)
  assert_eq(sunday.weekday(), 0)
}

///|
test "calendar follows Gregorian century leap rules" {
  assert_false(@schedule.is_leap_year(1900))
  assert_true(@schedule.is_leap_year(2000))
  assert_eq(@schedule.days_in_month(1900, 2), 28)
  assert_eq(@schedule.days_in_month(2000, 2), 29)
}

///|
test "calendar subtracts minutes across a year boundary" {
  let start = @schedule.DateTime::new(2025, 1, 1, 0, 0)
  inspect(start.add_minutes(-1).to_string(), content="2024-12-31T23:59Z")
}
