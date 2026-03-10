import { Router } from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import { randomUUID } from "crypto";
import { fileURLToPath } from "url";
import sharp from "sharp";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir =
  process.env.UPLOADS_DIR
    ? path.join(process.env.UPLOADS_DIR, "images")
    : path.join(__dirname, "..", "uploads", "images");

if (!fs.existsSync(imagesDir)) fs.mkdirSync(imagesDir, { recursive: true });

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const allowed = ["image/jpeg", "image/png", "image/gif", "image/webp"];
    cb(null, allowed.includes(file.mimetype));
  },
});

export const imagesRouter = Router();

// POST /api/images/upload
imagesRouter.post("/upload", upload.single("image"), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: "No image file provided" });
  }

  try {
    const ext = req.file.mimetype === "image/png" ? "png"
      : req.file.mimetype === "image/gif" ? "gif"
      : req.file.mimetype === "image/webp" ? "webp"
      : "jpg";

    const filename = `${randomUUID()}.${ext}`;
    const outputPath = path.join(imagesDir, filename);

    let pipeline = sharp(req.file.buffer);
    const meta = await pipeline.metadata();

    const MAX_DIM = 2000;
    if (meta.width > MAX_DIM || meta.height > MAX_DIM) {
      pipeline = pipeline.resize(MAX_DIM, MAX_DIM, { fit: "inside", withoutEnlargement: true });
    }

    if (ext === "jpg") {
      pipeline = pipeline.jpeg({ quality: 85 });
    } else if (ext === "png") {
      pipeline = pipeline.png({ compressionLevel: 8 });
    } else if (ext === "webp") {
      pipeline = pipeline.webp({ quality: 85 });
    }

    await pipeline.toFile(outputPath);

    const baseUrl = `${req.protocol}://${req.get("host")}`;
    const url = `${baseUrl}/api/images/${filename}`;

    const stats = fs.statSync(outputPath);
    res.status(201).json({
      filename,
      url,
      width: meta.width > MAX_DIM ? MAX_DIM : meta.width,
      height: meta.height > MAX_DIM
        ? Math.round(meta.height * (MAX_DIM / meta.width))
        : meta.height,
      size: stats.size,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/images/:filename
imagesRouter.get("/:filename", (req, res) => {
  const filePath = path.join(imagesDir, req.params.filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "Image not found" });
  }
  res.sendFile(filePath);
});

// DELETE /api/images/:filename
imagesRouter.delete("/:filename", (req, res) => {
  const filePath = path.join(imagesDir, req.params.filename);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: "Image not found" });
  }
  try {
    fs.unlinkSync(filePath);
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
