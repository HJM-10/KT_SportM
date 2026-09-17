const express = require('express');
const router = express.Router();
const { requireAdmin } = require('../middleware/auth');
const { getRevenueSummary, getBookingAnalytics, getUtilizationReport, getCustomerAnalytics, exportBookingsCsv } = require('../controllers/reports.controller');

router.use(requireAdmin);

router.get('/revenue', getRevenueSummary);
router.get('/bookings', getBookingAnalytics);
router.get('/utilization', getUtilizationReport);
router.get('/customers', getCustomerAnalytics);
router.get('/export/bookings', exportBookingsCsv);

module.exports = router;
