// Corrected test for prompts.
// The brief's Step 1 test had a substring mismatch with Step 3's implementation:
//   - test expected: "USER FEEDBACK: hazlo más corto"
//   - impl produces: "USER FEEDBACK (apply these changes to the new version): hazlo más corto"
// The implementation's annotated form is more explicit for the model, so the
// controller corrected the test to match the implementation.
const { buildMessages, TALE_TEXT_PROMPT } = require("../src/prompts");

describe("prompts", () => {
  test("buildMessages includes theme in user content", () => {
    const msgs = buildMessages({ theme: "amistad" });
    expect(msgs).toHaveLength(2);
    expect(msgs[1].content).toContain("amistad");
  });

  test("buildMessages appends feedback to system prompt when provided", () => {
    const msgs = buildMessages({ theme: null, feedback: "hazlo más corto" });
    expect(msgs[0].content).toContain("USER FEEDBACK");
    expect(msgs[0].content).toContain("hazlo más corto");
  });

  test("buildMessages omits feedback section when not provided", () => {
    const msgs = buildMessages({ theme: null });
    expect(msgs[0].content).not.toContain("USER FEEDBACK");
  });

  test("TALE_TEXT_PROMPT mentions 300-500 words and El fin.", () => {
    expect(TALE_TEXT_PROMPT).toContain("300-500 words");
    expect(TALE_TEXT_PROMPT).toContain("El fin.");
  });
});
