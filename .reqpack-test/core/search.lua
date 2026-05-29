return {
  name = "skillssh search app",
  request = {
    action = "search",
    system = "skillssh",
    prompt = "skills.sh",
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 1,
    resultName = "app:skillssh",
  }
}
