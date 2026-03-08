import { Router } from "express";
import pool from "../db.js";

export const notesRouter = Router();

// GET /api/notes — list notes, optional ?folder_id=...&search=...
notesRouter.get("/", async (req, res) => {
  try {
    const { folder_id, search } = req.query;
    let query = "SELECT * FROM notes";
    const params = [];
    const conditions = [];

    if (folder_id) {
      params.push(folder_id);
      conditions.push(`folder_id = $${params.length}`);
    }

    if (search) {
      params.push(`%${search}%`);
      conditions.push(
        `(title ILIKE $${params.length} OR content ILIKE $${params.length})`
      );
    }

    if (conditions.length > 0) {
      query += " WHERE " + conditions.join(" AND ");
    }

    query += " ORDER BY created_at DESC";

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/notes/:id
notesRouter.get("/:id", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM notes WHERE id = $1", [
      req.params.id,
    ]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Note not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/notes
notesRouter.post("/", async (req, res) => {
  try {
    const { title, content, folder_id, is_voice_note, audio_url, transcription_raw } = req.body;
    const result = await pool.query(
      `INSERT INTO notes (title, content, folder_id, is_voice_note, audio_url, transcription_raw)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        title || "",
        content || "",
        folder_id || null,
        is_voice_note || false,
        audio_url || null,
        transcription_raw || null,
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/notes/:id
notesRouter.put("/:id", async (req, res) => {
  try {
    const { title, content, folder_id, is_voice_note, audio_url, transcription_raw } = req.body;
    const result = await pool.query(
      `UPDATE notes
       SET title = COALESCE($1, title),
           content = COALESCE($2, content),
           folder_id = $3,
           is_voice_note = COALESCE($4, is_voice_note),
           audio_url = COALESCE($5, audio_url),
           transcription_raw = COALESCE($6, transcription_raw)
       WHERE id = $7
       RETURNING *`,
      [title, content, folder_id, is_voice_note, audio_url, transcription_raw, req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Note not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/notes/:id
notesRouter.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM notes WHERE id = $1 RETURNING id",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Note not found" });
    }
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
