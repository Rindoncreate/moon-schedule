///|
fn main {
  run(@env.args()) catch {
    _ => {
      println("error: invalid schedule input")
      print_usage()
    }
  }
}

///|
fn run(args : Array[String]) -> Unit raise @schedule.ScheduleError {
  if args.length() < 3 {
    print_usage()
    return
  }
  match args[1] {
    "parse" => parse_command(args)
    "next" => next_command(args)
    "between" => between_command(args)
    _ => print_usage()
  }
}

///|
fn parse_command(args : Array[String]) -> Unit raise @schedule.ScheduleError {
  let (kind, expression) = split_spec(args[2])
  match kind {
    "cron" => {
      ignore(@schedule.Cron::parse(expression))
      println("valid cron: \{expression}")
    }
    "rrule" => {
      ignore(@schedule.RRule::parse(expression))
      println("valid rrule: \{expression}")
    }
    _ => print_usage()
  }
}

///|
fn next_command(args : Array[String]) -> Unit raise @schedule.ScheduleError {
  if args.length() != 5 {
    print_usage()
    return
  }
  let (kind, expression) = split_spec(args[2])
  let after = @schedule.DateTime::parse(args[3])
  let amount = @string.parse_int(args[4]) catch { _ => 0 }
  if amount < 1 {
    println("amount must be positive")
    return
  }
  match kind {
    "cron" => {
      let cron = @schedule.Cron::parse(expression)
      let mut current = after
      for _ in 0..<amount {
        current = cron.next_after(current)
        println(current.to_string())
      }
    }
    "rrule" => {
      let rule = @schedule.RRule::parse(expression)
      let mut current = after
      for _ in 0..<amount {
        match rule.next_after(current) {
          Some(next) => {
            println(next.to_string())
            current = next
          }
          None => return
        }
      }
    }
    _ => print_usage()
  }
}

///|
fn between_command(args : Array[String]) -> Unit raise @schedule.ScheduleError {
  if args.length() != 5 {
    print_usage()
    return
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
      let cron = @schedule.Cron::parse(expression)
      let mut current = start.add_minutes(-1)
      for _ in 0..<1_100_000 {
        let next = cron.next_after(current)
        if next > end {
          return
        }
        println(next.to_string())
        current = next
      }
    }
    _ => print_usage()
  }
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
  println("MoonSchedule UTC simulator")
  println("  moon run cmd/main -- parse cron:<five fields>")
  println(
    "  moon run cmd/main -- next cron:<five fields> <YYYY-MM-DDTHH:MMZ> <amount>",
  )
  println("  moon run cmd/main -- between rrule:<rule> <start> <end>")
}
