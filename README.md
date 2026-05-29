# skillssh

ReqPack Lua wrapper for `skills.sh` with shared-cache-aware skill projection.

## What it manages

- launcher availability via `app:skillssh`
- repo installs like `owner/repo`
- concrete skill installs like `owner/repo/skill-name`
- canonical AICache artifacts for repos and skills
- runtime projections into agent or project skill directories

## Package forms

- `app:skillssh`
- `owner/repo`
- `https://github.com/owner/repo`
- `owner/repo/skill-name`
- `https://github.com/owner/repo#skill-name`

## Notes

- launcher preference: `bunx skills`, then `npx --yes skills`
- `installLocal()` unsupported in v1
- `outdated()` conservative/empty in v1
- canonical cache lives in `~/.local/share/aicache`
- plugin metadata lives in `~/.local/share/skillssh/reqpack`
- `info/list` enrich installed skill projections from `SKILL.md` frontmatter when present

## Test

```sh
rqp test-plugin --plugin ./run.lua --preset core
```
