return {
  name = "skillssh install local unsupported",
  request = {
    action = "install",
    system = "skillssh",
    localPath = "/tmp/skills-local",
  },
  expect = {
    success = false,
    events = { "failed", "unavailable" },
    eventPayloads = {
      failed = "skillssh plugin does not support installLocal()",
      unavailable = "{path=/tmp/skills-local, reason=local-install-unsupported}",
    },
  }
}
