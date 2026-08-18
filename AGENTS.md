# Agent conventions (all agents: Claude Code, Codex, Hermes)

## Commits
- Every commit must be authored as `welldonestreams <chanceweldon11@gmail.com>`.
- Never use an AI agent name as author or committer.
- No AI-attribution trailers or footers in commit messages ("Co-Authored-By: Claude", "Generated with Claude Code", etc.) and none in PR bodies, unless the user explicitly asks for one.

## Branching
- Non-trivial work goes on `feat/*` branches; surface the branch name in handoffs so other agents don't collide on the shared checkout.
