const std = @import("std");

pub const Agent = enum {
    codex,
    claude,
    kiro,
};

pub fn defaultTargetPath(allocator: std.mem.Allocator, environ: std.process.Environ, agent: Agent) ![]u8 {
    const home = environ.getAlloc(allocator, "USERPROFILE") catch environ.getAlloc(allocator, "HOME") catch return error.HomeDirectoryNotFound;
    defer allocator.free(home);

    const suffix = switch (agent) {
        .codex => ".codex\\skills\\context-manager\\SKILL.md",
        .claude => ".claude\\skills\\context-manager\\SKILL.md",
        .kiro => ".kiro\\skills\\context-manager\\SKILL.md",
    };
    return try std.fs.path.join(allocator, &.{ home, suffix });
}

pub fn render(allocator: std.mem.Allocator) ![]u8 {
    return try allocator.dupe(u8,
        \\---
        \\name: context-manager
        \\description: |
        \\  AI Agent 持久化记忆系统。会话开始时读取上下文，关键决策实时追加，会话结束前保存上下文。
        \\  触发词：继续、上下文、ctx、项目名、保存上下文、读取上下文。
        \\---
        \\
        \\# Context Manager
        \\
        \\## 触发规则
        \\
        \\1. 当用户提到项目名、说“继续”、或要求恢复上下文时，先执行 `ctx load <project>`.
        \\2. 当做出关键决策、进度更新或备注时，执行 `ctx append <project> ...`.
        \\3. 当会话接近结束时，执行 `ctx save <project> --summary "..."`.
        \\4. 当用户询问项目概况时，先用 `ctx load` 再回答。
        \\
        \\## 常用命令
        \\
        \\```bash
        \\ctx init
        \\ctx save <project> --summary "..."
        \\ctx load <project>
        \\ctx append <project> --decision "..."
        \\ctx append <project> --progress "..."
        \\ctx append <project> --note "..."
        \\ctx append <project> --pending "..."
        \\ctx list
        \\ctx search <keyword>
        \\```
        \\
        \\## 安装
        \\
        \\- Codex: `ctx skill install --agent codex`
        \\- Claude Code: `ctx skill install --agent claude`
        \\- Kiro: `ctx skill install --agent kiro`
        \\
        \\## 规则
        \\
        \\- 读取到的上下文直接作为当前会话背景。
        \\- 不要让用户重复解释已记录的信息。
        \\- 关键决策要实时追加，不要等到会话结束。
        \\- `summary` 保持简短，把细节放到决策/备注里。
    );
}
