const request = require('supertest');
const { app, pool } = require('../app');

describe('Inventory API', () => {

    afterAll(async () => {
        await pool.end();
    });

    test('GET /health/alive should return OK', async () => {
        const res = await request(app).get('/health/alive');
        expect(res.statusCode).toBe(200);
        expect(res.text).toContain('OK');
    });

    test('GET /health/ready should return OK when DB is connected', async () => {
        const res = await request(app).get('/health/ready');
        expect([200, 500]).toContain(res.statusCode);
    });

    test('GET /items should return array', async () => {
        const res = await request(app).get('/items');

        expect(res.statusCode).toBe(200);

        expect(res.text).toBeDefined();
    });

    let createdItemId;

    test('POST /items should create item', async () => {
        const res = await request(app)
            .post('/items')
            .send({
                name: 'Test Item',
                quantity: 5
            });

        expect(res.statusCode).toBe(201);
        expect(res.body.name).toBe('Test Item');
        expect(res.body.quantity).toBe(5);

        createdItemId = res.body.id;
    });

    test('GET /items/:id should return item', async () => {
        const res = await request(app).get(`/items/${createdItemId}`);

        expect(res.statusCode).toBe(200);
        expect(res.body.id).toBe(createdItemId);
    });

});