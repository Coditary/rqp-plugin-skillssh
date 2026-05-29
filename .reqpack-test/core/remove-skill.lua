return {
  name = "skillssh remove skill",
  request = {
    action = "remove",
    system = "skillssh",
    packages = {
      { name = "vercel-labs/skills/find-skills" }
    },
  },
  fixtureRoot = "../fixtures-remove-skill",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills#find-skills","package_kind":"skill","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","skill_name":"find-skills","artifact_id":"skillssh/skill/vercel-labs_skills/find-skills@sha-find","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-find","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"symlink","installed_at":"2026-05-29T10:20:00Z","installed_revision":"sha-find","discovered_skills":["find-skills"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "bunx skills remove 'find-skills'", exitCode = 0, stdout = "removed\n", stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "deleted", "success" },
    eventPayloads = {
      deleted = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
