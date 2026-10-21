///|
suberror CliError {
  InvalidArguments(String)
}

///|
fn main {
  run(@env.args()) catch {
    @schedule.InvalidDate(message) => abort("invalid date: \{message}")
    @schedule.InvalidRule(message) => abort("invalid rule: \{message}")
    InvalidArguments(message) => abort("invalid arguments: \{message}")
    _ => abort("unexpected command error")
  }
}

///|
fn run(args : Array[String]) -> Unit raise {
  if args.length() < 2 || args[1] == "help" || args[1] == "--help" {
    print_usage()
    return
  }
  if args.length() < 3 {
    raise InvalidArguments("missing rule; use help")
  }
  match args[1] {
    "parse" => {
      if args.length() != 3 {
        raise InvalidArguments("parse requires one rule")
      }
      let (kind, expression) = split_spec(args[2])
      match kind {
        "cron" => ignore(@schedule.Cron::parse(expression))
        "rrule" => ignore(@schedule.RRule::parse(expression))
        _ => raise InvalidArguments("expected cron: or rrule: prefix")
      }
      println("valid \{kind}: \{expression}")
    }
    "next" => next_command(args)
    "between" => between_command(args)
    "window" => window_command(args)
    _ => raise InvalidArguments("unknown command; use help")
  }
}

///|
fn next_command(args : Array[String]) -> Unit raise {
  let (kind, expression) = split_spec(args[2])
  match kind {
    "cron" => {
      if args.length() != 5 {
        raise InvalidArguments("next cron requires after and amount")
      }
      let cron = @schedule.Cron::parse(expression)
      let mut current = @schedule.DateTime::parse(args[3])
      let amount = parse_amount(args[4])
      for _ in 0..<amount {
        current = cron.next_after(current)
        println(current.to_string())
      }
    }
    "rrule" => {
      if args.length() != 6 {
        raise InvalidArguments("next rrule requires DTSTART, after, and amount")
      }
      let rule = @schedule.RRule::parse(expression)
      let start = @schedule.DateTime::parse(args[3])
      let mut current = @schedule.DateTime::parse(args[4])
      let amount = parse_amount(args[5])
      for _ in 0..<amount {
        match rule.next_after_from(start, current) {
          Some(next) => {
            println(next.to_string())
            current = next
          }
          None => return
        }
      }
    }
    _ => raise InvalidArguments("expected cron: or rrule: prefix")
  }
}

///|
fn between_command(args : Array[String]) -> Unit raise {
  if args.length() != 5 {
    raise InvalidArguments("between requires start and end")
  }
  let (kind, expression) = split_spec(args[2])
  let start = @schedule.DateTime::parse(args[3])
  let end = @schedule.DateTime::parse(args[4])
  match kind {
    "rrule" => {
      let rule = @schedule.RRule::parse(expression)
      for occurrence in rule.occurrences_between(start, end) {
        println(occurrence.to_string())
      }
    }
    "cron" => {
      if start > end {
        return
      }
      let cron = @schedule.Cron::parse(expression)
      let mut current = start
      let mut emitted = 0
      if cron.matches(start) {
        println(start.to_string())
        emitted = 1
      }
      while current < end {
        let next = cron.next_after(current)
        if next > end {
          return
        }
        if emitted >= 10000 {
          raise InvalidArguments("cron result budget exceeded")
        }
        println(next.to_string())
        current = next
        emitted = emitted + 1
      }
    }
    _ => raise InvalidArguments("expected cron: or rrule: prefix")
  }
}

///|
fn window_command(args : Array[String]) -> Unit raise {
  if args.length() != 6 {
    raise InvalidArguments("window requires DTSTART, from, and end")
  }
  let (kind, expression) = split_spec(args[2])
  if kind != "rrule" {
    raise InvalidArguments("window requires rrule:")
  }
  let rule = @schedule.RRule::parse(expression)
  let values = rule.occurrences_window(
    @schedule.DateTime::parse(args[3]),
    @schedule.DateTime::parse(args[4]),
    @schedule.DateTime::parse(args[5]),
  )
  for value in values {
    println(value.to_string())
  }
}

///|
fn parse_amount(value : String) -> Int32 raise {
  let amount = @string.parse_int(value) catch {
    _ => raise InvalidArguments("amount must be an integer")
  }
  if amount < 1 || amount > 10000 {
    raise InvalidArguments("amount must be 1..10000")
  }
  amount
}

///|
fn split_spec(input : String) -> (String, String) {
  match input.split(":").to_array() {
    [kind, .. rest] if rest.length() > 0 =>
      (kind.to_owned().to_lower(), rest.join(":"))
    _ => ("", input)
  }
}

///|
fn print_usage() -> Unit {
  println("MoonSchedule UTC simulator (minute precision)")
  println("  parse cron:<five fields> | rrule:<rule>")
  println("  next cron:<five fields> <after> <amount>")
  println("  next rrule:<rule> <DTSTART> <after> <amount>")
  println("  between rrule:<rule> <DTSTART> <end>")
  println("  window rrule:<rule> <DTSTART> <from> <end>")
  println(
    "  timestamps: YYYY-MM-DDTHH:MMZ; quote rules containing spaces or semicolons",
  )
}
