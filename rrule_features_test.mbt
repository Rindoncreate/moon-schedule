///|
fn occurrences(
  rule : String,
  start : String,
  end : String,
) -> Array[String] raise @schedule.ScheduleError {
  @schedule.RRule::parse(rule)
  .occurrences_between(
    @schedule.DateTime::parse(start),
    @schedule.DateTime::parse(end),
  )
  .map(date => date.to_string())
}

///|
test "WKST changes the phase of alternating weeks" {
  assert_eq(
    occurrences(
      "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=MO", "1997-08-05T09:00Z",
      "1997-09-30T09:00Z",
    ),
    [
      "1997-08-05T09:00Z", "1997-08-10T09:00Z", "1997-08-19T09:00Z", "1997-08-24T09:00Z",
    ],
  )
  assert_eq(
    occurrences(
      "FREQ=WEEKLY;INTERVAL=2;COUNT=4;BYDAY=TU,SU;WKST=SU", "1997-08-05T09:00Z",
      "1997-09-30T09:00Z",
    ),
    [
      "1997-08-05T09:00Z", "1997-08-17T09:00Z", "1997-08-19T09:00Z", "1997-08-31T09:00Z",
    ],
  )
}

///|
test "negative monthdays mean days counted from the end of each month" {
  assert_eq(
    occurrences(
      "FREQ=MONTHLY;BYMONTHDAY=-1;COUNT=3", "2024-01-31T08:00Z", "2024-03-31T08:00Z",
    ),
    ["2024-01-31T08:00Z", "2024-02-29T08:00Z", "2024-03-31T08:00Z"],
  )
}

///|
test "ordinal weekdays support first and last weekdays of a month" {
  assert_eq(
    occurrences(
      "FREQ=MONTHLY;BYDAY=1MO,-1FR;COUNT=4", "2025-01-06T09:00Z", "2025-02-28T09:00Z",
    ),
    [
      "2025-01-06T09:00Z", "2025-01-31T09:00Z", "2025-02-03T09:00Z", "2025-02-28T09:00Z",
    ],
  )
}

///|
test "yearly ordinal BYDAY is within year or specified months" {
  assert_eq(
    occurrences(
      "FREQ=YEARLY;BYDAY=-1MO;COUNT=2", "2024-12-30T09:00Z", "2025-12-31T09:00Z",
    ),
    ["2024-12-30T09:00Z", "2025-12-29T09:00Z"],
  )
  assert_eq(
    occurrences(
      "FREQ=YEARLY;BYMONTH=1,2;BYDAY=1MO;COUNT=3", "2025-01-06T09:00Z", "2026-01-31T09:00Z",
    ),
    ["2025-01-06T09:00Z", "2025-02-03T09:00Z", "2026-01-05T09:00Z"],
  )
}

///|
test "BYSETPOS selects before applying DTSTART UNTIL and query windows" {
  assert_eq(
    occurrences(
      "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3", "2025-01-31T09:00Z",
      "2025-03-31T09:00Z",
    ),
    ["2025-01-31T09:00Z", "2025-02-28T09:00Z", "2025-03-31T09:00Z"],
  )
  // The first Monday of January precedes DTSTART; it must not become January 13.
  assert_eq(
    occurrences(
      "FREQ=MONTHLY;BYDAY=MO;BYSETPOS=1;COUNT=2", "2025-01-13T09:00Z", "2025-04-30T09:00Z",
    ),
    ["2025-02-03T09:00Z", "2025-03-03T09:00Z"],
  )
}

///|
test "BYSETPOS deduplicates overlapping positive and negative positions" {
  assert_eq(
    occurrences(
      "FREQ=MONTHLY;BYMONTHDAY=1,15;BYSETPOS=2,-1,1;COUNT=3", "2025-01-01T09:00Z",
      "2025-02-28T09:00Z",
    ),
    ["2025-01-01T09:00Z", "2025-01-15T09:00Z", "2025-02-01T09:00Z"],
  )
}

///|
test "RFC compact UTC UNTIL is inclusive" {
  assert_eq(
    occurrences(
      "FREQ=DAILY;UNTIL=20250103T090000Z", "2025-01-01T09:00Z", "2025-01-10T09:00Z",
    ),
    ["2025-01-01T09:00Z", "2025-01-02T09:00Z", "2025-01-03T09:00Z"],
  )
}

///|
test "parser rejects ambiguous contradictory and unsupported rules" {
  for
    text in [
      "FREQ=DAILY;FREQ=WEEKLY", "FREQ=DAILY;freq=WEEKLY", "FREQ=DAILY;COUNT=2;UNTIL=20250103T090000Z",
      "FREQ=WEEKLY;BYMONTHDAY=1", "FREQ=DAILY;BYDAY=1MO", "FREQ=MONTHLY;BYSETPOS=-1",
      "FREQ=MONTHLY;BYMONTHDAY=0", "FREQ=MONTHLY;BYMONTHDAY=-32", "FREQ=MONTHLY;BYDAY=0MO",
      "FREQ=DAILY;BYSETPOS=367;BYDAY=MO", "FREQ=DAILY;WKST=XX", "FREQ=DAILY;COUNT=+2",
      "FREQ=DAILY;INTERVAL=0", "FREQ=DAILY;COUNT=2147483648", "FREQ=DAILY;BYHOUR=9",
      "FREQ=DAILY;UNTIL=20250103T090001Z", "FREQ=HOURLY", "FREQ=DAILY;",
    ] {
    try @schedule.RRule::parse(text) catch {
      @schedule.InvalidRule(_) => ()
      @schedule.InvalidDate(_) => ()
    } noraise {
      _ => fail("accepted invalid rule: \{text}")
    }
  }
}
