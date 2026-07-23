/**
 * Maps the user's Ghostty terminal theme onto CodeMirror syntax highlighting.
 *
 * The ANSI-slot assignments mirror `shikiThemeFromGhostty` in
 * `pierre-options.ts` (the diff viewer's palette mapping) so the same file
 * looks identical in the editor, the diff viewer, and the terminal:
 * comments = bright black (italic), strings = green, constants = yellow,
 * keywords = magenta, functions = blue, types = cyan.
 */
import { HighlightStyle } from "@codemirror/language";
import { tags } from "@lezer/highlight";
import type { EditorTerminalTheme } from "./bridge";

export type TerminalTokenColors = {
  comment: string;
  string: string;
  constant: string;
  keyword: string;
  functionName: string;
  typeName: string;
  invalid: string;
  heading: string;
  strong: string;
  emphasis: string;
  raw: string;
  link: string;
  quote: string;
};

export function hasUsableTerminalPalette(
  theme: EditorTerminalTheme | null | undefined,
): theme is EditorTerminalTheme {
  return Boolean(
    theme &&
      typeof theme.foreground === "string" &&
      theme.foreground.trim() !== "" &&
      Array.isArray(theme.palette) &&
      theme.palette.length >= 8,
  );
}

export function terminalTokenColors(theme: EditorTerminalTheme): TerminalTokenColors {
  const palette = theme.palette ?? [];
  const slot = (index: number, fallback?: string): string => {
    const value = palette[index];
    if (typeof value === "string" && value.trim() !== "") {
      return value;
    }
    return fallback ?? theme.foreground;
  };
  // Bright slots (8-15) fall back to their normal counterparts, matching the
  // diff viewer's tokenColor fallbacks for 8-color themes.
  return {
    comment: slot(8),
    string: slot(2),
    constant: slot(3),
    keyword: slot(5),
    functionName: slot(4),
    typeName: slot(6),
    invalid: slot(9, slot(1)),
    heading: slot(12, slot(4)),
    strong: slot(11, slot(3)),
    emphasis: slot(13, slot(5)),
    raw: slot(10, slot(2)),
    link: slot(14, slot(6)),
    quote: slot(8),
  };
}

export function terminalHighlightStyle(theme: EditorTerminalTheme): HighlightStyle {
  const colors = terminalTokenColors(theme);
  return HighlightStyle.define([
    { tag: tags.comment, color: colors.comment, fontStyle: "italic" },
    { tag: [tags.string, tags.special(tags.string), tags.character, tags.attributeValue], color: colors.string },
    { tag: [tags.number, tags.bool, tags.null, tags.atom, tags.literal, tags.unit], color: colors.constant },
    {
      tag: [
        tags.keyword,
        tags.modifier,
        tags.operatorKeyword,
        tags.controlKeyword,
        tags.definitionKeyword,
        tags.moduleKeyword,
        tags.self,
      ],
      color: colors.keyword,
    },
    {
      tag: [tags.function(tags.variableName), tags.function(tags.propertyName), tags.macroName],
      color: colors.functionName,
    },
    { tag: [tags.typeName, tags.className, tags.namespace, tags.tagName], color: colors.typeName },
    { tag: tags.invalid, color: colors.invalid },
    { tag: tags.heading, color: colors.heading, fontWeight: "bold" },
    { tag: tags.strong, color: colors.strong, fontWeight: "bold" },
    { tag: tags.emphasis, color: colors.emphasis, fontStyle: "italic" },
    { tag: tags.monospace, color: colors.raw },
    { tag: [tags.link, tags.url], color: colors.link },
    { tag: tags.quote, color: colors.quote, fontStyle: "italic" },
  ]);
}
