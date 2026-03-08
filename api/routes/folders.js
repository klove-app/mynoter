import { Router } from "express";
import pool from "../db.js";

export const foldersRouter = Router();

// GET /api/folders
foldersRouter.get("/", async (_req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM folders ORDER BY name ASC"
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/folders
foldersRouter.post("/", async (req, res) => {
  try {
    const { name, parent_id } = req.body;
    if (!name) {
      return res.status(400).json({ error: "name is required" });
    }
    const result = await pool.query(
      `INSERT INTO folders (name, parent_id) VALUES ($1, $2) RETURNING *`,
      [name, parent_id || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PUT /api/folders/:id
foldersRouter.put("/:id", async (req, res) => {
  try {
    const { name, parent_id } = req.body;
    const result = await pool.query(
      `UPDATE folders SET name = COALESCE($1, name), parent_id = $2 WHERE id = $3 RETURNING *`,
      [name, parent_id, req.params.id]
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
