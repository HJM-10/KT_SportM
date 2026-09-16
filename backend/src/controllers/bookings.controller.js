const prisma = require('../lib/prisma');
const QRCode = require('qrcode');
const { v4: uuidv4 } = require('uuid');

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
        }
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

const createBooking = async (req, res) => {
  try {
    const { slotId, notes } = req.body;
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

    const qrToken = uuidv4();
    const qrPayload = JSON.stringify({ bookingId: null, token: qrToken, userId: req.user.id });
    const qrCode = await QRCode.toDataURL(qrPayload);

    const booking = await prisma.$transaction(async (tx) => {
      const b = await tx.booking.create({
        data: {
          userId: req.user.id,
          slotId: parseInt(slotId),
          qrToken,
          qrCode,
          totalPrice: slot.venue.pricePerSlot,
          notes
        },
        include: {
          slot: { include: { venue: { include: { sport: { select: { name: true } } } } } }
        }
      });
      await tx.bookingSlot.update({ where: { id: parseInt(slotId) }, data: { isBooked: true } });
      return b;
    });

    res.status(201).json({ success: true, data: booking });
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
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getSlots, createSlot, getMyBookings, getAllBookings, createBooking, cancelBooking, getBookingQR, scanBooking };
