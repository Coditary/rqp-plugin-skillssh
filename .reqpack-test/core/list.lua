return {
  name = "skillssh list",
  request = {
    action = "list",
    system = "skillssh",
  },
  fixtureRoot = "../fixtures-list",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.config/opencode/skills/find-skills",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/app.json",
      content = [[{"launcher":"bunx","version":"1.2.3","detected_at":"2026-05-29T10:00:00Z"}]],
    },
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills#find-skills","package_kind":"skill","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","skill_name":"find-skills","artifact_id":"skillssh/skill/vercel-labs_skills/find-skills@sha-find","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-find","scope":"global","agents":["opencode"],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"copy","installed_at":"2026-05-29T10:20:00Z","installed_revision":"sha-find","discovered_skills":["find-skills"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = ".config/opencode/skills/find-skills'", exitCode = 0, stdout = "", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "listed" },
    resultCount = 2,
    resultName = "app:skillssh",
    resultVersion = "1.2.3",
  }
}
