const handleError = require('../middleware/errorHandler');
const prisma = require('../lib/prisma');
const socket = require('../lib/socket');

const getAllEvents = async (req, res) => {
  try {
    const events = await prisma.event.findMany({
      include: {
        sport: { select: { name: true, icon: true } },
        registrations: { where: { userId: req.user.id }, select: { id: true, payment: { select: { status: true } } } },
        _count: { select: { registrations: true } }
      },
      orderBy: { startDate: 'asc' }
    });
    res.json({ success: true, data: events });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const getEventById = async (req, res) => {
  try {
    const event = await prisma.event.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        sport: { select: { name: true, icon: true } },
        registrations: { include: { user: { select: { id: true, name: true } }, payment: { select: { status: true } } } }
      }
    });
    if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
    res.json({ success: true, data: event });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
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
    handleError(err, req, res);
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
        fee: fee !== undefined ? parseFloat(fee) : undefined,
        imageUrl,
        status
      }
    });

    res.json({ success: true, data: event });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Event not found' });
    console.error(err);
    handleError(err, req, res);
  }
};

const deleteEvent = async (req, res) => {
  try {
    const eventId = parseInt(req.params.id);
    const registrationsCount = await prisma.eventRegistration.count({ where: { eventId } });
    if (registrationsCount > 0) return res.status(409).json({ success: false, message: 'This event has registrations. Cancel it instead to retain payment history.' });
    
    // Find all registrations for this event to delete their payments
    const registrations = await prisma.eventRegistration.findMany({ 
      where: { eventId }, 
      select: { id: true } 
    });
    const regIds = registrations.map(r => r.id);

    await prisma.$transaction([
      // 1. Delete payments tied to these registrations
      prisma.payment.deleteMany({ where: { eventRegId: { in: regIds } } }),
      // 2. Delete the registrations themselves
      prisma.eventRegistration.deleteMany({ where: { eventId } }),
      // 3. Finally, delete the event
      prisma.event.delete({ where: { id: eventId } })
    ]);

    res.json({ success: true, message: 'Event deleted successfully' });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};


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
      await tx.event.update({ where: { id: eventId }, data: { updatedAt: new Date() } });
      const current = await tx.event.findUnique({ where: { id: eventId } });
      const count = await tx.eventRegistration.count({ where: { eventId } });
      if (current.status !== 'UPCOMING' || (current.maxParticipants && count >= current.maxParticipants)) throw Object.assign(new Error('Event registration is closed or full'), { status: 409 });
      const registration = await tx.eventRegistration.create({
        data: {
          eventId,
          userId: req.user.id
        }
      });

      if (event.fee > 0) {

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount: event.fee,
            purpose: 'EVENT_REGISTRATION',
            eventRegId: registration.id,
            status: 'PENDING'
          }
        });
        registration.paymentId = payment.id;
      }

      return registration;
    });

    res.status(201).json({ success: true, data: result });
    try { socket.getIO().emit('event_updated', { eventId }); } catch (e) {}
  } catch (err) {
    if (err.code === 'P2002') return res.status(409).json({ success: false, message: 'Already registered for this event' });
    console.error(err);
    handleError(err, req, res);
  }
};

module.exports = { getAllEvents, getEventById, createEvent, updateEvent, deleteEvent, registerForEvent };


