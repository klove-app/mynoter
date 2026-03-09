import { Router } from "express";
import pool from "../db.js";

export const foldersRouter = Router();

// GET /api/folders (with note counts + word counts for books)
foldersRouter.get("/", async (req, res) => {
  try {
    const { type } = req.query;
    let query = `
      SELECT f.*,
        COALESCE(cnt.c, 0)::int AS note_count,
        COALESCE(cnt.total_words, 0)::int AS total_word_count
      FROM folders f
      LEFT JOIN (
        SELECT folder_id,
          COUNT(*) AS c,
          SUM(word_count) AS total_words
        FROM notes GROUP BY folder_id
      ) cnt ON f.id = cnt.folder_id`;

    const params = [];
    if (type) {
      params.push(type);
      query += ` WHERE f.type = $${params.length}`;
    }
    query += ` ORDER BY f.name ASC`;

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/folders
foldersRouter.post("/", async (req, res) => {
  try {
    const { name, parent_id, type, description, target_word_count, genre } =
      req.body;
    if (!name) {
      return res.status(400).json({ error: "name is required" });
    }
    const result = await pool.query(
      `INSERT INTO folders (name, parent_id, type, description, target_word_count, genre)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [
        name,
        parent_id || null,
        type || "folder",
        description || "",
        target_word_count || null,
        genre || "",
      ]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/folders/:id
foldersRouter.put("/:id", async (req, res) => {
  try {
    const { name, parent_id, type, description, target_word_count, genre } =
      req.body;
    const result = await pool.query(
      `UPDATE folders
       SET name = COALESCE($1, name),
           parent_id = $2,
           type = COALESCE($3, type),
           description = COALESCE($4, description),
           target_word_count = $5,
           genre = COALESCE($6, genre)
       WHERE id = $7 RETURNING *`,
      [
        name,
        parent_id,
        type,
        description,
        target_word_count,
        genre,
        req.params.id,
      ]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Folder not found" });
    }
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/folders/:id
foldersRouter.delete("/:id", async (req, res) => {
  try {
    const result = await pool.query(
      "DELETE FROM folders WHERE id = $1 RETURNING id",
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Folder not found" });
    }
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});
