const express = require('express');
const router = express.Router({ mergeParams: true }); // mergeParams to get venueId if mounted on venues
const { authenticate, requireAdmin } = require('../middleware/auth');
const { getVenueReviews, createReview, deleteReview, getAllReviews } = require('../controllers/reviews.controller');

// Mounted on /api/reviews
router.get('/', authenticate, requireAdmin, getAllReviews);
router.delete('/:id', authenticate, deleteReview);

module.exports = router;
