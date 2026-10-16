const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getAllEvents, getEventById, createEvent, updateEvent, deleteEvent, registerForEvent } = require('../controllers/events.controller');

router.get('/', getAllEvents);
router.get('/:id', getEventById);

router.use(authenticate);

router.post('/:id/register', registerForEvent);

router.use(requireAdmin);

router.post('/', createEvent);
router.put('/:id', updateEvent);
router.delete('/:id', deleteEvent);

module.exports = router;
