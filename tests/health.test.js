const request = require('supertest');
const { app } = require('../app');

describe('Health endpoints', () => {
    test('GET /health/alive should return OK', async () => {
        const response = await request(app).get('/health/alive');

        expect(response.statusCode).toBe(200);
        expect(response.text).toBe('OK\n');
    });
});