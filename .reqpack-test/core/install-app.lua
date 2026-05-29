return {
  name = "skillssh install app",
  request = {
    action = "install",
    system = "skillssh",
    packages = {
      { name = "app:skillssh" }
    },
  },
  fixtureRoot = "../fixtures-install-app",
  fixtureDirs = {
    "home",
    "home/.local/share/skillssh/reqpack",
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  fakeExec = {
    { match = "bunx skills --version", exitCode = 0, stdout = "1.2.3\n", stderr = "", success = true },
    { match = "mkdir -p '", exitCode = 0, stdout = "", stderr = "", success = true },
    { match = "date -u +%Y-%m-%dT%H:%M:%SZ", exitCode = 0, stdout = "2026-05-29T10:00:00Z\n", stderr = "", success = true },
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
