import { Router } from "express";
import pool from "../db.js";

export const notesRouter = Router();

// GET /api/notes — list notes, optional ?folder_id=...&search=...&sort_by_order=true
notesRouter.get("/", async (req, res) => {
  try {
    const { folder_id, search, sort_by_order } = req.query;
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

    query +=
      sort_by_order === "true"
        ? " ORDER BY sort_order ASC, created_at ASC"
        : " ORDER BY created_at DESC";

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
    const {
      title,
      content,
      folder_id,
      is_voice_note,
      audio_url,
      transcription_raw,
      sort_order,
      synopsis,
      status,
      word_count,
    } = req.body;
    const result = await pool.query(
      `INSERT INTO notes (title, content, folder_id, is_voice_note, audio_url,
       transcription_raw, sort_order, synopsis, status, word_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        title || "",
        content || "",
        folder_id || null,
        is_voice_note || false,
        audio_url || null,
        transcription_raw || null,
        sort_order ?? 0,
        synopsis || "",
        status || "draft",
        word_count ?? 0,
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
    const {
      title,
      content,
      folder_id,
      is_voice_note,
      audio_url,
      transcription_raw,
      sort_order,
      synopsis,
      status,
      word_count,
    } = req.body;
    const result = await pool.query(
      `UPDATE notes
       SET title = COALESCE($1, title),
           content = COALESCE($2, content),
           folder_id = $3,
           is_voice_note = COALESCE($4, is_voice_note),
           audio_url = COALESCE($5, audio_url),
           transcription_raw = COALESCE($6, transcription_raw),
           sort_order = COALESCE($7, sort_order),
           synopsis = COALESCE($8, synopsis),
           status = COALESCE($9, status),
           word_count = COALESCE($10, word_count)
       WHERE id = $11
       RETURNING *`,
      [
        title,
        content,
        folder_id,
        is_voice_note,
        audio_url,
        transcription_raw,
        sort_order,
        synopsis,
        status,
        word_count,
        req.params.id,
      ]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Note not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/notes/reorder — batch update sort_order
notesRouter.put("/reorder/batch", async (req, res) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items)) {
      return res.status(400).json({ error: "items array required" });
    }
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      for (const item of items) {
        await client.query(
          "UPDATE notes SET sort_order = $1 WHERE id = $2",
          [item.sort_order, item.id]
        );
      }
      await client.query("COMMIT");
      res.json({ updated: items.length });
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/books/:id/stats — book statistics
notesRouter.get("/book-stats/:bookId", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        COUNT(*)::int AS chapter_count,
        COALESCE(SUM(word_count), 0)::int AS total_words,
        COUNT(*) FILTER (WHERE status = 'final')::int AS completed_chapters,
        COUNT(*) FILTER (WHERE status = 'draft')::int AS draft_chapters,
        COUNT(*) FILTER (WHERE status = 'in_progress')::int AS in_progress_chapters,
        COUNT(*) FILTER (WHERE status = 'revised')::int AS revised_chapters
      FROM notes WHERE folder_id = $1`,
      [req.params.bookId]
    );
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
