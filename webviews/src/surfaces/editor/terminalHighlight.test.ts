import { describe, expect, test } from "bun:test";
import type { EditorTerminalTheme } from "./bridge";
import { hasUsableTerminalPalette, terminalTokenColors } from "./terminalHighlight";

const fullPalette = Array.from({ length: 16 }, (_, i) => `#c${i.toString(16)}0000`);

const theme = (overrides: Partial<EditorTerminalTheme> = {}): EditorTerminalTheme => ({
  background: "#101010",
  foreground: "#f0f0f0",
  palette: fullPalette,
  ...overrides,
});

describe("terminalTokenColors", () => {
  test("maps ANSI slots like the diff viewer's shikiThemeFromGhostty", () => {
    const colors = terminalTokenColors(theme());
    expect(colors.comment).toBe(fullPalette[8]);
    expect(colors.string).toBe(fullPalette[2]);
    expect(colors.constant).toBe(fullPalette[3]);
    expect(colors.keyword).toBe(fullPalette[5]);
    expect(colors.functionName).toBe(fullPalette[4]);
    expect(colors.typeName).toBe(fullPalette[6]);
    expect(colors.invalid).toBe(fullPalette[9]);
    expect(colors.heading).toBe(fullPalette[12]);
  });

  test("bright slots fall back to normal counterparts on 8-color palettes", () => {
    const colors = terminalTokenColors(theme({ palette: fullPalette.slice(0, 8) }));
    expect(colors.invalid).toBe(fullPalette[1]);
    expect(colors.heading).toBe(fullPalette[4]);
    expect(colors.raw).toBe(fullPalette[2]);
    expect(colors.link).toBe(fullPalette[6]);
  });

  test("blank slots fall back to the terminal foreground", () => {
    const gappy = [...fullPalette];
    gappy[2] = "";
    const colors = terminalTokenColors(theme({ palette: gappy }));
    expect(colors.string).toBe("#f0f0f0");
  });
});

describe("hasUsableTerminalPalette", () => {
  test("accepts a full terminal theme", () => {
    expect(hasUsableTerminalPalette(theme())).toBe(true);
  });

  test("rejects missing, short-palette, or foreground-less themes", () => {
    expect(hasUsableTerminalPalette(null)).toBe(false);
    expect(hasUsableTerminalPalette(undefined)).toBe(false);
    expect(hasUsableTerminalPalette(theme({ palette: fullPalette.slice(0, 4) }))).toBe(false);
    expect(hasUsableTerminalPalette(theme({ foreground: " " }))).toBe(false);
  });
});
