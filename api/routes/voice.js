import { Router } from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import { randomUUID } from "crypto";
import { fileURLToPath } from "url";
import OpenAI from "openai";
import Anthropic from "@anthropic-ai/sdk";
import pool from "../db.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = process.env.UPLOADS_DIR || path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: uploadsDir,
  filename: (_req, _file, cb) => {
    cb(null, `${randomUUID()}.m4a`);
  },
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

export const voiceRouter = Router();

// POST /api/voice/transcribe — upload audio, transcribe with Whisper
voiceRouter.post("/transcribe", upload.single("audio"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No audio file provided" });
  }

  const filePath = req.file.path;
  const baseUrl = `${req.protocol}://${req.get("host")}`;
  const audioUrl = `${baseUrl}/api/audio/${req.file.filename}`;

  try {
    const transcription = await transcribeWithWhisper(filePath);
    res.json({ transcription, audio_url: audioUrl });
  } catch (err) {
    console.error("Transcription error:", err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/voice/format — format transcription with Claude and save note
voiceRouter.post("/format", async (req, res) => {
  const { transcription, audio_url } = req.body;
  if (!transcription) {
    return res.status(400).json({ error: "No transcription provided" });
  }

  try {
    const formattedHTML = await formatWithClaude(transcription);
    const title = extractTitle(formattedHTML, transcription);

    const result = await pool.query(
      `INSERT INTO notes (title, content, is_voice_note, audio_url, transcription_raw)
       VALUES ($1, $2, true, $3, $4)
       RETURNING *`,
      [title, formattedHTML, audio_url || null, transcription]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Format error:", err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/voice/format-text — format transcription, return HTML only (no DB save)
voiceRouter.post("/format-text", async (req, res) => {
  const { transcription } = req.body;
  if (!transcription) {
    return res.status(400).json({ error: "No transcription provided" });
  }

  try {
    const html = await formatWithClaude(transcription, true);
    res.json({ html });
  } catch (err) {
    console.error("Format-text error:", err);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/voice/normalize — clean up and normalize existing HTML content
voiceRouter.post("/normalize", async (req, res) => {
  const { html } = req.body;
  console.log("[normalize] Request received, HTML length:", html?.length || 0);
  if (!html) {
    return res.status(400).json({ error: "No HTML content provided" });
  }

  try {
    let result = programmaticNormalize(html);
    console.log("[normalize] After programmatic fix, length:", result.length);
    result = await normalizeWithClaude(result);
    console.log("[normalize] After Claude, result length:", result.length);
    res.json({ html: result });
  } catch (err) {
    console.error("[normalize] Error:", err);
    res.status(500).json({ error: err.message });
  }
});

async function transcribeWithWhisper(filePath) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  const openai = new OpenAI({ apiKey });
  const response = await openai.audio.transcriptions.create({
    file: fs.createReadStream(filePath),
    model: "whisper-1",
    language: "ru",
    response_format: "text",
  });

  return response;
}

async function formatWithClaude(transcription, appendMode = false) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

  const prompt = appendMode
    ? `Ты помощник для форматирования заметок. Тебе дана транскрипция голосового дополнения к существующей заметке.
Твоя задача — превратить её в красиво отформатированный фрагмент HTML.

Правила:
- НЕ добавляй заголовки (<h1>, <h2>) — это дополнение, не новая заметка
- Разбей текст на логические абзацы (<p>)
- Если есть перечисления или списки, используй <ul>/<ol> с <li>
- Важные мысли выдели жирным (<strong>) или курсивом (<em>)
- Ключевые слова/термины можно выделить маркером (<mark>)
- Если есть цитаты, используй <blockquote>
- Исправь грамматические ошибки транскрипции
- НЕ добавляй информацию от себя, только форматируй то что есть
- Отвечай ТОЛЬКО HTML кодом, без обёрток в \`\`\` или пояснений

Транскрипция:
${transcription}`
    : `Ты помощник для форматирования заметок. Тебе дана транскрипция голосовой заметки. 
Твоя задача — превратить её в красиво отформатированную заметку в HTML формате.

Правила:
- Определи основную тему и сделай её заголовком (<h2>)
- Разбей текст на логические абзацы (<p>)
- Если есть перечисления или списки, используй <ul>/<ol> с <li>
- Важные мысли выдели жирным (<strong>) или курсивом (<em>)
- Ключевые слова/термины можно выделить маркером (<mark>)
- Если есть цитаты или ссылки на кого-то, используй <blockquote>
- Исправь грамматические ошибки транскрипции
- НЕ добавляй информацию от себя, только форматируй то что есть
- Отвечай ТОЛЬКО HTML кодом, без обёрток в \`\`\` или пояснений

Транскрипция:
${transcription}`;

  const anthropic = new Anthropic({ apiKey });
  const model = process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514";
  const message = await anthropic.messages.create({
    model,
    max_tokens: 4096,
    messages: [{ role: "user", content: prompt }],
  });

  let text = message.content[0].text;
  text = text.replace(/^```html?\s*/i, "").replace(/\s*```\s*$/, "");
  return text.trim();
}

function programmaticNormalize(html) {
  let result = html;

  // Fix: <ul><li><ul><li>text</li></ul></li></ul> → <ul><li>text</li></ul>
  // Flatten pointless single-child nested lists (up to 5 levels deep)
  for (let i = 0; i < 5; i++) {
    result = result.replace(
      /<ul[^>]*>\s*<li[^>]*>\s*<ul[^>]*>([\s\S]*?)<\/ul>\s*<\/li>\s*<\/ul>/gi,
      "<ul>$1</ul>"
    );
  }

  // Fix: <li><ul><li>text</li></ul></li> → <li>text</li> (nested list inside li with no other content)
  for (let i = 0; i < 5; i++) {
    result = result.replace(
      /<li[^>]*>\s*<ul[^>]*>\s*<li([^>]*)>([\s\S]*?)<\/li>\s*<\/ul>\s*<\/li>/gi,
      "<li$1>$2</li>"
    );
  }

  // Remove empty <p></p>, <p><br></p>, <p>&nbsp;</p>
  result = result.replace(/<p[^>]*>\s*(<br\s*\/?>|\s|&nbsp;)*\s*<\/p>/gi, "");

  // Remove empty <li></li>
  result = result.replace(/<li[^>]*>\s*<\/li>/gi, "");

  // Remove empty <ul></ul> or <ol></ol>
  result = result.replace(/<(ul|ol)[^>]*>\s*<\/(ul|ol)>/gi, "");

  // Collapse multiple <br> into single
  result = result.replace(/(<br\s*\/?\s*>){2,}/gi, "<br>");

  // Remove excessive whitespace between tags
  result = result.replace(/>\s{3,}</g, "> <");

  return result;
}

async function normalizeWithClaude(htmlContent) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

  const prompt = `Нормализуй HTML-форматирование заметки. Верни ТОЛЬКО исправленный HTML без обёрток и пояснений.

ПРАВИЛА:
1. Если <ul> содержит только один <li> с вложенным <ul> — развернуть, убрать лишний уровень вложенности
2. Пример: <ul><li><ul><li>текст</li></ul></li></ul> → <ul><li>текст</li></ul>  
3. Убрать пустые <p>, <li>, <ul>, <ol>
4. Убрать лишние <br> подряд
5. НЕ менять текст, заголовки, <b>, <i>, <mark>, <img>, <table>, <span>
6. НЕ добавлять и НЕ удалять контент

HTML:
${htmlContent}`;

  const anthropic = new Anthropic({ apiKey });
  const model = process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514";
  const message = await anthropic.messages.create({
    model,
    max_tokens: 4096,
    messages: [{ role: "user", content: prompt }],
  });

  let text = message.content[0].text;
  text = text.replace(/^```html?\s*/i, "").replace(/\s*```\s*$/, "");
  return text.trim();
}

function extractTitle(html, rawText) {
  const h2Match = html.match(/<h2[^>]*>(.*?)<\/h2>/i);
  if (h2Match) {
    return h2Match[1].replace(/<[^>]+>/g, "").trim();
  }
  const clean = rawText.trim();
  if (clean.length <= 60) return clean;
  return clean.substring(0, 57) + "...";
}
