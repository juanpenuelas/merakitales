const sharp = require("sharp");
const { resizeToWidth, downloadFile, fileExists } = require("../src/storage");

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

describe("downloadFile", () => {
  test("returns the file's buffer contents", async () => {
    const mockBuffer = Buffer.from("hello");
    const bucket = { file: jest.fn(() => ({ download: jest.fn(async () => [mockBuffer]) })) };
    const result = await downloadFile({ bucket, path: "some/path.png" });
    expect(result).toBe(mockBuffer);
    expect(bucket.file).toHaveBeenCalledWith("some/path.png");
  });
});

describe("fileExists", () => {
  test("returns true when the file exists", async () => {
    const bucket = { file: jest.fn(() => ({ exists: jest.fn(async () => [true]) })) };
    expect(await fileExists({ bucket, path: "a" })).toBe(true);
  });

  test("returns false when the file does not exist", async () => {
    const bucket = { file: jest.fn(() => ({ exists: jest.fn(async () => [false]) })) };
    expect(await fileExists({ bucket, path: "a" })).toBe(false);
  });
});
