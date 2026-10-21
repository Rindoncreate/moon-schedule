///|
test "large positive and negative offsets do not recurse per minute" {
  let date = @schedule.DateTime::new(2000, 1, 1, 9, 15)
  let moved = date.add_minutes(2000000000)
  assert_eq(moved.add_minutes(-2000000000), date)
  assert_eq(date.add_minutes(525600).to_string(), "2000-12-31T09:15Z")
  assert_eq(date.add_minutes(-1).to_string(), "2000-01-01T09:14Z")
}

///|
test "Gregorian ordinal conversion agrees at century and year boundaries" {
  for year in [1, 4, 100, 400, 1600, 1900, 2000, 2024, 2100, 2400, 9999] {
    for month in 1..<=12 {
      let date = @schedule.DateTime::new(
        year,
        month,
        @schedule.days_in_month(year, month),
        23,
        58,
      )
      assert_eq(date.add_minutes(1).add_minutes(-1), date)
      if year != 9999 || month != 12 {
        assert_eq(date.add_minutes(2).add_minutes(-2), date)
      }
    }
  }
}

///|
test "calendar rejects overflow beyond its supported year domain" {
  for
    (date, delta) in [
      (@schedule.DateTime::new(1, 1, 1, 0, 0), -1),
      (@schedule.DateTime::new(9999, 12, 31, 23, 59), 1),
      (@schedule.DateTime::new(1, 1, 1, 0, 0), -2147483648),
    ] {
    try date.add_minutes(delta) catch {
      @schedule.InvalidDate(_) => ()
      _ => fail("unexpected error")
    } noraise {
      _ => fail("expected bounded calendar error")
    }
  }
  for text in ["+025-01-01T09:00Z", "2025-+1-01T09:00Z", "0000-01-01T09:00Z"] {
    try @schedule.DateTime::parse(text) catch {
      @schedule.InvalidDate(_) => ()
      _ => fail("unexpected error")
    } noraise {
      _ => fail("expected strict calendar input")
    }
  }
}
