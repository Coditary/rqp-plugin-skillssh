return {
  name = "skillssh install repo",
  request = {
    action = "install",
    system = "skillssh",
    packages = {
      { name = "vercel-labs/skills" }
    },
  },
  fixtureRoot = "../fixtures-install-repo",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.local/share/aicache",
    "home/.local/share/aicache/artifacts/skillssh/repo/vercel-labs_skills@sha-find_sha-spec",
    "home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/find-skills@sha-find",
    "home/.local/share/aicache/artifacts/skillssh/skill/vercel-labs_skills/spec-story@sha-spec",
    "home/.local/share/aicache/views/by-source/skillssh/repo/vercel-labs_skills",
    "home/.local/share/aicache/views/by-source/skillssh/skill/vercel-labs_skills/find-skills",
    "home/.local/share/aicache/views/by-source/skillssh/skill/vercel-labs_skills/spec-story",
    "home/.config/opencode/skills/find-skills",
    "home/.config/opencode/skills/spec-story",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "bunx skills add 'vercel-labs/skills' -y", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
    { match = "bunx skills list --json", exitCode = 0, stdout = '[{"name":"find-skills","description":"Find skills","path":"${fixtureRoot}/home/.config/opencode/skills/find-skills","canonicalPath":"${fixtureRoot}/home/.config/opencode/skills/find-skills","scope":"global","skillFolderHash":"sha-find"},{"name":"spec-story","description":"Spec story","path":"${fixtureRoot}/home/.config/opencode/skills/spec-story","canonicalPath":"${fixtureRoot}/home/.config/opencode/skills/spec-story","scope":"global","skillFolderHash":"sha-spec"}]\n', stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = ".config/opencode/skills/find-skills'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = ".config/opencode/skills/spec-story'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T10:10:00Z\n", stderr = "", success = true },
  },
  expect = {
    success = true,
    events = { "installed", "success" },
    eventPayloads = {
      installed = "{1=<lua-value>}",
      success = "ok",
    },
  }
}
