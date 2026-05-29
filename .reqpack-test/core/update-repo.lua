return {
  name = "skillssh update repo",
  request = {
    action = "update",
    system = "skillssh",
    packages = {
      { name = "vercel-labs/skills" }
    },
  },
  fixtureRoot = "../fixtures-update-repo",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.local/share/aicache",
    "home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-new",
    "home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-new",
    "home/.local/share/aicache/views/by-source/skillssh/repo/vercel-labs_skills",
    "home/.local/share/aicache/views/by-source/skillssh/skill/vercel-labs_skills/find-skills",
    "home/.config/opencode/skills/find-skills",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills","package_kind":"repo","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","artifact_id":"skillssh/repo/vercel-labs_skills@sha-old","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-old","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"symlink","installed_at":"2026-05-29T09:00:00Z","installed_revision":"sha-old","discovered_skills":["find-skills"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "bunx skills add 'vercel-labs/skills' -y", exitCode = 0, stdout = "updated\n", stderr = "", success = true },
    { match = "bunx skills list --json", exitCode = 0, stdout = '[{"name":"find-skills","description":"Find skills","path":"${fixtureRoot}/home/.config/opencode/skills/find-skills","canonicalPath":"${fixtureRoot}/home/.config/opencode/skills/find-skills","scope":"global","skillFolderHash":"sha-new"}]\n', stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = ".config/opencode/skills/find-skills'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T10:30:00Z\n", stderr = "", success = true },
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
