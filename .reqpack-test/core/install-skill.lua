return {
  name = "skillssh install skill npx fallback",
  request = {
    action = "install",
    system = "skillssh",
    packages = {
      {
        name = "https://github.com/vercel-labs/skills#find-skills"
      }
    },
  },
  fixtureRoot = "../fixtures-install-skill",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
    "home/.local/share/aicache",
    "home/.local/share/aicache/artifacts/skillssh/repo/github.com_vercel-labs_skills@sha-find",
    "home/.local/share/aicache/artifacts/skillssh/skill/github.com_vercel-labs_skills/find-skills@sha-find",
    "home/.local/share/aicache/views/by-source/skillssh/repo/github.com_vercel-labs_skills",
    "home/.local/share/aicache/views/by-source/skillssh/skill/github.com_vercel-labs_skills/find-skills",
    "home/.config/opencode/skills/find-skills",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 1, stdout = "", stderr = "bunx missing", success = false },
    { match = "npx --yes skills --version", exitCode = 0, stdout = "1.2.4\n", stderr = "", success = true },
    { match = "npx --yes skills add 'https://github.com/vercel-labs/skills' --skill 'find-skills' -y", exitCode = 0, stdout = "installed\n", stderr = "", success = true },
    { match = "npx --yes skills list --json", exitCode = 0, stdout = '[{"name":"find-skills","description":"Find skills","path":"${fixtureRoot}/home/.config/opencode/skills/find-skills","canonicalPath":"${fixtureRoot}/home/.config/opencode/skills/find-skills","scope":"global","skillFolderHash":"sha-find"}]\n', stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = ".config/opencode/skills/find-skills'", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "cp -R '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T10:20:00Z\n", stderr = "", success = true },
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
