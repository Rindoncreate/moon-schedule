///|
pub enum Frequency {
  Daily
  Weekly
  Monthly
  Yearly
} derive(Eq, Debug)

///|
pub struct RRule {
  frequency : Frequency
  interval : Int
  count : Int?
  until : DateTime?
  weekdays : Array[Int]
  monthdays : Array[Int]
  months : Array[Int]
} derive(Debug)

///| Parse the UTC-safe RFC 5545 subset used by MoonSchedule.
pub fn RRule::parse(input : String) -> RRule raise ScheduleError {
  let mut frequency : Frequency? = None
  let mut interval = 1
  let mut count : Int? = None
  let mut until : DateTime? = None
  let mut weekdays : Array[Int] = []
  let mut monthdays : Array[Int] = []
  let mut months : Array[Int] = []
  for raw in input.trim().split(";") {
    let pair = raw.split("=").to_array()
    if pair.length() != 2 { raise InvalidRule("RRULE entries need KEY=VALUE") }
    let key = pair[0].to_owned().to_upper()
    let value = pair[1].to_owned().to_upper()
    match key {
      "FREQ" => frequency = Some(parse_frequency(value))
      "INTERVAL" => interval = positive_number(value, "INTERVAL")
      "COUNT" => count = Some(positive_number(value, "COUNT"))
      "UNTIL" => until = Some(DateTime::parse(value))
      "BYDAY" => weekdays = parse_weekdays(value)
      "BYMONTHDAY" => monthdays = parse_numbers(value, 1, 31, "BYMONTHDAY")
      "BYMONTH" => months = parse_numbers(value, 1, 12, "BYMONTH")
      _ => raise InvalidRule("unsupported RRULE key: \{key}")
    }
  }
  match frequency {
    Some(frequency) => { frequency, interval, count, until, weekdays, monthdays, months }
    None => raise InvalidRule("RRULE requires FREQ")
  }
}

///| Enumerate occurrences in `[start, end]`; `start` is the recurrence anchor.
pub fn RRule::occurrences_between(
  self : RRule,
  start : DateTime,
  end : DateTime,
) -> Array[DateTime] {
  let output : Array[DateTime] = []
  let mut candidate = start
  let mut emitted = 0
  for _ in 0..<20000 {
    if candidate > end { break }
    if self.until is Some(limit) && candidate > limit { break }
    if self.matches_filters(candidate) {
      output.push(candidate)
      emitted = emitted + 1
      if self.count is Some(limit) && emitted >= limit { break }
    }
    candidate = advance(candidate, self.frequency, self.interval)
  }
  output
}

///|
pub fn RRule::next_after(self : RRule, after : DateTime) -> DateTime? {
  let end = after.add_minutes(1_100_000)
  let values = self.occurrences_between(after.add_minutes(1), end)
  values.get(0)
}

///|
fn RRule::matches_filters(self : RRule, candidate : DateTime) -> Bool {
  (self.weekdays.length() == 0 || self.weekdays.contains(candidate.weekday())) &&
  (self.monthdays.length() == 0 || self.monthdays.contains(candidate.day)) &&
  (self.months.length() == 0 || self.months.contains(candidate.month))
}

///|
fn advance(current : DateTime, frequency : Frequency, interval : Int) -> DateTime {
  match frequency {
    Daily => current.add_minutes(interval * 1440)
    Weekly => current.add_minutes(interval * 10080)
    Monthly => add_months(current, interval)
    Yearly => add_months(current, interval * 12)
  }
}

///|
fn add_months(current : DateTime, amount : Int) -> DateTime {
  let raw = (current.year * 12 + current.month - 1) + amount
  let year = raw / 12
  let month = raw % 12 + 1
  let day = if current.day > days_in_month(year, month) { days_in_month(year, month) } else { current.day }
  { year, month, day, hour: current.hour, minute: current.minute }
}

///|
fn parse_frequency(value : String) -> Frequency raise ScheduleError {
  match value {
    "DAILY" => Daily
    "WEEKLY" => Weekly
    "MONTHLY" => Monthly
    "YEARLY" => Yearly
    _ => raise InvalidRule("unsupported FREQ: \{value}")
  }
}

///|
fn positive_number(value : String, label : String) -> Int raise ScheduleError {
  let result = @string.parse_int(value) catch { _ => raise InvalidRule("\{label} must be a number") }
  if result < 1 { raise InvalidRule("\{label} must be positive") }
  result
}

///|
fn parse_numbers(value : String, minimum : Int, maximum : Int, label : String) -> Array[Int] raise ScheduleError {
  let output : Array[Int] = []
  for item in value.split(",") {
    let number = positive_number(item.to_owned(), label)
    if number < minimum || number > maximum { raise InvalidRule("\{label} value is out of range") }
    output.push(number)
  }
  output
}

///|
fn parse_weekdays(value : String) -> Array[Int] raise ScheduleError {
  let output : Array[Int] = []
  for item in value.split(",") {
    let weekday = match item.to_owned().to_upper() {
      "SU" => 0
      "MO" => 1
      "TU" => 2
      "WE" => 3
      "TH" => 4
      "FR" => 5
      "SA" => 6
      _ => raise InvalidRule("BYDAY needs SU,MO,TU,WE,TH,FR,SA")
    }
    output.push(weekday)
  }
  output
}
