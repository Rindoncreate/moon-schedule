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
  interval : Int32
  count : Int32?
  until : DateTime?
  weekdays : Array[Int32]
  monthdays : Array[Int32]
  months : Array[Int32]
} derive(Debug)

///|
/// Parse the UTC-safe RFC 5545 subset used by MoonSchedule.
pub fn RRule::parse(input : String) -> RRule raise ScheduleError {
  let mut frequency : Frequency? = None
  let mut interval = 1
  let mut count : Int32? = None
  let mut until : DateTime? = None
  let mut weekdays : Array[Int32] = []
  let mut monthdays : Array[Int32] = []
  let mut months : Array[Int32] = []
  for raw in input.trim().split(";") {
    let pair = raw.split("=").to_array()
    if pair.length() != 2 {
      raise InvalidRule("RRULE entries need KEY=VALUE")
    }
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
    Some(frequency) =>
      { frequency, interval, count, until, weekdays, monthdays, months, }
    None => raise InvalidRule("RRULE requires FREQ")
  }
}

///|
/// Enumerate occurrences in `[start, end]`; `start` is the recurrence anchor.
pub fn RRule::occurrences_between(
  self : RRule,
  start : DateTime,
  end : DateTime,
) -> Array[DateTime] raise ScheduleError {
  self.occurrences_window(start, start, end)
}

///|
/// Keep DTSTART independent from the query window. COUNT includes earlier occurrences.
/// Limits raise InvalidRule rather than returning an incomplete recurrence set.
pub fn RRule::occurrences_window(
  self : RRule,
  start : DateTime,
  from : DateTime,
  end : DateTime,
  period_limit~ : Int32 = 20000,
  result_limit~ : Int32 = 10000,
) -> Array[DateTime] raise ScheduleError {
  self.collect(start, from, end, false, period_limit, result_limit)
}

///|
/// The first occurrence strictly after `after`, preserving DTSTART and global COUNT.
pub fn RRule::next_after_from(
  self : RRule,
  start : DateTime,
  after : DateTime,
  period_limit~ : Int32 = 20000,
) -> DateTime? raise ScheduleError {
  if after >= DateTime::new(9999, 12, 31, 23, 59) {
    return None
  }
  self
  .collect(
    start,
    after.add_minutes(1),
    DateTime::new(9999, 12, 31, 23, 59),
    true,
    period_limit,
    1,
  )
  .get(0)
}

///|
#deprecated("Use next_after_from(dtstart, after) to retain DTSTART and COUNT")
pub fn RRule::next_after(
  self : RRule,
  after : DateTime,
) -> DateTime? raise ScheduleError {
  self.next_after_from(after, after)
}

///|
fn RRule::collect(
  self : RRule,
  start : DateTime,
  from : DateTime,
  end : DateTime,
  first_only : Bool,
  period_limit : Int32,
  result_limit : Int32,
) -> Array[DateTime] raise ScheduleError {
  for date in [start, from, end] {
    ignore(
      DateTime::new(date.year, date.month, date.day, date.hour, date.minute),
    )
  }
  if period_limit < 1 ||
    period_limit > 1000000 ||
    result_limit < 1 ||
    result_limit > 1000000 {
    raise InvalidRule("query limits must be within 1..1000000")
  }
  let output : Array[DateTime] = []
  let stop = match self.until {
    Some(until) if until < end => until
    _ => end
  }
  if from > stop || start > stop {
    return output
  }
  let mut emitted = 0
  let mut period = 0
  while true {
    let (lower, upper) = match self.period_range(start, period) {
      Some(range) => range
      None => return output
    }
    if lower > day_index(stop) {
      return output
    }
    if period >= period_limit {
      raise InvalidRule(
        "recurrence period budget exhausted; narrow the window or raise period_limit",
      )
    }
    for day = lower; day < upper; day = day + 1 {
      if day < 0 || day >= days_before_year(10000) {
        continue
      }
      let candidate = date_at(day, start.hour, start.minute)
      if !self.matches_date(candidate, start) || candidate < start {
        continue
      }
      if candidate > stop {
        return output
      }
      if self.count is Some(count) && emitted >= count {
        return output
      }
      emitted = emitted + 1
      if candidate >= from {
        if output.length() >= result_limit {
          raise InvalidRule(
            "recurrence result budget exhausted; narrow the window or raise result_limit",
          )
        }
        output.push(candidate)
        if first_only {
          return output
        }
      }
    }
    // COUNT must terminate even when the next period contains no matching dates.
    if self.count is Some(count) && emitted >= count {
      return output
    }
    period = period + 1
  } nobreak {
    output
  }
}

