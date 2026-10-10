import { describe, expect, it } from "vitest";
import { performanceMessage } from "./performance-mode.js";

const image = { id: "review-screen", url: "/images/review-screen", mimeType: "image/png", thumbnailUrl: "/images/review-screen/thumbnail" };
const toolResult = {
  type: "tool_result", toolUseId: "review", toolName: "mcp:browser/screenshot",
  content: "Captured the review. [Release review](</workspace/reports/Release review.pdf>)\n" + "log output\n".repeat(100_000),
  images: [image], rawContentBlocks: [{ type: "image", source: { data: "large".repeat(100_000) } }],
};
const links = [{ href: "/workspace/reports/Release review.pdf", label: "Release review", syntax: "markdown" }];

describe("performance output artifacts", () => {
  it("keeps only image references and file destinations alongside the completion marker", () => {
    const projected = performanceMessage(toolResult)!;
    expect(projected).toEqual({ type: "tool_result", toolUseId: "review", content: "", images: [image], outputLinkCandidates: links });
    expect(Buffer.byteLength(JSON.stringify(projected))).toBeLessThan(1024);
    expect(projected.rawContentBlocks).toBeUndefined();
    expect(toolResult.content).toContain("log output");
    expect(toolResult.images).toEqual([image]);
  });

  it("retains the same artifact metadata in all restored-history envelopes", () => {
    const marker = { type: "tool_result", toolUseId: "review", content: "", images: [image], outputLinkCandidates: links };
    expect(performanceMessage({ type: "history", messages: [toolResult] })).toEqual({ type: "history", messages: [marker] });
    expect(performanceMessage({ type: "past_history", messages: [{ ...toolResult, type: undefined, role: "tool_result" }] })).toEqual({ type: "past_history", messages: [{ ...marker, type: undefined, role: "tool_result" }] });
    for (const type of ["history_snapshot", "history_delta"]) {
      expect(performanceMessage({ type, fromSeq: 7, toSeq: 7, messages: [{ seq: 7, message: toolResult }] })).toEqual({ type, fromSeq: 7, toSeq: 7, filtered: true, messages: [{ seq: 7, message: marker }] });
    }
  });

  it("retains relative candidates while excluding external links and code examples", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: [
      "Read `reports/summary.md` and README.md.",
      "[Source](lib/main.dart#L42)",
      "[External](https://example.org/report.pdf)",
      "`[Example](./sample.pdf)`",
      "```markdown\n[Example](./example.pdf)\n```",
    ].join("\n") })!;
    expect(projected.outputLinkCandidates).toEqual([
      { href: "reports/summary.md", label: "reports/summary.md", syntax: "inline" },
      { href: "lib/main.dart#L42", label: "Source", syntax: "markdown" },
      { href: "README.md", label: "README.md", syntax: "bare" },
    ]);
    expect(projected.content).toBe("");
  });

  it("keeps the complete absolute destination when collecting bare path candidates", () => {
    const projected = performanceMessage({ type: "tool_result", toolUseId: "report", content: "Output: /workspace/reports/summary.md" })!;
    expect(projected.outputLinkCandidates).toEqual([{ href: "/workspace/reports/summary.md", label: "/workspace/reports/summary.md", syntax: "bare" }]);
  });
});
