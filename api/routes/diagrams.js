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

const DIAGRAM_TYPES = {
  auto: "Choose the best diagram type automatically based on the content.",
  flowchart: "Use flowchart TD (top-down). Good for processes, algorithms, business flows.",
  sequence: "Use sequenceDiagram. Good for interactions between actors/services/systems.",
  class: "Use classDiagram. Good for data structures, object models.",
  state: "Use stateDiagram-v2. Good for state machines, lifecycle stages.",
  er: "Use erDiagram. Good for database schemas, entity relationships.",
  gantt: "Use gantt. Good for timelines, project plans.",
  mindmap: "Use mindmap. Good for hierarchical concepts, brainstorming.",
  pie: "Use pie. Good for distributions, proportions.",
};

const MERMAID_PROMPT = `You are a diagram generator. Convert the user's description into a Mermaid diagram.

Rules:
- Output ONLY valid Mermaid code, no markdown fences, no explanation
- Use Russian text in node labels when the input is in Russian
- Keep it clean and readable — avoid overly complex layouts
- Use descriptive node IDs (A, B, C... or meaningful short names)
- Add styling where appropriate (colors, shapes)
- For flowcharts: use rounded boxes for start/end, diamonds for decisions, rectangles for processes
- The user may provide raw text/notes — analyze them and extract the structure for the diagram`;

diagramsRouter.post("/generate", async (req, res) => {
  const { description, type } = req.body;
  if (!description || !description.trim()) {
    return res.status(400).json({ error: "No description provided" });
  }

  const diagramType = type && DIAGRAM_TYPES[type] ? type : "auto";
  const typeHint = DIAGRAM_TYPES[diagramType];

  console.log("[diagram] Generating for:", description.substring(0, 100), "type:", diagramType);

  try {
    const systemPrompt = `${MERMAID_PROMPT}\n\nDiagram type instruction: ${typeHint}`;

    const modelName = process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514";
    const response = await anthropic.messages.create({
      model: modelName,
      max_tokens: 2048,
      system: systemPrompt,
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
