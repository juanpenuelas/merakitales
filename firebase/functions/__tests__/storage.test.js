const sharp = require("sharp");
const { resizeToWidth } = require("../src/storage");

describe("storage helpers", () => {
  test("resizeToWidth scales a PNG buffer down", async () => {
    const original = await sharp({
      create: { width: 1024, height: 1024, channels: 4, background: "#fff" },
    }).png().toBuffer();
    const resized = await resizeToWidth({ buffer: original, width: 640 });
    const meta = await sharp(resized).metadata();
    expect(meta.width).toBe(640);
  });

  test("resizeToWidth does not upscale", async () => {
    const original = await sharp({
      create: { width: 400, height: 400, channels: 4, background: "#fff" },
    }).png().toBuffer();
    const resized = await resizeToWidth({ buffer: original, width: 640 });
    const meta = await sharp(resized).metadata();
    expect(meta.width).toBe(400);
  });
});
