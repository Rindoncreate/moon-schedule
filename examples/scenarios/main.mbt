///|
fn main {
  scenarios() catch {
    @schedule.InvalidDate(message) => abort(message)
    @schedule.InvalidRule(message) => abort(message)
  }
}

///|
fn scenarios() -> Unit raise @schedule.ScheduleError {
  let billing = @schedule.RRule::parse(
    "FREQ=MONTHLY;BYDAY=MO,TU,WE,TH,FR;BYSETPOS=-1;COUNT=3",
  )
  let billing_dates = billing.occurrences_between(
    @schedule.DateTime::parse("2025-01-31T09:00Z"),
    @schedule.DateTime::parse("2025-03-31T09:00Z"),
  )
  println("Billing: \{billing_dates.map(date => date.to_string()).join(", ")}")
  let maintenance = @schedule.RRule::parse(
    "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;WKST=MO;COUNT=4",
  )
  let maintenance_dates = maintenance.occurrences_between(
    @schedule.DateTime::parse("2025-10-20T09:00Z"),
    @schedule.DateTime::parse("2025-11-30T09:00Z"),
  )
  println(
    "Maintenance: \{maintenance_dates.map(date => date.to_string()).join(", ")}",
  )
  let appointments = @schedule.RRule::parse("FREQ=DAILY;COUNT=3")
  let start = @schedule.DateTime::parse("2025-01-01T09:00Z")
  let remaining = appointments.occurrences_window(
    start,
    @schedule.DateTime::parse("2025-01-02T12:00Z"),
    @schedule.DateTime::parse("2025-01-10T09:00Z"),
  )
  println("Appointments: \{remaining.map(date => date.to_string()).join(", ")}")
  println(
    "Exhausted: \{appointments.next_after_from(start, @schedule.DateTime::parse("2025-01-03T09:00Z")) is None}",
  )
}
