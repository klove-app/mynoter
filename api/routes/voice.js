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
const uploadsDir = path.join(__dirname, "..", "uploads");

const storage = multer.diskStorage({
  destination: uploadsDir,
  filename: (_req, _file, cb) => {
    cb(null, `${randomUUID()}.m4a`);
  },
});
const upload = multer({ storage, limits: { fileSize: 50 * 1024 * 1024 } });

export const voiceRouter = Router();

// POST /api/voice/process — upload audio, transcribe (Whisper), format (Claude), save note
voiceRouter.post("/process", upload.single("audio"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No audio file provided" });
  }

  const filePath = req.file.path;
  const baseUrl = `${req.protocol}://${req.get("host")}`;
  const audioUrl = `${baseUrl}/api/audio/${req.file.filename}`;

  try {
    // 1. Transcribe with Whisper
    const transcription = await transcribeWithWhisper(filePath);

    // 2. Format with Claude
    const formattedHTML = await formatWithClaude(transcription);

    // 3. Extract title
    const title = extractTitle(formattedHTML, transcription);

    // 4. Save to DB
    const result = await pool.query(
      `INSERT INTO notes (title, content, is_voice_note, audio_url, transcription_raw)
       VALUES ($1, $2, true, $3, $4)
       RETURNING *`,
      [title, formattedHTML, audioUrl, transcription]
    );

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Voice processing error:", err);
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

async function formatWithClaude(transcription) {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) throw new Error("ANTHROPIC_API_KEY not set");

  const anthropic = new Anthropic({ apiKey });
  const message = await anthropic.messages.create({
    model: "claude-3-5-haiku-20241022",
    max_tokens: 4096,
    messages: [
      {
        role: "user",
        content: `Ты помощник для форматирования заметок. Тебе дана транскрипция голосовой заметки. 
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
${transcription}`,
      },
    ],
  });

  return message.content[0].text;
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
