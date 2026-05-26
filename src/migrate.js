const { runMigrations } = require('./database');

async function migrate() {
    try {
        await runMigrations();
        console.log("Migration successful");
        process.exit(0);
    } catch (e) {
        console.error("Migration failed:", e);
        process.exit(1);
    }
}

migrate();