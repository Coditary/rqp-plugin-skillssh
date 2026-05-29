return {
  name = "skillssh info cached skill",
  request = {
    action = "info",
    system = "skillssh",
    prompt = "vercel-labs/skills/find-skills",
  },
  fixtureRoot = "../fixtures-info-skill",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.config/opencode/skills/find-skills",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills#find-skills","package_kind":"skill","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","skill_name":"find-skills","artifact_id":"skillssh/skill/vercel-labs_skills/find-skills@sha-find","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-find","scope":"global","agents":["opencode"],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"copy","installed_at":"2026-05-29T10:20:00Z","installed_revision":"sha-find","discovered_skills":["find-skills"]}]}]],
    },
    {
      path = "home/.config/opencode/skills/find-skills/SKILL.md",
      content = [[---
name: find-skills
description: Finds reusable skills quickly
metadata:
  skillFolderHash: fm-hash
---
Body]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "test -f '", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "vercel-labs/skills#find-skills",
    resultVersion = "fm-hash",
  }
}
