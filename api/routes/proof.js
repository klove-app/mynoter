import { Router } from "express";
import Anthropic from "@anthropic-ai/sdk";

export const proofRouter = Router();

const anthropic = new Anthropic();

const PROOF_SYSTEM_PROMPT = `You are a fact-checking and research assistant. The user gives you a claim, hypothesis, or statement (usually in Russian). Your task:

1. Analyze the claim for factual accuracy
2. Find supporting OR refuting evidence from well-known reputable sources
3. Generate EXACTLY 3 text variants that present verified information on this topic:
   - Variant 1 (brief): 1-2 sentences, the most concise fact-based statement
   - Variant 2 (detailed): 3-4 sentences with more context and nuance
   - Variant 3 (with quote/data): includes a specific statistic, study finding, or notable quote

For each variant, include 2-3 real source references. Use only reputable, verifiable sources:
- Wikipedia (use real article URLs like https://en.wikipedia.org/wiki/Topic or https://ru.wikipedia.org/wiki/Тема)
- Major scientific journals, institutions (NIH, WHO, NASA, etc.)
- Well-known reputable publications (Nature, Science, BBC, Reuters, etc.)
- Government/official statistical sources

IMPORTANT: Only cite sources that you are highly confident actually exist at those URLs. Prefer Wikipedia for general facts as URLs are predictable and reliable.

Respond ONLY in JSON (no markdown), in this exact format:
{
  "verdict": "confirmed|refuted|nuanced|unverifiable",
  "verdict_explanation": "Brief explanation of the verdict in the same language as the claim",
  "variants": [
    {
      "id": "brief",
      "label": "Кратко",
      "text": "The fact-based statement text here...",
      "sources": [
        { "title": "Source title", "url": "https://..." },
        { "title": "Source title 2", "url": "https://..." }
      ]
    },
    {
      "id": "detailed",
      "label": "Подробно",
      "text": "...",
      "sources": [...]
    },
    {
      "id": "with_data",
      "label": "С данными",
      "text": "...",
      "sources": [...]
    }
  ]
}

Write variant texts in the SAME LANGUAGE as the input claim. If claim is in Russian — write in Russian. If in English — write in English.`;

proofRouter.post("/check", async (req, res) => {
  const { claim } = req.body;
  if (!claim || !claim.trim()) {
    return res.status(400).json({ error: "No claim provided" });
  }

  console.log("[proof] Checking claim:", claim.substring(0, 100));

  try {
    const modelName = process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514";
    const response = await anthropic.messages.create({
      model: modelName,
      max_tokens: 3000,
      system: PROOF_SYSTEM_PROMPT,
      messages: [{ role: "user", content: claim }],
    });

    let raw = response.content[0]?.text?.trim() || "";

    raw = raw
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (parseErr) {
      console.error("[proof] JSON parse error:", parseErr, "raw:", raw.substring(0, 300));
      return res.status(500).json({ error: "Failed to parse AI response" });
    }

    if (!parsed.variants || !Array.isArray(parsed.variants)) {
      return res.status(500).json({ error: "Invalid AI response structure" });
    }

    console.log("[proof] Verdict:", parsed.verdict, "| variants:", parsed.variants.length);
    res.json(parsed);
  } catch (err) {
    console.error("[proof] Error:", err);
    res.status(500).json({ error: err.message });
  }
});
