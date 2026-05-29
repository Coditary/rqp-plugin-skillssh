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
    {
      match = "curl -fsSL 'https://skills.sh/vercel-labs/skills/find-skills'",
      exitCode = 0,
      stdout = [[<!DOCTYPE html><html><head><script type="application/ld+json">{"@context":"https://schema.org","@type":"SoftwareApplication","description":"Helps users discover and install agent skills when they ask questions like \"how do I do X\" or \"find a skill for X\"."}</script></head><body></body></html>
]],
      stderr = "",
      success = true,
    },
    {
      match = "curl -fsSL 'https://skills.sh/vercel-labs/skills/spec-story'",
      exitCode = 0,
      stdout = [[<!DOCTYPE html><html><head><script type="application/ld+json">{"@context":"https://schema.org","@type":"SoftwareApplication","description":"Turns rough ideas into structured specs and implementation-ready plans."}</script></head><body></body></html>
]],
      stderr = "",
      success = true,
    },
  },
  expect = {
    success = true,
    commands = {
      "curl -fsSL 'https://skills.sh/api/search?q=find-skills&limit=15'",
      "curl -fsSL 'https://skills.sh/vercel-labs/skills/find-skills'",
      "curl -fsSL 'https://skills.sh/vercel-labs/skills/spec-story'",
    },
    events = { "searched" },
    resultCount = 3,
    resultName = "vercel-labs/skills",
  }
}
