// Integration Tests for API Routes

const request = require('supertest');
const app = require('../../src/app');

describe('API Routes Integration Tests', () => {
  describe('GET /api/items', () => {
    it('should return all items', async () => {
      const res = await request(app).get('/api/items');
      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body).toHaveProperty('count');
      expect(Array.isArray(res.body.data)).toBe(true);
    });
  });

  describe('POST /api/items', () => {
    it('should create a new item', async () => {
      const newItem = {
        name: 'Test Item',
        description: 'Test Description'
      };

      const res = await request(app)
        .post('/api/items')
        .send(newItem);

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(newItem.name);
      expect(res.body.data).toHaveProperty('id');
    });

    it('should return 400 if name is missing', async () => {
      const res = await request(app)
        .post('/api/items')
        .send({ description: 'No name' });

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/items/:id', () => {
    it('should return item by id', async () => {
      const res = await request(app).get('/api/items/1');
      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.id).toBe(1);
    });

    it('should return 404 for non-existent item', async () => {
      const res = await request(app).get('/api/items/9999');
      expect(res.statusCode).toBe(404);
      expect(res.body.success).toBe(false);
    });
  });

  describe('PUT /api/items/:id', () => {
    it('should update an item', async () => {
      const updates = {
        name: 'Updated Item',
        description: 'Updated Description'
      };

      const res = await request(app)
        .put('/api/items/1')
        .send(updates);

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.name).toBe(updates.name);
    });
  });

  describe('DELETE /api/items/:id', () => {
    it('should delete an item', async () => {
      const res = await request(app).delete('/api/items/2');
      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
    });

    it('should return 404 for non-existent item', async () => {
      const res = await request(app).delete('/api/items/9999');
      expect(res.statusCode).toBe(404);
    });
  });
});
