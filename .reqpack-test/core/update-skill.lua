return {
  name = "skillssh update skill",
  request = {
    action = "update",
    system = "skillssh",
    packages = {
      { name = "vercel-labs/skills/find-skills" }
    },
  },
  fixtureRoot = "../fixtures-update-skill",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.local/share/aicache",
    "home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-newer",
    "home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-newer",
    "home/.local/share/aicache/views/by-source/skillssh/repo/vercel-labs_skills",
    "home/.local/share/aicache/views/by-source/skillssh/skill/vercel-labs_skills/find-skills",
    "home/.config/opencode/skills/find-skills",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills#find-skills","package_kind":"skill","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","skill_name":"find-skills","artifact_id":"skillssh/skill/vercel-labs_skills/find-skills@sha-old","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-old","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"symlink","installed_at":"2026-05-29T09:30:00Z","installed_revision":"sha-old","discovered_skills":["find-skills"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "bunx skills add 'vercel-labs/skills' --skill 'find-skills' -y", exitCode = 0, stdout = "updated\n", stderr = "", success = true },
    { match = "bunx skills list --json", exitCode = 0, stdout = '[{"name":"find-skills","description":"Find skills","path":"${fixtureRoot}/home/.config/opencode/skills/find-skills","canonicalPath":"${fixtureRoot}/home/.config/opencode/skills/find-skills","scope":"global","skillFolderHash":"sha-newer"}]\n', stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = ".config/opencode/skills/find-skills'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T10:40:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "updated", "success" },
    eventPayloads = {
      updated = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
