import { Router } from "express";
import multer from "multer";
import path from "path";
import { randomUUID } from "crypto";
import { fileURLToPath } from "url";

import fs from "fs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = process.env.UPLOADS_DIR || path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

const storage = multer.diskStorage({
  destination: uploadsDir,
  filename: (_req, _file, cb) => {
    cb(null, `${randomUUID()}.m4a`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 },
});

export const audioRouter = Router();

// POST /api/audio/upload — upload audio file, returns { filename, url }
audioRouter.post("/upload", upload.single("audio"), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No audio file provided" });
  }

  const baseUrl = `${req.protocol}://${req.get("host")}`;
  const url = `${baseUrl}/api/audio/${req.file.filename}`;

  res.json({
    filename: req.file.filename,
    url,
  });
});

// GET /api/audio/:filename — serve audio file
audioRouter.get("/:filename", (req, res) => {
  const filePath = path.join(uploadsDir, req.params.filename);
  res.sendFile(filePath, (err) => {
    if (err) {
      res.status(404).json({ error: "Audio file not found" });
    }
  });
});
