# MoonSchedule 项目申报材料

> 上游 0.1.0 的历史材料，保留用于来源追溯，不是 Rindoncreate 本次维护贡献的正式申报书。当前生态情况、本次新增范围和归属以 `docs/contribution-plan.md` 为准。

**项目名称：** MoonSchedule

**项目简介：** 面向 MoonBit 的纯实现 UTC 日程规则引擎，统一提供 Cron 与 RFC 5545 RRULE 的解析、匹配、下一次触发计算和区间实例枚举。

**方向与场景：** 补充 MoonBit 在任务调度、CI 定时触发、提醒服务、日历同步和离线 WASM 应用中的基础规则能力。核心库不依赖系统时间或时区数据库，因此四个稳定后端具有一致结果。

**核心功能：** UTC 日期时间模型；五字段 Cron 的范围、列表、步长和别名；RRULE 的频率、间隔、终止条件和常用 BY 过滤；CLI 模拟器；跨后端 CI 与测试。

**实现计划：** 首版完成 Cron/RRULE 可用子集、测试与 Mooncakes 打包；后续增加规则集合、排除/追加日期、更多 RFC 字段、性质测试、时区适配和基准，最终达到约 4k 有效 MoonBit 行。

**交付物：** 公开 GitHub/Gitlink 仓库、Mooncakes 包、MIT 许可证、README、可运行 CLI、CI、测试和发布产物。

**原创说明：** 项目为原创 MoonBit 实现；Cron 与 RFC 5545 是公开互操作规范，不复制其他项目源代码。
