///|
pub enum Frequency {
  Daily
  Weekly
  Monthly
  Yearly
} derive(Eq, Debug)

///|
pub extend Frequency with Eq::{equal, not_equal}

///|
pub extend Frequency with @debug.Debug::{to_repr}

///|
pub struct WeekdaySpec {
  weekday : Int32
  ordinal : Int32?
} derive(Eq, Debug)

///|
pub extend WeekdaySpec with Eq::{equal, not_equal}

///|
pub extend WeekdaySpec with @debug.Debug::{to_repr}

///|
pub struct RRule {
  frequency : Frequency
  interval : Int32
  count : Int32?
  until : DateTime?
  weekdays : Array[WeekdaySpec]
  monthdays : Array[Int32]
  months : Array[Int32]
  week_start : Int32
  positions : Array[Int32]
} derive(Debug)

///|
pub extend RRule with @debug.Debug::{to_repr}

///|
/// Parse the UTC-safe RFC 5545 subset used by MoonSchedule.
pub fn RRule::parse(input : String) -> RRule raise ScheduleError {
  if input.length() > 4096 {
    raise InvalidRule("RRULE input exceeds 4096 code units")
  }
  let mut frequency : Frequency? = None
  let mut interval = 1
  let mut count : Int32? = None
  let mut until : DateTime? = None
  let mut weekdays : Array[WeekdaySpec] = []
  let mut monthdays : Array[Int32] = []
  let mut months : Array[Int32] = []
  let mut week_start = 1
  let mut positions : Array[Int32] = []
  let seen : Array[String] = []
  for raw in input.trim().split(";") {
    let pair = raw.split("=").to_array()
    if pair.length() != 2 {
      raise InvalidRule("RRULE entries need KEY=VALUE")
    }
    let key = pair[0].to_owned().to_upper()
    let value = pair[1].to_owned().to_upper()
    if seen.contains(key) {
      raise InvalidRule("duplicate RRULE key: \{key}")
    }
    seen.push(key)
    match key {
      "FREQ" => frequency = Some(parse_frequency(value))
      "INTERVAL" => interval = positive_number(value, "INTERVAL")
      "COUNT" => count = Some(positive_number(value, "COUNT"))
      "UNTIL" => until = Some(parse_until(value))
      "BYDAY" => weekdays = parse_weekdays(value)
      "BYMONTHDAY" => monthdays = parse_signed_list(value, 31, "BYMONTHDAY")
      "BYMONTH" => months = parse_numbers(value, 1, 12, "BYMONTH")
      "WKST" => week_start = parse_weekday(value)
      "BYSETPOS" => positions = parse_signed_list(value, 366, "BYSETPOS")
      _ => raise InvalidRule("unsupported RRULE key: \{key}")
    }
  }
  let frequency = match frequency {
    Some(value) => value
    None => raise InvalidRule("RRULE requires FREQ")
  }
  if count is Some(_) && until is Some(_) {
    raise InvalidRule("COUNT and UNTIL must not appear together")
  }
  if frequency == Weekly && monthdays.length() > 0 {
    raise InvalidRule("WEEKLY must not use BYMONTHDAY")
  }
  if frequency != Monthly &&
    frequency != Yearly &&
    weekdays.any(day => day.ordinal is Some(_)) {
    raise InvalidRule("ordinal BYDAY requires MONTHLY or YEARLY")
  }
  if positions.length() > 0 &&
    weekdays.length() == 0 &&
    monthdays.length() == 0 &&
    months.length() == 0 {
    raise InvalidRule("BYSETPOS requires another BY rule")
  }
  {
    frequency,
    interval,
    count,
    until,
    weekdays,
    monthdays,
    months,
    week_start,
    positions,
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
    for candidate in self.period_candidates(start, lower, upper) {
      if candidate < start {
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
      let lower = day_index(start) -
        (start.weekday() - self.week_start + 7) % 7 +
        step * 7
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
  if self.weekdays.length() > 0 && !self.matches_weekday(date) {
    return false
  }
  if self.monthdays.length() > 0 &&
    !self.monthdays.any(day => {
      if day > 0 {
        day == date.day
      } else {
        days_in_month(date.year, date.month) + day + 1 == date.day
      }
    }) {
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
fn RRule::period_candidates(
  self : RRule,
  start : DateTime,
  lower : Int32,
  upper : Int32,
) -> Array[DateTime] {
  let candidates : Array[DateTime] = []
  for day = lower; day < upper; day = day + 1 {
    if day >= 0 && day < days_before_year(10000) {
      let date = date_at(day, start.hour, start.minute)
      if self.matches_date(date, start) {
        candidates.push(date)
      }
    }
  }
  if self.positions.length() == 0 {
    return candidates
  }
  let selected : Array[DateTime] = []
  for i, date in candidates {
    if self.positions.contains(i + 1) ||
      self.positions.contains(i - candidates.length()) {
      selected.push(date)
    }
  }
  selected
}

///|
fn RRule::matches_weekday(self : RRule, date : DateTime) -> Bool {
  self.weekdays.any(spec => {
    if spec.weekday != date.weekday() {
      return false
    }
    match spec.ordinal {
      None => true
      Some(n) => {
        let (before, after) = if self.frequency == Yearly &&
          self.months.length() == 0 {
          let offset = day_index(date) - days_before_year(date.year)
          (offset, days_before_year(date.year + 1) - day_index(date) - 1)
        } else {
          (date.day - 1, days_in_month(date.year, date.month) - date.day)
        }
        if n > 0 {
          before / 7 + 1 == n
        } else {
          after / 7 + 1 == -n
        }
      }
    }
  })
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
  if value.length() == 0 || !value.iter().all(c => c >= '0' && c <= '9') {
    raise InvalidRule("\{label} requires ASCII digits")
  }
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
fn parse_weekdays(value : String) -> Array[WeekdaySpec] raise ScheduleError {
  let output : Array[WeekdaySpec] = []
  for item in value.split(",") {
    if item.length() < 2 {
      raise InvalidRule(
        "BYDAY needs a weekday, optionally preceded by an ordinal",
      )
    }
    let weekday = parse_weekday(item[item.length() - 2:].to_owned())
    let ordinal = if item.length() > 2 {
      Some(
        parse_signed_number(item[:item.length() - 2].to_owned(), 53, "BYDAY"),
      )
    } else {
      None
    }
    output.push({ weekday, ordinal, })
  }
  output
}

///|
fn parse_weekday(value : String) -> Int32 raise ScheduleError {
  match value {
    "SU" => 0
    "MO" => 1
    "TU" => 2
    "WE" => 3
    "TH" => 4
    "FR" => 5
    "SA" => 6
    _ => raise InvalidRule("weekday needs SU,MO,TU,WE,TH,FR,SA")
  }
}

///|
fn parse_signed_number(
  value : String,
  maximum : Int32,
  label : String,
) -> Int32 raise ScheduleError {
  let negative = value.has_prefix("-")
  let digits = if negative || value.has_prefix("+") {
    value[1:].to_owned()
  } else {
    value
  }
  let magnitude = positive_number(digits, label)
  if magnitude > maximum {
    raise InvalidRule("\{label} magnitude must be 1..\{maximum}")
  }
  if negative {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn parse_signed_list(
  value : String,
  maximum : Int32,
  label : String,
) -> Array[Int32] raise ScheduleError {
  let output : Array[Int32] = []
  for part in value.split(",") {
    let number = parse_signed_number(part.to_owned(), maximum, label)
    if !output.contains(number) {
      output.push(number)
    }
  }
  output
}

///|
fn parse_until(value : String) -> DateTime raise ScheduleError {
  if value.length() == 16 && value[8] == 'T' && value[15] == 'Z' {
    if value[13:15] != "00" {
      raise InvalidRule(
        "UNTIL seconds must be 00 in the minute-precision subset",
      )
    }
    return DateTime::parse(
      "\{value[0:4]}-\{value[4:6]}-\{value[6:8]}T\{value[9:11]}:\{value[11:13]}Z",
    )
  }
  // Backwards-compatible ISO minute form accepted by the original release.
  DateTime::parse(value)
}
