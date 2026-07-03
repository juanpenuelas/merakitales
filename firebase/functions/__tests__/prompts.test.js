const { buildMessages } = require("../src/prompts");

describe("prompts", () => {
  it("should contain the ESCAPING rule in the system prompt", () => {
    const messages = buildMessages();
    const systemMsg = messages.find(m => m.role === "system");
    expect(systemMsg.content).toContain("ESCAPING");
    expect(systemMsg.content).toContain("escape all double quotes (\\\")");
    expect(systemMsg.content).toContain("escape all newlines as \\n");
  });
});
