return {
  name = "skillssh search remote",
  request = {
    action = "search",
    system = "skillssh",
    prompt = "find-skills",
  },
  fakeExec = {
    {
      match = "curl -fsSL 'https://skills.sh/api/search?q=find-skills&limit=15'",
      exitCode = 0,
      stdout = [[{"query":"find-skills","skills":[{"id":"vercel-labs/skills/find-skills","skillId":"find-skills","name":"find-skills","installs":1761081,"source":"vercel-labs/skills"},{"id":"vercel-labs/skills/spec-story","skillId":"spec-story","name":"spec-story","installs":42000,"source":"vercel-labs/skills"},{"id":"skills.volces.com/find-skills","skillId":"find-skills","name":"find-skills","installs":1469,"source":"skills.volces.com"}]}
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    events = { "searched" },
    resultCount = 3,
    resultName = "vercel-labs/skills",
  }
}
