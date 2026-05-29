return {
  name = "skillssh info app",
  request = {
    action = "info",
    system = "skillssh",
    prompt = "app:skillssh",
  },
  fixtureRoot = "../fixtures-info-app",
  fixtureDirs = {
    "home/.local/share/skillssh/reqpack",
  },
  fixtureFiles = {
    {
      path = "home/.local/share/skillssh/reqpack/app.json",
      content = [[{"launcher":"bunx","version":"1.2.3","detected_at":"2026-05-29T10:00:00Z"}]],
    },
  },
  environment = {
    HOME = "${fixtureRoot}/home",
  },
  expect = {
    success = true,
    events = { "informed" },
    resultCount = 1,
    resultName = "app:skillssh",
    resultVersion = "1.2.3",
  }
}
