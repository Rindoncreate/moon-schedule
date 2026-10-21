///|
pub suberror ScheduleError {
  InvalidDate(String)
  InvalidRule(String)
}

///|
pub struct DateTime {
  year : Int32
  month : Int32
  day : Int32
  hour : Int32
  minute : Int32
} derive(Eq, Compare, Debug)

///|
pub extend DateTime with Eq::{equal, not_equal}

///|
pub extend DateTime with Compare::{compare, op_lt, op_le, op_ge, op_gt}

///|
pub extend DateTime with @debug.Debug::{to_repr}

///|
pub fn is_leap_year(year : Int32) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
pub fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
pub fn DateTime::new(
  year : Int32,
  month : Int32,
  day : Int32,
  hour : Int32,
  minute : Int32,
) -> DateTime raise ScheduleError {
  if year < 1 || year > 9999 {
    raise InvalidDate("year must be 1..9999")
  }
  if month < 1 || month > 12 {
    raise InvalidDate("month must be 1..12")
  }
  if day < 1 || day > days_in_month(year, month) {
    raise InvalidDate("day is outside this month")
  }
  if hour < 0 || hour > 23 || minute < 0 || minute > 59 {
    raise InvalidDate("time must be within 00:00..23:59")
  }
  { year, month, day, hour, minute, }
}

///|
pub fn DateTime::to_string(self : DateTime) -> String {
  "\{pad4(self.year)}-\{pad2(self.month)}-\{pad2(self.day)}T\{pad2(self.hour)}:\{pad2(self.minute)}Z"
}

///|
pub fn DateTime::parse(input : String) -> DateTime raise ScheduleError {
  let text = input.trim().to_owned()
  if text.length() != 17 ||
    text[4] != '-' ||
    text[7] != '-' ||
    text[10] != 'T' ||
    text[13] != ':' ||
    text[16] != 'Z' {
    raise InvalidDate("expected RFC 3339 minute timestamp YYYY-MM-DDTHH:MMZ")
  }
  DateTime::new(
    parse_number(text[0:4], "year"),
    parse_number(text[5:7], "month"),
    parse_number(text[8:10], "day"),
    parse_number(text[11:13], "hour"),
    parse_number(text[14:16], "minute"),
  )
}

///|
pub fn DateTime::add_minutes(self : DateTime, amount : Int32) -> DateTime {
  if amount == 0 {
    self
  } else if amount > 0 {
    let next_minute = self.minute + 1
    if next_minute < 60 {
      { ..self, minute: next_minute, }.add_minutes(amount - 1)
    } else if self.hour < 23 {
      { ..self, hour: self.hour + 1, minute: 0, }.add_minutes(amount - 1)
    } else {
      self.next_day().add_minutes(amount - 1)
    }
  } else {
    let previous_minute = self.minute - 1
    if previous_minute >= 0 {
      { ..self, minute: previous_minute, }.add_minutes(amount + 1)
    } else if self.hour > 0 {
      { ..self, hour: self.hour - 1, minute: 59, }.add_minutes(amount + 1)
    } else {
      self.previous_day().add_minutes(amount + 1)
    }
  }
}

///|
pub fn DateTime::next_day(self : DateTime) -> DateTime {
  if self.day < days_in_month(self.year, self.month) {
    { ..self, day: self.day + 1, hour: 0, minute: 0, }
  } else if self.month < 12 {
    { year: self.year, month: self.month + 1, day: 1, hour: 0, minute: 0, }
  } else {
    { year: self.year + 1, month: 1, day: 1, hour: 0, minute: 0, }
  }
}

///|
fn DateTime::previous_day(self : DateTime) -> DateTime {
  if self.day > 1 {
    { ..self, day: self.day - 1, hour: 23, minute: 59, }
  } else if self.month > 1 {
    let month = self.month - 1
    {
      year: self.year,
      month,
      day: days_in_month(self.year, month),
      hour: 23,
      minute: 59,
    }
  } else {
    { year: self.year - 1, month: 12, day: 31, hour: 23, minute: 59, }
  }
}

///|
pub fn DateTime::weekday(self : DateTime) -> Int32 {
  let mut y = self.year
  let mut m = self.month
  if m < 3 {
    y = y - 1
    m = m + 12
  }
  (self.day + 13 * (m + 1) / 5 + y + y / 4 - y / 100 + y / 400 + 6) % 7
}

///|
fn parse_number(input : StringView, name : String) -> Int32 raise ScheduleError {
  @string.parse_int(input.to_owned()) catch {
    _ => raise InvalidDate("invalid \{name}")
  }
}

///|
fn pad2(value : Int32) -> String {
  if value < 10 {
    "0\{value}"
  } else {
    "\{value}"
  }
}

///|
fn pad4(value : Int32) -> String {
  if value < 10 {
    "000\{value}"
  } else if value < 100 {
    "00\{value}"
  } else if value < 1000 {
    "0\{value}"
  } else {
    "\{value}"
  }
}
