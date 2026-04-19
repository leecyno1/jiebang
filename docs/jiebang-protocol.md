# 接棒协议

## 1. Goal

让 Claude Code (`cc`)、Codex (`cx`) 和 Antigravity (`ag`) 在同一个项目里切换开发时，可以通过项目内的持久化文件完成上下文接力，而不是依赖任何单一工具的私有会话记忆。

## 2. Core Principle

`CLAUDE.md` 的构建原理适合承载稳定、长期、低频变化的项目规则，不适合承载高频动态进度。并且为了不改动项目原生的 `CLAUDE.md`，本方案把跨代理协议完全外置到项目专有接棒文件。

因此本方案分两层：

1. `skills/jiebang/assets/`
   作为唯一 canonical scaffold source，包含 bootstrap 所需 manifest 和模板。
2. `.jiebang/runtime/`
   作为动态上下文层，保存 handoff、决策、当前任务和各代理会话摘要。

仓库根目录下的 `.jiebang/` 是目标项目生成物，不应作为包的一部分长期版本化。`AGENTS.md` 不是接棒协议的必需依赖。安装或初始化时可以选择写入一小段 hook，方便自动发现；但接棒流程本身必须能在没有 `AGENTS.md` 的项目中运行。

如果目标项目已有 `CLAUDE.md`、`AGENTS.md` 或其他代理配置文件，接棒工具必须默认只读不写。只有用户显式运行 `bootstrap --update-agents` 时，才允许在 `AGENTS.md` 追加带边界标记的 hook 块。不得重写、整理、合并、删除用户已有配置。

## 3. Command Contract

### `接棒cc`

当前代理收到 `接棒cc` 时，必须：

1. 读取 `.jiebang/manifest.yml`
2. 读取 `.jiebang/runtime/project.md`
3. 读取 `.jiebang/runtime/current-task.md`
4. 读取 `.jiebang/runtime/decision-log.md`
5. 优先读取 `.jiebang/runtime/handoffs/cc.md`
6. 若 manual handoff 缺失或明显过期，则回退到 `.jiebang/runtime/handoffs/cc.auto.md`
7. 如有必要，再读取 `.jiebang/runtime/sessions/cc.md`
8. 只有需要项目级规则时，才读取 `AGENTS.md` 或 manifest 声明的项目上下文文件
9. 输出一个简短的“已接棒上下文”摘要，再继续执行用户当前请求

### `接棒cx` / `接棒ag`

与 `接棒cc` 相同，只是把 handoff 来源替换为目标代理。

### `交棒`

当前代理在准备切换前，必须更新自己的 handoff 文件，至少包含：

1. 当前目标
2. 已完成事项
3. 正在进行中的工作
4. 修改过的文件
5. 尚未验证的风险
6. 下一位代理的第一步动作

`交棒` 不需要带后缀，因为它永远表示“当前代理写出自己的状态”。

### 自动交棒

为了降低断网、崩溃、意外退出导致的上下文丢失，建议启用本地自动交棒。

自动交棒分两类：

1. 周期快照
   每隔固定时间把当前代理的状态写入自己的 `.auto.md` handoff 文件。
2. 事件快照
   在检测到任务目标变化、关键决策落地、文件修改列表变化时，立即更新一次 handoff。

自动交棒的最低要求是本地落盘，不依赖远端服务。

## 4. File Responsibilities

| File | Responsibility |
|------|----------------|
| `.jiebang/runtime/project.md` | 项目长期背景、范围、目标 |
| `.jiebang/runtime/current-task.md` | 当前正在做的单一任务及成功标准 |
| `.jiebang/runtime/decision-log.md` | 已冻结的重要决策和约束 |
| `.jiebang/runtime/handoffs/cc.md` | Claude Code 的 authoritative manual handoff |
| `.jiebang/runtime/handoffs/cx.md` | Codex 的 authoritative manual handoff |
| `.jiebang/runtime/handoffs/ag.md` | Antigravity 的 authoritative manual handoff |
| `.jiebang/runtime/handoffs/*.auto.md` | 自动交棒产生的 fallback snapshot |
| `.jiebang/runtime/sessions/*.md` | 各代理更细粒度的工作日志，可选读取 |

## 5. Recommended Workflow

### A. 首次接入

1. 运行 `skills/jiebang/scripts/jiebang.sh bootstrap`
2. 填好 `.jiebang/runtime/project.md`
3. 填好 `.jiebang/runtime/current-task.md`
4. 让当前主力代理写入自己的第一份 handoff 文件

### B. 日常切换

1. 在当前代理中输入 `交棒`
2. 切换到目标代理
3. 输入 `接棒cc` 或对应来源代理命令
4. 目标代理读取 handoff 包并继续

### B1. 自动交棒建议

1. 启动本地守护脚本
2. 以 2-5 分钟周期生成一次 handoff 快照
3. 在 handoff 更新时同时写入 `sessions/{agent}.md` 的时间线
4. 在用户手动执行 `交棒` 时覆盖最新快照，保证摘要质量高于自动快照

可用命令：

```bash
skills/jiebang/scripts/jiebang.sh daemon-start cc 180
skills/jiebang/scripts/jiebang.sh daemon-status
skills/jiebang/scripts/jiebang.sh daemon-stop
```

### C. 发生漂移时

如果三个代理说法不一致，先看 manual handoff；若 manual 明显过期，再参考对应 `.auto.md`。session log 只用于追溯，不作为默认权威来源。

## 6. Important Limitation

任何代理都不能直接读取另一个代理的私有对话历史。

所以“接棒”这件事能否稳定成立，取决于源代理是否把关键进度外化到了 `.jiebang/runtime/`。这也是本方案把动态上下文从原生 `CLAUDE.md` 中剥离出来的根本原因。
