const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { initiatePayment, confirmPayment, getMyPayments, getAllPayments } = require('../controllers/payments.controller');

router.use(authenticate);

router.post('/initiate', initiatePayment);
router.post('/confirm', confirmPayment);
router.get('/my', getMyPayments);
router.get('/', requireAdmin, getAllPayments);

module.exports = router;
