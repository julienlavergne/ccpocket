export interface OutputLinkCandidate {
  href: string;
  syntax: "markdown" | "inline" | "bare";
}

const MAX_CANDIDATES = 32;
const MAX_PATH_LENGTH = 256;
const MAX_METADATA_BYTES = 8 * 1024;
const MAX_TEXT_LENGTH = 4 * 1024 * 1024;
const candidateCache = new WeakMap<object, { content: string; links: OutputLinkCandidate[] }>();

/** Shared history objects are projected independently for each connected client. */
export function outputLinkCandidatesForMessage(message: { content?: unknown }): OutputLinkCandidate[] {
  if (typeof message.content !== "string") return [];
  const cached = candidateCache.get(message);
  if (cached?.content === message.content) return cached.links;
  const links = extractOutputLinkCandidates(message.content);
  candidateCache.set(message, { content: message.content, links });
  return links;
}

function extractOutputLinkCandidates(text: string): OutputLinkCandidate[] {
  const candidates: OutputLinkCandidate[] = [];
  const seen = new Set<string>();
  let metadataBytes = 2;
  const add = (href: string, syntax: OutputLinkCandidate["syntax"]) => {
    if (candidates.length >= MAX_CANDIDATES || href.length > MAX_PATH_LENGTH) return;
    if (!href || href.startsWith("#") || href.endsWith("/")) return;
    if (/^[a-z][a-z0-9+.-]*:/i.test(href) && !/^file:/i.test(href) && !/^[a-z]:[\\/]/i.test(href)) return;
    if (href.startsWith("//")) return;
    const key = `${syntax}:${href}`;
    if (seen.has(key)) return;
    const candidate = { href, syntax };
    const bytes = Buffer.byteLength(JSON.stringify(candidate)) + 1;
    if (metadataBytes + bytes > MAX_METADATA_BYTES) return;
    metadataBytes += bytes;
    seen.add(key);
    candidates.push(candidate);
  };

  let fence: string | undefined;
  let textOutsideCode = text.slice(0, MAX_TEXT_LENGTH).split("\n").map((line) => {
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1];
    if (fence) {
      if (marker?.[0] === fence[0] && marker.length >= fence.length) fence = undefined;
      return "";
    }
    if (marker) { fence = marker; return ""; }
    if (/^(?: {4}|\t)/.test(line)) return "";
    return line;
  }).join("\n");

  textOutsideCode = textOutsideCode.replace(/`([^`\n]+)`/g, (_, value: string) => {
    if (!value.includes("](") && (value.includes("/") || value.includes(".") || value.includes("\\"))) add(value, "inline");
    return "";
  });
  textOutsideCode = textOutsideCode.replace(
    /!?\[([^\]\n]*)\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+["'][^\n]*?["'])?\s*\)/g,
    (_, _label: string, angleHref: string | undefined, href: string | undefined) => {
      add(angleHref ?? href ?? "", "markdown");
      return "";
    },
  );
  textOutsideCode = textOutsideCode.replace(/\b[a-z][a-z0-9+.-]*:\/\/\S+/gi, "");
  for (const match of textOutsideCode.matchAll(/(?:[a-z]:[\\/]|\\\\|\.\.?\/|\/)?[\w][\w./\\-]*[\w/]/gi)) {
    const value = match[0];
    if (value.includes("/") || value.includes(".")) add(value, "bare");
  }
  return candidates;
}
