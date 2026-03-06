// API Routes

const express = require('express');
const router = express.Router();
const logger = require('../logger');

// Sample data store (in production, use a database)
let items = [
  { id: 1, name: 'Item 1', description: 'First item' },
  { id: 2, name: 'Item 2', description: 'Second item' }
];

// GET /api/items - Get all items
router.get('/items', (req, res) => {
  logger.info('GET /api/items');
  res.json({
    success: true,
    count: items.length,
    data: items
  });
});

// GET /api/items/:id - Get item by ID
router.get('/items/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const item = items.find(i => i.id === id);

  if (!item) {
    logger.warn(`Item not found: ${id}`);
    return res.status(404).json({
      success: false,
      message: 'Item not found'
    });
  }

  logger.info(`GET /api/items/${id}`);
  res.json({
    success: true,
    data: item
  });
});

// POST /api/items - Create new item
router.post('/items', (req, res) => {
  const { name, description } = req.body;

  if (!name) {
    return res.status(400).json({
      success: false,
      message: 'Name is required'
    });
  }

  const newItem = {
    id: items.length + 1,
    name,
    description: description || ''
  };

  items.push(newItem);
  logger.info(`Created item: ${newItem.id}`);

  res.status(201).json({
    success: true,
    data: newItem
  });
});

// PUT /api/items/:id - Update item
router.put('/items/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const itemIndex = items.findIndex(i => i.id === id);

  if (itemIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Item not found'
    });
  }

  const { name, description } = req.body;
  items[itemIndex] = {
    ...items[itemIndex],
    name: name || items[itemIndex].name,
    description: description !== undefined ? description : items[itemIndex].description
  };

  logger.info(`Updated item: ${id}`);
  res.json({
    success: true,
    data: items[itemIndex]
  });
});

// DELETE /api/items/:id - Delete item
router.delete('/items/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const itemIndex = items.findIndex(i => i.id === id);

  if (itemIndex === -1) {
    return res.status(404).json({
      success: false,
      message: 'Item not found'
    });
  }

  items.splice(itemIndex, 1);
  logger.info(`Deleted item: ${id}`);

  res.json({
    success: true,
    message: 'Item deleted'
  });
});

module.exports = router;
