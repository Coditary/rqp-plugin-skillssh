return {
  name = "skillssh remove repo",
  request = {
    action = "remove",
    system = "skillssh",
    packages = {
      { name = "vercel-labs/skills" }
    },
  },
  fixtureRoot = "../fixtures-remove-repo",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills","package_kind":"repo","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","artifact_id":"skillssh/repo/vercel-labs_skills@sha-find_sha-spec","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-find_sha-spec","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills","${fixtureRoot}/home/.config/opencode/skills/spec-story"],"copy_mode":"symlink","installed_at":"2026-05-29T10:10:00Z","installed_revision":"sha-find+sha-spec","discovered_skills":["find-skills","spec-story"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "bunx skills remove 'find-skills'", exitCode = 0, stdout = "removed\n", stderr = "", success = true },
    { match = "bunx skills remove 'spec-story'", exitCode = 0, stdout = "removed\n", stderr = "", success = true },
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
