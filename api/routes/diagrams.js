import { Router } from "express";
import path from "path";
import fs from "fs";
import { randomUUID } from "crypto";
import { fileURLToPath } from "url";
import Anthropic from "@anthropic-ai/sdk";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir =
  process.env.UPLOADS_DIR
    ? path.join(process.env.UPLOADS_DIR, "images")
    : path.join(__dirname, "..", "uploads", "images");

if (!fs.existsSync(imagesDir)) fs.mkdirSync(imagesDir, { recursive: true });

export const diagramsRouter = Router();

const anthropic = new Anthropic();

const MERMAID_PROMPT = `You are a diagram generator. Convert the user's description into a Mermaid diagram.

Rules:
- Output ONLY valid Mermaid code, no markdown fences, no explanation
- Choose the best diagram type for the description:
  - flowchart TD/LR for processes and flows
  - sequenceDiagram for interactions between actors
  - classDiagram for data structures
  - stateDiagram-v2 for state machines
  - gantt for timelines
  - erDiagram for database schemas
  - pie for distributions
  - mindmap for hierarchical concepts
- Use Russian text in node labels when the input is in Russian
- Keep it clean and readable — avoid overly complex layouts
- Use descriptive node IDs (A, B, C... or meaningful short names)
- Add styling where appropriate (colors, shapes)
- For flowcharts: use rounded boxes for start/end, diamonds for decisions, rectangles for processes`;

diagramsRouter.post("/generate", async (req, res) => {
  const { description } = req.body;
  if (!description || !description.trim()) {
    return res.status(400).json({ error: "No description provided" });
  }

  console.log("[diagram] Generating for:", description.substring(0, 100));

  try {
    const modelName = process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514";
    const response = await anthropic.messages.create({
      model: modelName,
      max_tokens: 2048,
      system: MERMAID_PROMPT,
      messages: [{ role: "user", content: description }],
    });

    let mermaidCode = response.content[0]?.text?.trim() || "";

    mermaidCode = mermaidCode
      .replace(/^```mermaid\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    if (!mermaidCode) {
      return res.status(500).json({ error: "Failed to generate diagram code" });
    }

    console.log("[diagram] Mermaid code:", mermaidCode.substring(0, 200));

    const encoded = Buffer.from(mermaidCode, "utf-8").toString("base64url");
    const mermaidUrl = `https://mermaid.ink/img/${encoded}?type=png&bgColor=ffffff&width=1200`;

    const imgResponse = await fetch(mermaidUrl);
    if (!imgResponse.ok) {
      console.error("[diagram] mermaid.ink error:", imgResponse.status, await imgResponse.text().catch(() => ""));
      return res.status(500).json({
        error: "Failed to render diagram",
        mermaidCode,
      });
    }

    const buffer = Buffer.from(await imgResponse.arrayBuffer());
    const filename = `diagram-${randomUUID()}.png`;
    const outputPath = path.join(imagesDir, filename);
    fs.writeFileSync(outputPath, buffer);

    const baseUrl = `${req.protocol}://${req.get("host")}`;
    const url = `${baseUrl}/api/images/${filename}`;

    console.log("[diagram] Saved:", filename, "size:", buffer.length);

    res.json({
      url,
      mermaidCode,
      filename,
    });
  } catch (err) {
    console.error("[diagram] Error:", err);
    res.status(500).json({ error: err.message });
  }
});
