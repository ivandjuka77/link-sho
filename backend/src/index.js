import express from "express";
import pg from "pg";

const { Pool } = pg;
const app = express();
const port = process.env.PORT || 3000;

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Create the schema on boot so the app is self-contained.
async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS links (
      id SERIAL PRIMARY KEY,
      code TEXT UNIQUE NOT NULL,
      url TEXT NOT NULL,
      hits INTEGER NOT NULL DEFAULT 0,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

app.use(express.json());

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok" });
  } catch (err) {
    res.status(503).json({ status: "error", error: err.message });
  }
});

// Shorten a URL.
app.post("/shorten", async (req, res) => {
  const { url } = req.body || {};
  if (!url) return res.status(400).json({ error: "url is required" });

  const code = Math.random().toString(36).slice(2, 8);
  const { rows } = await pool.query(
    "INSERT INTO links (code, url) VALUES ($1, $2) RETURNING code, url, hits",
    [code, url]
  );
  res.status(201).json(rows[0]);
});

// List all links (for the frontend table).
app.get("/links", async (_req, res) => {
  const { rows } = await pool.query(
    "SELECT code, url, hits FROM links ORDER BY id DESC"
  );
  res.json(rows);
});

// Redirect + log a hit.
app.get("/:code", async (req, res) => {
  const { rows } = await pool.query(
    "UPDATE links SET hits = hits + 1 WHERE code = $1 RETURNING url",
    [req.params.code]
  );
  if (!rows.length) return res.status(404).json({ error: "not found" });
  res.redirect(rows[0].url);
});

init()
  .then(() => app.listen(port, () => console.log(`listening on ${port}`)))
  .catch((err) => {
    console.error("failed to start", err);
    process.exit(1);
  });
