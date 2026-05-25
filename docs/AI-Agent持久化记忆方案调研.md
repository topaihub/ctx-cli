# AI Agent 持久化记忆方案调研

## 问题

AI Agent 会话结束后上下文丢失。新会话需要重新解释项目背景、已做决策、当前进度。

## 现有方案对比

| 方案 | 原理 | 优势 | 劣势 | 开源 | 成本 |
|------|------|------|------|------|------|
| [claude-mem](https://github.com/thedotmack/claude-mem) | Hook 自动捕获 Agent 操作 → AI 压缩 → 注入下次会话 | 全自动，不需要手动 save | 依赖 hook 机制，需要 Agent 支持 hooks | ✅ | 免费 |
| [Basic Memory](https://docs.basicmemory.com) | MCP 协议，跨 Agent 共享记忆 | 标准协议，Codex/Claude/Cursor 互通 | 需要跑 MCP server | ✅ | 免费 |
| [Rememora](https://rememora.ai) | 商业产品，自动记录决策/上下文 | 开箱即用，UI 好 | 付费，闭源，数据不在本地 | ❌ | 付费 |
| Codex 内置 Memories | OpenAI 官方，Codex 自带持久记忆 | 原生集成，零配置 | 只限 Codex，不跨 Agent | — | 免费 |
| Claude CLAUDE.md | 项目根目录放 CLAUDE.md，每次会话自动读 | 零依赖，简单 | 手动维护，不结构化，不可搜索 | — | 免费 |
| [Neo4j + Hooks](https://towardsdatascience.com/unified-agentic-memory-across-harnesses-using-hooks/) | 图数据库存记忆，hook 自动写入 | 关联查询强，知识图谱 | 重，需要跑 Neo4j 实例 | ✅ | 免费（自建） |
| ctx CLI + SQLite（自研） | CLI + SQLite + Skill 文件 | 轻量本地，跨 Agent，可控 | 需要手动触发（或配合 hook） | ✅ | 免费 |

## 详细分析

### 1. claude-mem（推荐研究）

- GitHub: https://github.com/thedotmack/claude-mem
- 原理：通过 Agent 的 hook 机制（如 Claude Code 的 PostToolUse hook），自动捕获每次工具调用的结果，用 AI 压缩成摘要，存入本地文件。下次会话开始时自动注入。
- 支持：Claude Code, OpenClaw, Codex, Gemini, Hermes, Copilot, OpenCode
- 存储：本地 Markdown 文件（压缩后的记忆）
- 亮点：**完全自动**，不需要用户或 AI 手动操作

### 2. Basic Memory（推荐研究）

- 官网: https://docs.basicmemory.com
- 原理：实现 MCP（Model Context Protocol）server，任何支持 MCP 的 Agent 都能通过标准协议读写记忆。
- 支持：所有支持 MCP 的 Agent（Claude Code, Codex, Cursor, Kiro 等）
- 存储：本地 Markdown 文件 + SQLite 索引
- 亮点：**跨 Agent 互通**——在 Codex 里记的东西，Claude Code 也能读到

### 3. Codex 内置 Memories

- 文档: https://developers.openai.com/codex/memories
- 原理：Codex 原生支持持久记忆，自动记住项目的架构决策、代码风格等
- 限制：只在 Codex 生态内有效，不跨 Agent

### 4. Claude CLAUDE.md / Kiro AGENTS.md

- 原理：在项目根目录放一个 Markdown 文件，Agent 每次启动自动读取
- 优势：零依赖，任何 Agent 都支持
- 劣势：手动维护，不结构化，文件大了之后 token 浪费

### 5. Neo4j + Hooks

- 文章: https://towardsdatascience.com/unified-agentic-memory-across-harnesses-using-hooks/
- 原理：用图数据库存储记忆节点和关系，通过 hook 自动写入
- 优势：关联查询强（"哪些决策影响了这个文件"）
- 劣势：需要跑 Neo4j，对个人项目太重

## 推荐方案

### 短期（立即可用）：claude-mem

- 安装简单，开源免费
- 全自动，不需要改工作习惯
- 支持你在用的大部分 Agent

### 中期（标准化）：Basic Memory MCP

- 如果你的 Agent 都支持 MCP，这是最优雅的方案
- 一个 MCP server 统一管理所有 Agent 的记忆
- 记忆可搜索、可关联、可导出

### 长期（自研增强）：ctx CLI + SQLite

- 如果现有方案不满足需求（比如需要和 llmwiki 深度集成）
- 可以在 claude-mem 或 Basic Memory 的基础上扩展
- 加入 FTS5 搜索、知识图谱关联、wiki 同步等自定义功能

## 建议的行动路径

```
1. 先试 claude-mem（10 分钟安装，立即生效）
   ↓
2. 评估效果，如果满足需求就用它
   ↓
3. 如果需要跨 Agent 共享，加 Basic Memory MCP
   ↓
4. 如果需要深度定制（llmwiki 集成、知识图谱），再自研 ctx CLI
```

## 参考链接

- claude-mem: https://github.com/thedotmack/claude-mem
- Basic Memory: https://docs.basicmemory.com
- Basic Memory + Codex: https://docs.basicmemory.com/integrations/codex
- Rememora: https://rememora.ai
- Codex Memories: https://developers.openai.com/codex/memories
- Neo4j Hooks: https://towardsdatascience.com/unified-agentic-memory-across-harnesses-using-hooks/
- Claude Memory 指南: https://felo.ai/blog/claude-code-memory/
