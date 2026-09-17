const router = require('express').Router();
const { getUsers } = require('../controllers/users.controller');
const { authenticate, requireAdmin } = require('../middleware/auth');

router.get('/', authenticate, requireAdmin, getUsers);

module.exports = router;
