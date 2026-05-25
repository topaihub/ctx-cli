# Context Manager — AI Agent 持久化记忆系统

## 问题

AI Agent 会话结束后上下文丢失。新会话需要重新解释项目背景、已做决策、当前进度。浪费时间且容易遗漏。

## 解决方案

一个 CLI 工具 `ctx`，配合 Skill 文件，让 AI Agent 在会话间持久化和恢复上下文。数据存本地 SQLite。

## 核心流程

```
会话开始：AI 执行 ctx load <project> → 读取上下文 → 知道从哪继续
会话中：AI 执行 ctx append <project> --decision "..." → 实时记录关键决策
会话结束：AI 执行 ctx save <project> --summary "..." → 保存当前状态
新会话：AI 执行 ctx load <project> → 无缝继续
```

## 技术栈

- 语言：Python（和 msgflow scripts 统一）
- 存储：SQLite（本地文件 `~/.ctx/contexts.db`）
- 接口：CLI（argparse）
- 集成：Skill 文件（SKILL.md）让 AI Agent 知道何时/如何调用

## CLI 命令设计

### ctx init

初始化数据库（首次使用自动执行）。

```bash
ctx init
# 创建 ~/.ctx/contexts.db
```

### ctx save \<project\>

保存或更新项目上下文。

```bash
ctx save "msgflow重构" \
  --summary "Phase 0-2 完成，Worker 已部署，Astro 骨架搭好" \
  --pending "Phase 3 主题迁移, Phase 4 AI改写" \
  --files "worker-v2/src/**, site/src/**"
```

参数：
- `project`（必填）：项目名称，作为唯一标识
- `--summary`（必填）：当前状态一句话描述
- `--pending`：待做事项，逗号分隔
- `--files`：涉及的关键文件路径，逗号分隔
- `--decisions`：本次会话的关键决策，逗号分隔

### ctx load \<project\>

读取项目上下文，输出结构化文本供 AI 阅读。

```bash
ctx load "msgflow重构"
```

输出格式：

```
# 项目上下文：msgflow重构

## 当前状态
Phase 0-2 完成，Worker 已部署，Astro 骨架搭好

## 关键决策
1. [2026-05-22] 技术栈：TS + Mustache + daisyUI + HTMX（对齐 wucurcheck）
2. [2026-05-22] 存储：KV + D1 + R2 三层
3. [2026-05-22] 前端展示：Astro（非 Hugo），因为 AI 写 TSX 质量更高
4. [2026-05-22] 图片：Telegram 永久存储 + R2 缓存层
5. [2026-05-22] 部署：Cloudflare Pages（主）+ GitHub Pages（备）

## 已完成
- Phase 0: 项目骨架 + D1/R2/KV
- Phase 1: 抓取能力（5 fetcher + 3 repo + handlers + UI）
- Phase 2: GitHub/GitLab Actions + callback + 一次性 token
- Phase 5: Telegram + 飞书 webhook
- Astro 展示站骨架
- 认证（密码 + Google OAuth）
- turndown 清洗

## 待做
- Phase 3 主题迁移（hugo-theme-paper → Astro）
- Phase 4 AI 改写（NullClaw 集成）
- Phase 6 发布能力
- Phase 7 知识库

## 关键文件
- worker-v2/src/** — Worker 核心代码
- worker-v2/AGENTS.md — 编码规范
- site/src/** — Astro 展示站
- scripts/lib/** — Python 接口 + 注册表
- docs/redesign-v2.md — 设计文档

## 最近变更
- [2026-05-22 16:00] 加入 Python Protocol + 装饰器注册表模式
- [2026-05-22 15:50] Telegram/飞书 webhook 迁移完成
- [2026-05-22 15:30] Google OAuth 接入

## 备注
- 旧版 worker/ 目录保留做参考，不再修改
- 所有 Python 代码遵循 Protocol 接口 + 装饰器注册
- Worker 能做的不推给 Actions
```

### ctx list

列出所有项目。

```bash
ctx list
```

输出：

```
项目                 最后更新          状态摘要
msgflow重构          2026-05-22 16:00  Phase 0-2 完成，Worker 已部署
hugo-theme-paper     2026-05-20 14:00  SEO 优化完成，待发布
wucurcheck           2026-05-21 12:00  v4.1 注册功能开发中
```

### ctx append \<project\>

追加一条记录（不覆盖，增量添加）。

