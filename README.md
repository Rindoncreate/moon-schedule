# MoonSchedule

MoonSchedule 是一个纯 MoonBit 的确定性 UTC 日程规则引擎。它覆盖五字段 Cron 与 RFC 5545 RRULE 的实用子集，可用于跨 `wasm`、`wasm-gc`、`js`、`native` 后端计算下一次触发时间或一个时间区间内的复发实例。

## 为什么需要它

MoonBit 已有日期时间实现，但面向工程定时（Cron）与可互操作日历复发规则（RRULE）的纯 MoonBit 规则引擎仍是生态空缺。MoonSchedule 不读取系统时间、不做时区或 DST 猜测；同一输入在每个后端都会得到相同 UTC 结果。

## 安装

发布后：

```bash
moon add 100kkk/moon-schedule
```

本地开发：

```bash
moon check --target all --deny-warn
moon test --target all --deny-warn
```

## 功能范围

- `DateTime`：带分钟精度的 UTC RFC 3339 时间、闰年/月末/星期计算。
- `Cron`：`*`、列表、范围、步长、月份和星期英文别名；遵循传统 Cron 的 DOM/DOW OR 语义。
- `RRule`：`FREQ`（DAILY/WEEKLY/MONTHLY/YEARLY）、`INTERVAL`、`COUNT`、`UNTIL`、`BYDAY`、`BYMONTHDAY`、`BYMONTH`。
- CLI：解析、下一次触发模拟、区间枚举。

首版明确不支持时区、DST、秒字段、`BYSETPOS`、`EXDATE` 和完整 iCalendar 文档；它们是后续 4k 行规模路线图中的独立功能。

## API 示例

```mbt nocheck
let cron = @schedule.Cron::parse("*/15 9-17 * * MON-FRI")
let after = @schedule.DateTime::parse("2025-01-06T09:01Z")
let next = cron.next_after(after)
// 2025-01-06T09:15Z

let rule = @schedule.RRule::parse("FREQ=DAILY;COUNT=3")
let start = @schedule.DateTime::parse("2025-01-01T09:00Z")
let end = @schedule.DateTime::parse("2025-01-05T09:00Z")
let occurrences = rule.occurrences_between(start, end)
```

## CLI

PowerShell 中请将包含空格或分号的规则整体加引号：

```powershell
moon run cmd/main -- parse 'cron:*/15 9-17 * * MON-FRI'
moon run cmd/main -- next 'cron:0 0 1 JAN *' '2024-12-31T23:59Z' 2
moon run cmd/main -- between 'rrule:FREQ=DAILY;COUNT=3' '2025-01-01T09:00Z' '2025-01-05T09:00Z'
```

## 质量与发布

CI 对四个稳定后端执行检查、构建、格式检查、接口生成、测试和 `moon package`。项目采用 [MIT](LICENSE) 许可证。发布前运行：

```bash
moon check --target all --deny-warn
moon build --target all --deny-warn
moon fmt --check
moon info
git diff --exit-code
moon test --target all --deny-warn
moon package
```

## 路线图

1. 规则集合、`EXDATE`/`RDATE` 与人类可读描述。
2. RFC 5545 更多 `BY*` 字段与性质测试。
3. 时区适配层、DST 策略与性能基准。

## 许可证

MIT。
