import pg from "pg";

if (!process.env.DATABASE_URL) {
  console.error("DATABASE_URL environment variable is required");
  process.exit(1);
}

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false,
});

pool.on("error", (err) => {
  console.error("Unexpected pool error:", err);
});

export default pool;