```bash
# 追加决策
ctx append "msgflow重构" --decision "浏览器插件作为增值服务方向"

# 追加进度
ctx append "msgflow重构" --progress "Phase 5 Telegram/飞书 webhook 完成"

# 追加备注
ctx append "msgflow重构" --note "Prettier WASM 版本出来后可以消除 Actions 依赖"

# 追加待做
ctx append "msgflow重构" --pending "实现 /api/ci-download 端点"
```

### ctx delete \<project\>

删除项目上下文。

```bash
ctx delete "msgflow重构"
```

### ctx export \<project\>

导出为 Markdown 文件（可提交到 Git）。

```bash
ctx export "msgflow重构" > .ctx/msgflow重构.md
```

### ctx search \<keyword\>

跨项目搜索上下文。

```bash
ctx search "daisyUI"
# 在所有项目的决策/备注/摘要中搜索
```

## SQLite Schema

```sql
-- 数据库位置：~/.ctx/contexts.db
-- 初始化时执行以下 PRAGMA
PRAGMA journal_mode=WAL;          -- 并发读不阻塞写
PRAGMA foreign_keys=ON;           -- 外键约束生效
PRAGMA user_version=1;            -- Schema 版本（用于未来迁移）

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,                -- 项目名（如 "msgflow重构"），也是唯一标识
  summary TEXT NOT NULL DEFAULT '',   -- 当前状态一句话
  pending TEXT DEFAULT '[]',          -- JSON array: 待做事项
  files TEXT DEFAULT '[]',            -- JSON array: 关键文件路径
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS entries (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),  -- UUID，方便跨设备同步
  project_id TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('decision', 'progress', 'note', 'pending')),
  content TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- 索引：只建查询用到的
CREATE INDEX IF NOT EXISTS idx_entries_project ON entries(project_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_entries_type ON entries(project_id, type);

-- FTS5 全文搜索（独立虚拟表，不和主表混）
CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
  content,
  content=entries,
  content_rowid=rowid,
  tokenize='unicode61'
);

-- FTS 同步触发器（主表增删时自动更新 FTS 索引）
CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
  INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
END;

CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
  INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
END;

CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
  INSERT INTO entries_fts(entries_fts, rowid, content) VALUES('delete', old.rowid, old.content);
  INSERT INTO entries_fts(rowid, content) VALUES (new.rowid, new.content);
END;
```

### SQLite 最佳实践说明

| 实践 | 本方案的做法 |
|------|------------|
| WAL 模式 | 开启，CLI 和其他进程可以同时读 |
| 外键约束 | 开启，删除 project 自动级联删除 entries |
| 时间格式 | ISO 8601 UTC（`strftime('%Y-%m-%dT%H:%M:%SZ')`） |
| ID 策略 | TEXT UUID（不用自增，方便未来跨设备同步） |
| FTS 同步 | 触发器自动维护，不需要手动 rebuild |
| Schema 版本 | `user_version` pragma，未来加字段时做迁移判断 |
| CHECK 约束 | `type` 字段限制合法值 |
| 单文件 | 一个 `~/.ctx/contexts.db` 管所有项目 |

## Skill 文件

放在 `~/.kiro/skills/context-manager/SKILL.md`（或对应 Agent 的 skill 目录）：

```markdown
---
name: context-manager
description: |
  AI Agent 持久化记忆系统。每次会话开始时 load 上下文，结束前 save 上下文。
  确保跨会话的项目进度、决策、待做事项不丢失。
  触发词：读取上下文、保存上下文、继续项目、ctx。
---

# Context Manager

## 何时使用

1. **会话开始时**：如果用户提到一个项目名，先执行 `ctx load <项目名>` 读取上下文
2. **做出关键决策时**：执行 `ctx append <项目名> --decision "决策内容"`
3. **完成一个任务时**：执行 `ctx append <项目名> --progress "完成内容"`
4. **会话结束前**：执行 `ctx save <项目名> --summary "当前状态"`
5. **用户说「继续」时**：执行 `ctx load <项目名>` 恢复上下文

## 命令

```bash
ctx load <project>                          # 读取上下文（会话开始）
ctx save <project> --summary "..."          # 保存上下文（会话结束）
ctx append <project> --decision "..."       # 追加决策
ctx append <project> --progress "..."       # 追加进度
ctx append <project> --note "..."           # 追加备注
ctx append <project> --pending "..."        # 追加待做
ctx list                                    # 列出所有项目
ctx search <keyword>                        # 搜索
```

## 规则

- load 输出的内容直接作为当前会话的背景知识
- 不要让用户重复解释已经在上下文里的信息
- 每次会话至少 save 一次（结束前）
- 关键决策必须实时 append，不要等到会话结束
- summary 要简洁（一句话），详细信息放 decisions/notes
```