///|
fn RRule::period_range(
  self : RRule,
  start : DateTime,
  period : Int32,
) -> (Int32, Int32)? {
  let step = period.to_int64() * self.interval.to_int64()
  // No valid supported recurrence can move more than the entire calendar domain.
  if step > 3660000 {
    return None
  }
  let step = step.to_int()
  match self.frequency {
    Daily => {
      let lower = day_index(start) + step
      if lower >= days_before_year(10000) {
        None
      } else {
        Some((lower, lower + 1))
      }
    }
    Weekly => {
      let lower = day_index(start) - (start.weekday() + 6) % 7 + step * 7
      if lower >= days_before_year(10000) {
        None
      } else {
        Some((lower, lower + 7))
      }
    }
    Monthly => {
      let month_index = (start.year - 1) * 12 + start.month - 1 + step
      if month_index >= 9999 * 12 {
        None
      } else {
        let year = month_index / 12 + 1
        let month = month_index % 12 + 1
        let lower = month_start(year, month)
        Some((lower, lower + days_in_month(year, month)))
      }
    }
    Yearly => {
      let year = start.year + step
      if year > 9999 {
        None
      } else {
        Some((days_before_year(year), days_before_year(year + 1)))
      }
    }
  }
}

///|
fn RRule::matches_date(self : RRule, date : DateTime, start : DateTime) -> Bool {
  if self.months.length() > 0 && !self.months.contains(date.month) {
    return false
  }
  if self.weekdays.length() > 0 && !self.weekdays.contains(date.weekday()) {
    return false
  }
  if self.monthdays.length() > 0 && !self.monthdays.contains(date.day) {
    return false
  }
  match self.frequency {
    Daily => true
    Weekly => self.weekdays.length() > 0 || date.weekday() == start.weekday()
    Monthly =>
      self.weekdays.length() > 0 ||
      self.monthdays.length() > 0 ||
      date.day == start.day
    Yearly =>
      if self.weekdays.length() > 0 || self.monthdays.length() > 0 {
        true
      } else {
        date.day == start.day &&
        (self.months.length() > 0 || date.month == start.month)
      }
  }
}

///|
fn days_before_year(year : Int32) -> Int32 {
  let y = year - 1
  y * 365 + y / 4 - y / 100 + y / 400
}

///|
fn month_start(year : Int32, month : Int32) -> Int32 {
  let mut day = days_before_year(year)
  for m in 1..<month {
    day = day + days_in_month(year, m)
  }
  day
}

///|
fn day_index(date : DateTime) -> Int32 {
  month_start(date.year, date.month) + date.day - 1
}

///|
fn date_at(day : Int32, hour : Int32, minute : Int32) -> DateTime {
  let mut low = 1
  let mut high = 10000
  while low + 1 < high {
    let mid = (low + high) / 2
    if days_before_year(mid) <= day {
      low = mid
    } else {
      high = mid
    }
  }
  let mut remaining = day - days_before_year(low)
  let mut month = 1
  while remaining >= days_in_month(low, month) {
    remaining = remaining - days_in_month(low, month)
    month = month + 1
  }
  { year: low, month, day: remaining + 1, hour, minute, }
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
fn positive_number(value : String, label : String) -> Int32 raise ScheduleError {
  let result = @string.parse_int(value) catch {
    _ => raise InvalidRule("\{label} must be a number")
  }
  if result < 1 {
    raise InvalidRule("\{label} must be positive")
  }
  result
}

///|
fn parse_numbers(
  value : String,
  minimum : Int32,
  maximum : Int32,
  label : String,
) -> Array[Int32] raise ScheduleError {
  let output : Array[Int32] = []
  for item in value.split(",") {
    let number = positive_number(item.to_owned(), label)
    if number < minimum || number > maximum {
      raise InvalidRule("\{label} value is out of range")
    }
    output.push(number)
  }
  output
}

///|
fn parse_weekdays(value : String) -> Array[Int32] raise ScheduleError {
  let output : Array[Int32] = []
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
