return {
  name = "skillssh outdated empty",
  request = {
    action = "outdated",
    system = "skillssh",
  },
  expect = {
    success = true,
    events = { "outdated" },
    resultCount = 0,
  }
}
