const prisma = require('../lib/prisma');
const socket = require('../lib/socket');

const getAllEvents = async (req, res) => {
  try {
    const events = await prisma.event.findMany({
      include: {
        sport: { select: { name: true, icon: true } },
        _count: { select: { registrations: true } }
      },
      orderBy: { startDate: 'asc' }
    });
    res.json({ success: true, data: events });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getEventById = async (req, res) => {
  try {
    const event = await prisma.event.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        sport: { select: { name: true, icon: true } },
        registrations: { include: { user: { select: { id: true, name: true } } } }
      }
    });
    if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
    res.json({ success: true, data: event });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const createEvent = async (req, res) => {
  try {
    const { name, description, sportId, type, startDate, endDate, venue, maxParticipants, fee, imageUrl } = req.body;
    
    if (!name || !sportId || !startDate) {
      return res.status(400).json({ success: false, message: 'Name, sportId, and startDate are required' });
    }

    const event = await prisma.event.create({
      data: {
        name, description, 
        sportId: parseInt(sportId), 
        type: type || 'TRAINING',
        startDate: new Date(startDate),
        endDate: endDate ? new Date(endDate) : null,
        venue, 
        maxParticipants: maxParticipants ? parseInt(maxParticipants) : null,
        fee: fee ? parseFloat(fee) : 0,
        imageUrl,
        status: 'UPCOMING'
      }
    });

    res.status(201).json({ success: true, data: event });
    try { socket.getIO().emit('event_updated', event); } catch (e) {}
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const updateEvent = async (req, res) => {
  try {
    const { name, description, sportId, type, startDate, endDate, venue, maxParticipants, fee, imageUrl, status } = req.body;
    const eventId = parseInt(req.params.id);

    const event = await prisma.event.update({
      where: { id: eventId },
      data: {
        name, description, 
        sportId: sportId ? parseInt(sportId) : undefined, 
        type, 
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        venue, 
        maxParticipants: maxParticipants ? parseInt(maxParticipants) : undefined,
        fee: fee ? parseFloat(fee) : undefined,
        imageUrl,
        status
      }
    });

    res.json({ success: true, data: event });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Event not found' });
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const deleteEvent = async (req, res) => {
  try {
    await prisma.event.delete({ where: { id: parseInt(req.params.id) } });
    res.json({ success: true, message: 'Event deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const { v4: uuidv4 } = require('uuid');

const registerForEvent = async (req, res) => {
  try {
    const eventId = parseInt(req.params.id);
    const event = await prisma.event.findUnique({
      where: { id: eventId },
      include: { _count: { select: { registrations: true } } }
    });

    if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
    if (event.status !== 'UPCOMING') return res.status(400).json({ success: false, message: 'Event registration is closed' });
    if (event.maxParticipants && event._count.registrations >= event.maxParticipants) {
      return res.status(400).json({ success: false, message: 'Event has reached maximum capacity' });
    }

    const result = await prisma.$transaction(async (tx) => {
      const registration = await tx.eventRegistration.create({
        data: {
          eventId,
          userId: req.user.id
        }
      });

      if (event.fee > 0) {
        const stripePaymentIntentId = `pi_dummy_${uuidv4()}`;
        const stripeClientSecret = `${stripePaymentIntentId}_secret_${uuidv4()}`;

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount: event.fee,
            purpose: 'EVENT_REGISTRATION',
            eventRegId: registration.id,
            stripePaymentIntentId,
            stripeClientSecret,
            status: 'PENDING'
          }
        });
        registration.clientSecret = stripeClientSecret;
        registration.paymentId = payment.id;
      }

      return registration;
    });

    res.status(201).json({ success: true, data: result });
    try { socket.getIO().emit('event_updated', result); } catch (e) {}
  } catch (err) {
    if (err.code === 'P2002') return res.status(409).json({ success: false, message: 'Already registered for this event' });
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getAllEvents, getEventById, createEvent, updateEvent, deleteEvent, registerForEvent };
