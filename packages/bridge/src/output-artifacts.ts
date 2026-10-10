export interface OutputLinkCandidate {
  href: string;
  label: string;
  syntax: "markdown" | "inline" | "bare";
}

const MAX_CANDIDATES = 128;
const MAX_PATH_LENGTH = 2048;
const MAX_LABEL_LENGTH = 256;

/** Compact destinations let clients resolve workspace files without tool stdout. */
export function outputLinkCandidates(text: string): OutputLinkCandidate[] {
  const candidates: OutputLinkCandidate[] = [];
  const seen = new Set<string>();
  const add = (href: string, label: string, syntax: OutputLinkCandidate["syntax"]) => {
    if (candidates.length >= MAX_CANDIDATES || href.length > MAX_PATH_LENGTH) return;
    if (!href || href.startsWith("#") || href.endsWith("/")) return;
    if (/^[a-z][a-z0-9+.-]*:/i.test(href) && !/^file:/i.test(href) && !/^[a-z]:[\\/]/i.test(href)) return;
    if (href.startsWith("//")) return;
    const key = `${syntax}:${href}`;
    if (seen.has(key)) return;
    seen.add(key);
    candidates.push({ href, label: label.slice(0, MAX_LABEL_LENGTH), syntax });
  };

  let fence: string | undefined;
  let textOutsideCode = text.split("\n").map((line) => {
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1];
    if (fence) {
      if (marker?.[0] === fence[0] && marker.length >= fence.length) fence = undefined;
      return "";
    }
    if (marker) { fence = marker; return ""; }
    return line;
  }).join("\n");

  textOutsideCode = textOutsideCode.replace(/`([^`\n]+)`/g, (_, value: string) => {
    if (!value.includes("](") && (value.includes("/") || value.includes(".") || value.includes("\\"))) add(value, value, "inline");
    return "";
  });
  textOutsideCode = textOutsideCode.replace(
    /!?\[([^\]\n]*)\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+["'][^\n]*?["'])?\s*\)/g,
    (_, label: string, angleHref: string | undefined, href: string | undefined) => {
      add(angleHref ?? href ?? "", label, "markdown");
      return "";
    },
  );
  textOutsideCode = textOutsideCode.replace(/\b[a-z][a-z0-9+.-]*:\/\/\S+/gi, "");
  for (const match of textOutsideCode.matchAll(/(?:[a-z]:[\\/]|\\\\|\.\.?\/|\/)?[\w][\w./\\-]*[\w/]/gi)) {
    const value = match[0];
    if (value.includes("/") || value.includes(".")) add(value, value, "bare");
  }
  return candidates;
}
