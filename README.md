# MoonSchedule — UTC 重复日程计算兼容性维护

本分支是对 [100kkk/moon-schedule](https://github.com/100kkk/moon-schedule) 的维护贡献，基线为 `1d35dc9f150f9cb8f4f891f7ac98a284621afdc1`。上游作者为 100kkk，本次维护贡献者为 Rindoncreate（使用 AI 辅助）。保留原 MIT 许可与开发历史，不将上游成果申报为本次新增工作。

**0.2.0 为拟议、尚未发布的兼容性更新。** Mooncakes 已有的 0.1.0 不包含这些修复；上游合并、正式发布和赛事审核须另行确认。本次是已有生态项目维护，不声称日程引擎是生态空白。

## 解决的问题

日历、定时任务和预约服务需要稳定的重复日期计算。原实现存在月末／闰日被挪到其他日期、BY 规则只过滤而不展开，以及查询时 DTSTART/COUNT 丢失的问题。新的实现按频率周期展开候选日期，再应用过滤、BYSETPOS 和查询边界。

- 支持 DAILY、WEEKLY、MONTHLY、YEARLY，以及 INTERVAL、COUNT、UNTIL。
- 支持 BYMONTH、正负 BYMONTHDAY、普通／序号 BYDAY、WKST 和 BYSETPOS。
- 明确区分原始 DTSTART 与查询窗口；COUNT 包含窗口前已经发生的实例。
- 对重复字段、矛盾规则、未知字段和资源预算耗尽显式报错。
- 日期运算采用有界公历日序号，避免逐分钟递归。

## 边界与迁移

核心是纯 MoonBit，无浏览器、系统时钟或网络依赖，限定 UTC、分钟精度、年份 1..9999。**不是完整 RFC 5545 实现**，不支持时区/DST、秒级规则、BYWEEKNO、BYYEARDAY、EXDATE/RDATE 或完整 ICS 文件。

月末行为有意改变：1 月 31 日的每月规则应跳过无效月份，不挪到 2 月末。查询和日期运算现在可能抛出 `ScheduleError`。旧 `next_after(after)` 已弃用，改用 `next_after_from(dtstart, after)`。详见 [语义与迁移说明](docs/compatibility.md)。

## 从本地源码运行

需要 MoonBit CLI、Node.js；独立参考验证另需 Python 3.12。当前本地验证的编译器为 v0.10.15。

```sh
moon check --target js --deny-warn
moon test --target js --deny-warn
moon run examples/scenarios --target js
moon run cmd/main --target js -- next 'rrule:FREQ=DAILY;COUNT=3' '2025-01-01T09:00Z' '2025-01-02T10:00Z' 4
```

最后一条命令只输出 `2025-01-03T09:00Z`，不会因查询日期改变而重新计算三次。

三个场景共用同一核心：[月末结算、隔周巡检、有限次数预约](examples/scenarios/main.mbt)。运行输出包含：

```text
Billing: 2025-01-31T09:00Z, 2025-02-28T09:00Z, 2025-03-31T09:00Z
Maintenance: 2025-10-20T09:00Z, 2025-10-23T09:00Z, 2025-11-03T09:00Z, 2025-11-06T09:00Z
Appointments: 2025-01-03T09:00Z
Exhausted: true
```

## 命令行

所有时间均使用 `YYYY-MM-DDTHH:MMZ`，含空格或分号的规则须加引号。

```text
parse cron:<five fields> | rrule:<rule>
next cron:<five fields> <after> <amount>
next rrule:<rule> <DTSTART> <after> <amount>
between rrule:<rule> <DTSTART> <end>
window rrule:<rule> <DTSTART> <from> <end>
```

`between` 以第一个日期作为 DTSTART；移动窗口必须使用 `window` 保留原起点。无效输入返回非零退出状态。

## 验证

```sh
python -m pip install -r scripts/requirements-oracle.txt
node scripts/verify.mjs
```

验证脚本检查格式、独立参考向量、JS/Wasm/Wasm GC 的 check/build/test、示例精确输出、CLI 正常与错误路径以及源码打包。Linux CI 额外启用 native。可通过进程环境 `PYTHON` 和 `MOON` 指定可执行文件路径。

当前共有 234 项 MoonBit 测试，其中 200 项由固定版本 python-dateutil 和 Python datetime 独立生成。Python 只用于开发验证，未复制其实现源码。CI 会重新生成向量并检查差异；测试生成代码不算作手写生产代码规模。[详细验收记录](docs/verification.md)。

## 本次贡献与参考

- [维护范围、基线、归属与赛事定位](docs/contribution-plan.md)
- [RFC 5545 规则定义](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.3.10)
- [公开规则示例](https://www.rfc-editor.org/rfc/rfc5545.html#section-3.8.5.3)
- [python-dateutil](https://github.com/dateutil/dateutil)：仅作独立测试参考，不作为生产依赖。
- 原项目 MIT 许可证见 [LICENSE](LICENSE)。本分支的技术文档和代码含 AI 辅助，不是参赛者的人工正式申报书。
