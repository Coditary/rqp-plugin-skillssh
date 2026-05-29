return {
  name = "skillssh info repo",
  request = {
    action = "info",
    system = "skillssh",
    prompt = "vercel-labs/skills",
  },
  fixtureRoot = "../fixtures-info-repo",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/projections.json",
      content = [[{"projections":[{"package_id":"vercel-labs/skills","package_kind":"repo","source":"vercel-labs/skills","source_url":"https://github.com/vercel-labs/skills","artifact_id":"skillssh/repo/vercel-labs_skills@sha-find","artifact_path":"${fixtureRoot}/home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-find","scope":"project","agents":[],"target_paths":["${fixtureRoot}/home/.config/opencode/skills/find-skills"],"copy_mode":"symlink","installed_at":"2026-05-29T10:10:00Z","installed_revision":"sha-find","discovered_skills":["find-skills"]}]}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "vercel-labs/skills",
    resultVersion = "sha-find",
  }
}
