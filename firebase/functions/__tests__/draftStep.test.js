const { computeStep } = require("../src/draftStep");

describe("computeStep", () => {
  test("returns 'text' when nothing is uploaded", () => {
    expect(computeStep({})).toBe("text");
  });

  test("returns 'text' when called with no argument", () => {
    expect(computeStep()).toBe("text");
  });

  test("returns 'image' when only the image is present", () => {
    expect(computeStep({ image_url: "https://x/image_1024.png" })).toBe("image");
  });

  test("returns 'image' when image + only one audio language are present", () => {
    expect(computeStep({ image_url: "https://x/image_1024.png", audio_url_es: "https://x/audio_es.mp3" })).toBe("image");
  });

  test("returns 'audio' when image + both audio languages are present", () => {
    expect(computeStep({
      image_url: "https://x/image_1024.png",
      audio_url_es: "https://x/audio_es.mp3",
      audio_url_en: "https://x/audio_en.mp3",
    })).toBe("audio");
  });

  test("returns 'text' when both audios exist but the image does not (documented edge case)", () => {
    expect(computeStep({
      audio_url_es: "https://x/audio_es.mp3",
      audio_url_en: "https://x/audio_en.mp3",
    })).toBe("text");
  });
});
