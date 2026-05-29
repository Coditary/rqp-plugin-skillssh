# skillssh API

## Supported actions

- `install`
- `remove`
- `update`
- `list`
- `info`
- `search`
- `outdated`

## Flags

- `global`
- `project`
- `copy`
- `agent=<id>`
- `skill=<name>`

## Behavior summary

- `install app:skillssh` records launcher metadata
- repo install wraps `skills add <source> -y`
- skill install wraps `skills add <source> --skill <name> -y`
- `remove` drops projections, not canonical cache artifacts
- `list` shows installed projections and cache-only views
- `info` prefers projection metadata, then cache views
- installed skill projections are enriched from local `SKILL.md` frontmatter when present
