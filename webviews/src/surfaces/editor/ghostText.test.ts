import { describe, expect, test } from "bun:test";
import { clipContext, isCompletionPosition } from "./ghostText";

describe("isCompletionPosition", () => {
  test("accepts end of line, whitespace, and closing delimiters", () => {
    expect(isCompletionPosition("")).toBe(true);
    expect(isCompletionPosition("   ")).toBe(true);
    expect(isCompletionPosition(")")).toBe(true);
    expect(isCompletionPosition("});")).toBe(true);
    expect(isCompletionPosition(" )]}")).toBe(true);
  });

  test("rejects positions with code to the right", () => {
    expect(isCompletionPosition("foo")).toBe(false);
    expect(isCompletionPosition(" = 1")).toBe(false);
    expect(isCompletionPosition("bar)")).toBe(false);
  });
});

describe("clipContext", () => {
  test("returns short text unchanged", () => {
    expect(clipContext("let x = 1", 2048, "end")).toBe("let x = 1");
    expect(clipContext("let x = 1", 2048, "start")).toBe("let x = 1");
  });

  test("prefix keeps the tail, suffix keeps the head", () => {
    const text = "abcdefghij";
    expect(clipContext(text, 4, "end")).toBe("ghij");
    expect(clipContext(text, 4, "start")).toBe("abcd");
  });

  test("counts UTF-8 bytes and never splits a character", () => {
    // Each of these is 3 bytes in UTF-8.
    const japanese = "あいうえお";
    const clipped = clipContext(japanese, 7, "start");
    expect(clipped).toBe("あい");
    expect(new TextEncoder().encode(clipped).length).toBeLessThanOrEqual(7);

    const emoji = "🙂🙂🙂";
    const clippedEmoji = clipContext(emoji, 5, "start");
    expect(clippedEmoji).toBe("🙂");
    expect([...clippedEmoji].length).toBe(1);
  });
});
