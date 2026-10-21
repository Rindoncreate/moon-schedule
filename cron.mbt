///|
pub struct Cron {
  minutes : Array[Bool]
  hours : Array[Bool]
  days : Array[Bool]
  months : Array[Bool]
  weekdays : Array[Bool]
  days_wildcard : Bool
  weekdays_wildcard : Bool
} derive(Debug)

///|
pub extend Cron with @debug.Debug::{to_repr}

///|
/// Parse a five-field UTC cron expression: minute hour day-of-month month day-of-week.
pub fn Cron::parse(input : String) -> Cron raise ScheduleError {
  let fields = input
    .trim()
    .split(" ")
    .filter(field => field.length() > 0)
    .to_array()
  if fields.length() != 5 {
    raise InvalidRule("cron needs exactly five fields")
  }
  let minutes = parse_field(fields[0], 0, 59, "minute", false)
  let hours = parse_field(fields[1], 0, 23, "hour", false)
  let days = parse_field(fields[2], 1, 31, "day-of-month", false)
  let months = parse_field(fields[3], 1, 12, "month", true)
  let weekdays = parse_field(fields[4], 0, 7, "day-of-week", true)
  {
    minutes,
    hours,
    days,
    months,
    weekdays,
    days_wildcard: fields[2] == "*",
    weekdays_wildcard: fields[4] == "*",
  }
}

///|
pub fn Cron::matches(self : Cron, at : DateTime) -> Bool {
  let weekday = at.weekday()
  let day_matches = self.days[at.day]
  let weekday_matches = self.weekdays[weekday] ||
    (weekday == 0 && self.weekdays[7])
  let calendar_matches = if self.days_wildcard && self.weekdays_wildcard {
    true
  } else if self.days_wildcard {
    weekday_matches
  } else if self.weekdays_wildcard {
    day_matches
  } else {
    day_matches || weekday_matches
  }
  self.minutes[at.minute] &&
  self.hours[at.hour] &&
  self.months[at.month] &&
  calendar_matches
}

///|
/// Return the first matching minute strictly after `after`, searching at most two years.
pub fn Cron::next_after(
  self : Cron,
  after : DateTime,
) -> DateTime raise ScheduleError {
  let mut candidate = after.add_minutes(1)
  for _ in 0..<1_100_000 {
    if self.matches(candidate) {
      return candidate
    }
    candidate = candidate.add_minutes(1)
  }
  raise InvalidRule("cron has no occurrence within two years")
}

///|
fn parse_field(
  input : StringView,
  minimum : Int32,
  maximum : Int32,
  name : String,
  allow_names : Bool,
) -> Array[Bool] raise ScheduleError {
  let output = Array::make(maximum + 1, false)
  for part in input.split(",") {
    parse_part(part.to_owned(), minimum, maximum, name, allow_names, output)
  }
  output
}

///|
fn parse_part(
  input : String,
  minimum : Int32,
  maximum : Int32,
  name : String,
  allow_names : Bool,
  output : Array[Bool],
) -> Unit raise ScheduleError {
  let pieces = input.split("/").to_array()
  if pieces.length() > 2 || pieces[0] == "" {
    raise InvalidRule("invalid \{name} field: \{input}")
  }
  let step = if pieces.length() == 2 {
    let value = cron_value(pieces[1], minimum, maximum, name, allow_names)
    if value < 1 {
      raise InvalidRule("step must be positive")
    }
    value
  } else {
    1
  }
  let range = pieces[0]
  if range == "*" {
    mark_range(output, minimum, maximum, step)
  } else {
    let ends = range.split("-").to_array()
    if ends.length() == 1 {
      let value = cron_value(ends[0], minimum, maximum, name, allow_names)
      mark_range(output, value, value, step)
    } else if ends.length() == 2 {
      let start = cron_value(ends[0], minimum, maximum, name, allow_names)
      let end = cron_value(ends[1], minimum, maximum, name, allow_names)
      if start > end {
        raise InvalidRule("range start exceeds end in \{name}")
      }
      mark_range(output, start, end, step)
    } else {
      raise InvalidRule("invalid range in \{name}")
    }
  }
}

///|
fn mark_range(
  output : Array[Bool],
  start : Int32,
  end : Int32,
  step : Int32,
) -> Unit {
  for value = start; value <= end; value = value + step {
    output[value] = true
  }
}

///|
fn cron_value(
  raw : StringView,
  minimum : Int32,
  maximum : Int32,
  name : String,
  allow_names : Bool,
) -> Int32 raise ScheduleError {
  let upper = raw.to_owned().to_upper()
  let named = if allow_names { cron_name(upper) } else { None }
  let value = match named {
    Some(value) => value
    None =>
      @string.parse_int(upper) catch {
        _ => raise InvalidRule("invalid \{name} value: \{raw}")
      }
  }
  if value < minimum || value > maximum {
    raise InvalidRule("\{name} must be \{minimum}..\{maximum}")
  }
  value
}

///|
fn cron_name(raw : String) -> Int32? {
  match raw {
    "JAN" => Some(1)
    "FEB" => Some(2)
    "MAR" => Some(3)
    "APR" => Some(4)
    "MAY" => Some(5)
    "JUN" => Some(6)
    "JUL" => Some(7)
    "AUG" => Some(8)
    "SEP" => Some(9)
    "OCT" => Some(10)
    "NOV" => Some(11)
    "DEC" => Some(12)
    "SUN" => Some(0)
    "MON" => Some(1)
    "TUE" => Some(2)
    "WED" => Some(3)
    "THU" => Some(4)
    "FRI" => Some(5)
    "SAT" => Some(6)
    _ => None
  }
}
