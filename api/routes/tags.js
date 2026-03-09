import { Router } from "express";
import pool from "../db.js";

export const tagsRouter = Router();

// GET /api/tags — all tags
tagsRouter.get("/", async (_req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM tags ORDER BY name ASC"
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/tags — create tag
tagsRouter.post("/", async (req, res) => {
  try {
    const { name, color } = req.body;
    if (!name) return res.status(400).json({ error: "name is required" });
    const result = await pool.query(
      "INSERT INTO tags (name, color) VALUES ($1, $2) RETURNING *",
      [name, color || "blue"]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/tags/:id — update tag
tagsRouter.put("/:id", async (req, res) => {
  try {
    const { name, color } = req.body;
    const result = await pool.query(
      "UPDATE tags SET name = COALESCE($1, name), color = COALESCE($2, color) WHERE id = $3 RETURNING *",
      [name, color, req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Tag not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/tags/:id — delete tag
tagsRouter.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM tags WHERE id = $1 RETURNING id",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Tag not found" });
    }
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/tags/note/:noteId — tags for a note
tagsRouter.get("/note/:noteId", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT t.* FROM tags t
       JOIN note_tags nt ON nt.tag_id = t.id
       WHERE nt.note_id = $1
       ORDER BY t.name ASC`,
      [req.params.noteId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/tags/note/:noteId — add tag to note
tagsRouter.post("/note/:noteId", async (req, res) => {
  try {
    const { tag_id } = req.body;
    if (!tag_id) return res.status(400).json({ error: "tag_id is required" });
    await pool.query(
      "INSERT INTO note_tags (note_id, tag_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      [req.params.noteId, tag_id]
    );
    const result = await pool.query(
      `SELECT t.* FROM tags t
       JOIN note_tags nt ON nt.tag_id = t.id
       WHERE nt.note_id = $1
       ORDER BY t.name ASC`,
      [req.params.noteId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/tags/note/:noteId/:tagId — remove tag from note
tagsRouter.delete("/note/:noteId/:tagId", async (req, res) => {
  try {
    await pool.query(
      "DELETE FROM note_tags WHERE note_id = $1 AND tag_id = $2",
      [req.params.noteId, req.params.tagId]
    );
    const result = await pool.query(
      `SELECT t.* FROM tags t
       JOIN note_tags nt ON nt.tag_id = t.id
       WHERE nt.note_id = $1
       ORDER BY t.name ASC`,
      [req.params.noteId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/tags/:tagId/notes — notes with specific tag
tagsRouter.get("/:tagId/notes", async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT n.* FROM notes n
       JOIN note_tags nt ON nt.note_id = n.id
       WHERE nt.tag_id = $1
       ORDER BY n.created_at DESC`,
      [req.params.tagId]
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
