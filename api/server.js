import express from "express";
import cors from "cors";
import { notesRouter } from "./routes/notes.js";
import { foldersRouter } from "./routes/folders.js";
import { voiceRouter } from "./routes/voice.js";
import { audioRouter } from "./routes/audio.js";
import { tagsRouter } from "./routes/tags.js";
import { imagesRouter } from "./routes/images.js";
import { diagramsRouter } from "./routes/diagrams.js";
import { proofRouter } from "./routes/proof.js";
import pool from "./db.js";

const app = express();
const PORT = process.env.PORT || 3000;

app.set("trust proxy", true);
app.use(cors());
app.use(express.json({ limit: "50mb" }));

app.use("/api/notes", notesRouter);
app.use("/api/folders", foldersRouter);
app.use("/api/voice", voiceRouter);
app.use("/api/audio", audioRouter);
app.use("/api/tags", tagsRouter);
app.use("/api/images", imagesRouter);
app.use("/api/diagrams", diagramsRouter);
app.use("/api/proof", proofRouter);

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok", db: "connected" });
  } catch (err) {
    res.status(500).json({ status: "error", db: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`API server running on port ${PORT}`);
});
