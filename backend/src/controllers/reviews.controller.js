const prisma = require('../lib/prisma');

const getVenueReviews = async (req, res) => {
  try {
    const { id: venueId } = req.params;
    const reviews = await prisma.review.findMany({
      where: { venueId: parseInt(venueId) },
      include: { user: { select: { id: true, name: true } } },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: reviews });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const createReview = async (req, res) => {
  try {
    const { id: venueId } = req.params;
    const { rating, comment, bookingId } = req.body;
    if (!Number.isInteger(Number(rating)) || Number(rating) < 1 || Number(rating) > 5) return res.status(400).json({ success: false, message: 'Rating must be an integer from 1 to 5' });
    
    if (!rating || !bookingId) {
      return res.status(400).json({ success: false, message: 'Rating and bookingId are required' });
    }

    // Verify booking
    const booking = await prisma.booking.findFirst({
      where: { 
        id: parseInt(bookingId), 
        userId: req.user.id, 
        slot: { venueId: parseInt(venueId) },
        status: { in: ['CONFIRMED', 'SCANNED'] }
      }
    });

    if (!booking) {
      return res.status(403).json({ success: false, message: 'Valid confirmed booking required to leave a review' });
    }

    const review = await prisma.review.upsert({
      where: { userId_venueId: { userId: req.user.id, venueId: parseInt(venueId) } },
      update: { rating: parseInt(rating), comment, bookingId: parseInt(bookingId) },
      create: {
        userId: req.user.id,
        venueId: parseInt(venueId),
        bookingId: parseInt(bookingId),
        rating: parseInt(rating),
        comment
      },
      include: { user: { select: { id: true, name: true } } }
    });

    res.status(201).json({ success: true, data: review });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteReview = async (req, res) => {
  try {
    const reviewId = parseInt(req.params.id);
    const review = await prisma.review.findUnique({ where: { id: reviewId } });
    
    if (!review) return res.status(404).json({ success: false, message: 'Review not found' });
    if (review.userId !== req.user.id && req.user.role !== 'ADMIN') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }

    await prisma.review.delete({ where: { id: reviewId } });
    res.json({ success: true, message: 'Review deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getAllReviews = async (req, res) => {
  try {
    const reviews = await prisma.review.findMany({
      include: { 
        user: { select: { id: true, name: true, email: true } },
        venue: { select: { id: true, name: true, sport: { select: { name: true } } } }
      },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: reviews });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getVenueReviews, createReview, deleteReview, getAllReviews };

