# Agent Skills

Skills for building TanStack Start apps on Cloudflare Workers. They follow the [Agent Skills](https://agentskills.io) format, so Claude Code, Codex, Cursor, and other agents can use them.

| Skill | Use it for |
| --- | --- |
| [`typescript-standards`](skills/typescript-standards/SKILL.md) | Types, schemas, module design, errors, comments, and tests |
| [`cloudflare-backend`](skills/cloudflare-backend/SKILL.md) | Server code on Workers: boundaries, messages, persistence, bindings, retries |
| [`tanstack-frontend`](skills/tanstack-frontend/SKILL.md) | React and TanStack Start: FSD entities, queries, mutations, routes, UI |
| [`composition-root`](skills/composition-root/SKILL.md) | Build dependencies from Cloudflare bindings and keep raw bindings out of inner code |
| [`tech-spec`](skills/tech-spec/SKILL.md) | A typed architecture handoff before code |
| [`product-research`](skills/product-research/SKILL.md) | Validate product ideas from community pain points |

## Install

Any agent with a shell:

```bash
npx skills add alexander-zuev/agent-skills
```

Add `-s <skill>` for one skill, `-g` for all projects, or `-a <agent>` for one agent. The [skills CLI](https://github.com/vercel-labs/skills) supports Claude Code, Codex, Cursor, and many others.

Claude Code plugin:

```text
/plugin marketplace add alexander-zuev/agent-skills
/plugin install agent-skills@agent-skills
```

claude.ai: download a skill zip from the [latest release](https://github.com/alexander-zuev/agent-skills/releases/tag/latest), then upload it in **Settings → Capabilities → Skills**.

Agents that can only fetch a URL: read `https://raw.githubusercontent.com/alexander-zuev/agent-skills/main/skills/<skill>/SKILL.md`.

## How this repository works

The skills are written and edited in a private repository. A CI job copies each skill listed in [`skills.txt`](skills.txt) into `skills/` on every change.
Do not edit files in `skills/` here; the next sync replaces them. Open an issue for a correction or a suggestion.
