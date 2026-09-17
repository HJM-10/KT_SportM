const express = require('express');
const router = express.Router();
const { authenticate, requireAdmin } = require('../middleware/auth');
const { initiatePayment, confirmPayment, getMyPayments, getAllPayments } = require('../controllers/payments.controller');

router.get('/return', (req, res) => res.type('text').send('Return to Smart Sports Hub and refresh your payments. Payment status is updated only after Stripe verifies the transaction.'));
router.use(authenticate);
router.post('/checkout', require('../controllers/checkout.controller').checkout);

router.post('/initiate', initiatePayment);
router.post('/confirm', confirmPayment);
router.get('/my', getMyPayments);
router.get('/', requireAdmin, getAllPayments);

module.exports = router;