## 目录结构

```
context-manager/
├── ctx.py                  ← CLI 入口（argparse）
├── lib/
│   ├── __init__.py
│   ├── db.py              ← SQLite 操作（CRUD + FTS）
│   ├── formatter.py       ← 输出格式化（Markdown 结构）
│   └── models.py          ← dataclass 定义
├── tests/
│   ├── test_db.py
│   └── test_cli.py
├── SKILL.md               ← AI Agent skill 文件
├── pyproject.toml          ← 打包配置（pip install 后全局可用 ctx 命令）
└── README.md
```

## pyproject.toml

```toml
[project]
name = "ctx-manager"
version = "0.1.0"
description = "AI Agent persistent context manager"
requires-python = ">=3.10"

[project.scripts]
ctx = "ctx:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

## 安装后使用

```bash
# 安装
pip install -e .

# 或者直接运行
python ctx.py load "msgflow重构"
```

## 与现有工具的集成

### Kiro CLI（推荐方式：Skill，不需要 hooks）

Kiro CLI 的 hooks 机制和 claude-mem 格式不兼容，但 Kiro 原生支持 Skills。直接把 Skill 文件放到 `~/.kiro/skills/context-memory/SKILL.md`，Kiro 读到后会主动调用 `ctx` CLI 命令。

**不需要 hooks 适配，不需要改 Kiro 源码，零侵入。**

### Kiro CLI Hooks 格式（待验证）

Kiro CLI 支持 hooks，格式如下（写在 `~/.kiro/agents/default.json` 的 `hooks` 字段）：

```json
{
  "hooks": {
    "agentSpawn": [
      { "command": "ctx load --auto", "timeout": 10 }
    ],
    "postToolUse": [
      { "matcher": "*", "command": "ctx observe", "timeout": 5 }
    ],
    "stop": [
      { "command": "ctx save --auto", "timeout": 10 }
    ]
  }
}
```

Hook 行为：
- 接收 JSON via STDIN（包含 `hook_event_name`、`cwd`、`tool_name`、`tool_input` 等）
- STDOUT 输出会注入到 Agent 上下文
- Exit code 0 = 成功，其他 = 警告

**待验证：**
- [x] hooks 是否需要重启 Kiro CLI 才生效 → 已验证：重启后也不生效
- [x] Kiro CLI 是否实际执行 hooks → **已验证：当前版本不执行（文档有但功能未上线）**
- [ ] 未来版本修复后再切换到 hooks 方案

**当前结论：Kiro CLI hooks 不可用，走 Skill + ctx CLI 方案。**

**终极方案（hooks 验证通过后）：**

```json
{
  "hooks": {
    "agentSpawn": [
      { "command": "ctx load --auto --format inject", "timeout": 15 }
    ],
    "stop": [
      { "command": "ctx save --auto --stdin", "timeout": 15 }
    ]
  }
}
```

`ctx load --auto` 自动检测当前目录对应的项目，输出上下文到 STDOUT 注入会话。
`ctx save --auto --stdin` 从 STDIN 读取 `assistant_response`，提取关键信息保存。

| Agent | 集成方式 | Skill 位置 |
|-------|---------|-----------|
| Kiro CLI | **Skill（推荐）** | `~/.kiro/skills/context-memory/SKILL.md` |
| Hermes | Skill | `~/.hermes/skills/context-memory/SKILL.md` |
| Claude Code | Skill 或 hooks（claude-mem） | `.claude/skills/context-memory/SKILL.md` |
| Codex | Skill 或 hooks（claude-mem） | `.codex/skills/context-memory/SKILL.md` |

## 验收标准

1. `ctx save` + `ctx load` 能正确保存和恢复完整上下文
2. `ctx append` 追加的记录按时间排序，不丢失
3. `ctx search` 能跨项目搜索关键词
4. `ctx load` 的输出格式清晰，AI 读取后能理解项目全貌
5. SQLite 文件损坏时有错误提示，不 crash
6. 首次使用自动初始化数据库，无需手动 init
7. Skill 文件放入对应目录后，AI Agent 能自动识别并使用
