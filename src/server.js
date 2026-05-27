const { app, runMigrations } = require('../app');

async function startServer() {
    const MAX_RETRIES = 10;
    let retries = 0;

    while (retries < MAX_RETRIES) {
        try {
            console.log(`Attempting to run migrations (try ${retries + 1})...`);
            await runMigrations();
            console.log('Database is ready and migrated.');
            
            app.listen(8000, () => {
                console.log('Server is running on port 8000...');
            });
            return;
        } catch (err) {
            retries++;
            console.error(`Database connection failed. Retrying in 3 seconds... (${err.message})`);
            await new Promise(res => setTimeout(res, 3000));
        }
    }

    console.error('Could not start server: DB is not responding.');
    process.exit(1);
}

startServer();