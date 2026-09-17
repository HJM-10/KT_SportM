const prisma = require('../lib/prisma');
const QRCode = require('qrcode');
const { v4: uuidv4 } = require('uuid');
const socket = require('../lib/socket');

const getSlots = async (req, res) => {
  try {
    const { venueId, date } = req.query;
    if (!venueId || !date) {
      return res.status(400).json({ success: false, message: 'venueId and date are required' });
    }
    const targetDate = new Date(date);
    const slots = await prisma.bookingSlot.findMany({
      where: {
        venueId: parseInt(venueId),
        date: targetDate
      },
      orderBy: { startTime: 'asc' }
    });
    res.json({ success: true, data: slots });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const createSlot = async (req, res) => {
  try {
    const { venueId, date, startTime, endTime } = req.body;
    if (!venueId || !date || !startTime || !endTime) {
      return res.status(400).json({ success: false, message: 'venueId, date, startTime, endTime are required' });
    }
    
    // Check for overlapping slots
    const existingSlots = await prisma.bookingSlot.findMany({
      where: { venueId: parseInt(venueId), date: new Date(date) }
    });
    
    const isOverlap = existingSlots.some(slot => {
      return (startTime < slot.endTime && endTime > slot.startTime);
    });
    
    if (isOverlap) {
      return res.status(409).json({ success: false, message: 'Time slot overlaps with an existing slot' });
    }

    const slot = await prisma.bookingSlot.create({
      data: { venueId: parseInt(venueId), date: new Date(date), startTime, endTime }
    });
    res.status(201).json({ success: true, data: slot });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getMyBookings = async (req, res) => {
  try {
    const bookings = await prisma.booking.findMany({
      where: { userId: req.user.id },
      include: {
        slot: {
          include: {
            venue: { include: { sport: { select: { id: true, name: true, icon: true } } } }
          }
        },
        payment: true
      },
      orderBy: { createdAt: 'desc' }
    });
    res.json({ success: true, data: bookings });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getAllBookings = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 100;
    const skip = (page - 1) * limit;

    const bookings = await prisma.booking.findMany({
      include: {
        user: { select: { id: true, name: true, email: true } },
        slot: {
          include: { venue: { include: { sport: { select: { id: true, name: true } } } } }
        }
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit
    });
    res.json({ success: true, data: bookings });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const bcrypt = require('bcryptjs');

const createBooking = async (req, res) => {
  try {
    const { slotId, notes, promoCode, walkInName, walkInPhone } = req.body;
    if (!slotId) return res.status(400).json({ success: false, message: 'slotId is required' });

    // Check slot availability
    const slot = await prisma.bookingSlot.findUnique({ where: { id: parseInt(slotId) }, include: { venue: true } });
    if (!slot) return res.status(404).json({ success: false, message: 'Slot not found' });
    if (slot.isBooked) return res.status(409).json({ success: false, message: 'Slot already booked' });

    // Check if slot is in the past
    const slotDateTime = new Date(`${slot.date.toISOString().split('T')[0]}T${slot.startTime}:00`);
    if (slotDateTime < new Date()) {
      return res.status(400).json({ success: false, message: 'Cannot book a slot in the past' });
    }

    const basePrice = slot.venue.pricePerSlot;
    let membershipDiscount = 0;
    let promoDiscount = 0;
    let finalPrice = basePrice;
    let promoCodeId = null;

    // Membership logic
    const membership = await prisma.membership.findUnique({ where: { userId: req.user.id } });
    if (membership && membership.isActive) {
      if (membership.tier === 'SILVER') membershipDiscount = basePrice * 0.10;
      if (membership.tier === 'GOLD') membershipDiscount = basePrice * 0.20;
    }
    
    finalPrice -= membershipDiscount;

    // Promo code logic
    if (promoCode) {
      const promo = await prisma.promoCode.findUnique({ where: { code: promoCode } });
      if (promo && promo.isActive && (!promo.expiresAt || new Date() <= promo.expiresAt) && (!promo.maxUses || promo.usedCount < promo.maxUses)) {
        if (!promo.minOrderAmount || basePrice >= promo.minOrderAmount) {
          if (promo.discountType === 'PERCENTAGE') {
            promoDiscount = finalPrice * (promo.discountValue / 100);
          } else {
            promoDiscount = promo.discountValue;
          }
          promoCodeId = promo.id;
        }
      }
    }
    
    finalPrice -= promoDiscount;
    if (finalPrice < 0) finalPrice = 0;

    let targetUserId = req.user.id;
    let targetBookingStatus = 'PENDING_PAYMENT';

    // Handle Walk-in Users (Admin Only)
    if (req.user.role === 'ADMIN' && walkInName && walkInPhone) {
      const email = `guest_${walkInPhone}@smartsportshub.com`;
      const guestPass = await bcrypt.hash(walkInPhone, 10);
      
      const guestUser = await prisma.user.upsert({
        where: { email },
        update: { name: walkInName },
        create: {
          name: walkInName,
          email,
          phone: walkInPhone,
          password: guestPass,
          role: 'CUSTOMER'
        }
      });
      targetUserId = guestUser.id;
      // Cash payments for walk-ins can be considered CONFIRMED immediately if the admin specifies, 
      // but let's keep it PENDING_PAYMENT and the admin can click "Confirm Payment" in the dashboard.
    }

    const qrToken = uuidv4();
    const qrPayload = JSON.stringify({ bookingId: null, token: qrToken, userId: targetUserId });
    const qrCode = await QRCode.toDataURL(qrPayload);

    const booking = await prisma.$transaction(async (tx) => {
      const b = await tx.booking.create({
        data: {
          userId: targetUserId,
          slotId: parseInt(slotId),
          qrToken,
          qrCode,
          basePrice,
          membershipDiscount,
          promoDiscount,
          finalPrice,
          promoCodeId,
          notes,
          status: 'PENDING_PAYMENT'
        },
        include: {
          slot: { include: { venue: { include: { sport: { select: { name: true } } } } } }
        }
      });
      await tx.bookingSlot.update({ where: { id: parseInt(slotId) }, data: { isBooked: true } });
      
      if (promoCodeId) {
         await tx.promoCode.update({ where: { id: promoCodeId }, data: { usedCount: { increment: 1 } } });
         await tx.promoCodeUsage.create({ data: { promoCodeId, userId: targetUserId, bookingId: b.id } });
      }

      // Create Payment Record (Dummy Stripe)
      const stripePaymentIntentId = `pi_dummy_${uuidv4()}`;
      const stripeClientSecret = `${stripePaymentIntentId}_secret_${uuidv4()}`;
      
      const payment = await tx.payment.create({
        data: {
          userId: targetUserId,
          amount: finalPrice,
          purpose: 'BOOKING',
          stripePaymentIntentId,
          stripeClientSecret,
          bookingId: b.id,
          status: 'PENDING'
        }
      });

      b.clientSecret = stripeClientSecret;
      b.paymentId = payment.id;

      return b;
    });

    res.status(201).json({ success: true, data: booking });
    try { socket.getIO().emit('booking_updated', booking); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const cancelBooking = async (req, res) => {
  try {
    const booking = await prisma.booking.findUnique({ where: { id: parseInt(req.params.id) } });
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (booking.userId !== req.user.id && req.user.role !== 'ADMIN') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    if (booking.status !== 'CONFIRMED') {
      return res.status(400).json({ success: false, message: 'Booking cannot be cancelled' });
    }

    await prisma.$transaction(async (tx) => {
      await tx.booking.update({ where: { id: booking.id }, data: { status: 'CANCELLED' } });
      await tx.bookingSlot.update({ where: { id: booking.slotId }, data: { isBooked: false } });
    });

    res.json({ success: true, message: 'Booking cancelled' });
    try { socket.getIO().emit('booking_updated', booking); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getBookingQR = async (req, res) => {
  try {
    const booking = await prisma.booking.findUnique({
      where: { id: parseInt(req.params.id) },
      include: { slot: { include: { venue: { include: { sport: true } } } } }
    });
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
    if (booking.userId !== req.user.id && req.user.role !== 'ADMIN') {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    res.json({ success: true, data: { qrCode: booking.qrCode, qrToken: booking.qrToken, booking } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const scanBooking = async (req, res) => {
  try {
    const { qrToken } = req.body;
    if (!qrToken) return res.status(400).json({ success: false, message: 'qrToken is required' });

    const booking = await prisma.booking.findUnique({
      where: { qrToken },
      include: {
        user: { select: { id: true, name: true, email: true } },
        slot: { include: { venue: { include: { sport: { select: { name: true } } } } } }
      }
    });

    if (!booking) return res.status(404).json({ success: false, message: 'Invalid QR code' });
    if (booking.status === 'CANCELLED') return res.status(400).json({ success: false, message: 'Booking is cancelled' });
    if (booking.status === 'SCANNED') return res.status(400).json({ success: false, message: 'Booking already used' });

    const updated = await prisma.booking.update({
      where: { id: booking.id },
      data: { status: 'SCANNED' },
      include: {
        user: { select: { id: true, name: true, email: true } },
        slot: { include: { venue: { include: { sport: { select: { name: true } } } } } }
      }
    });

    res.json({ success: true, message: 'Booking verified!', data: updated });
    try { socket.getIO().emit('booking_updated', updated); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const confirmBooking = async (req, res) => {
  try {
    const booking = await prisma.booking.findUnique({ where: { id: parseInt(req.params.id) } });
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
    
    if (booking.status === 'CONFIRMED' || booking.status === 'SCANNED') {
      return res.status(400).json({ success: false, message: 'Booking is already confirmed or scanned' });
    }

    const updated = await prisma.booking.update({
      where: { id: booking.id },
      data: { status: 'CONFIRMED' },
      include: {
        user: { select: { id: true, name: true, email: true } },
        slot: { include: { venue: { include: { sport: { select: { name: true } } } } } }
      }
    });

    res.json({ success: true, message: 'Booking manually confirmed', data: updated });
    try { socket.getIO().emit('booking_updated', updated); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getSlots, createSlot, getMyBookings, getAllBookings, createBooking, cancelBooking, getBookingQR, scanBooking, confirmBooking };
