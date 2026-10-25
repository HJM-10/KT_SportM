const prisma = require('../lib/prisma');
const handleError = require('../middleware/errorHandler');

// All daily operational views use the arena's Pakistan calendar day.
const pakistanDay = now => new Date(now.getTime() + 5 * 3600000).toISOString().slice(0, 10);
const dayBounds = value => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const date = new Date(value);
  if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) return null;
  const start = new Date(`${value}T00:00:00+05:00`);
  return { date, start, end: new Date(start.getTime() + 86400000) };
};

const getArenaDesk = async (req, res) => {
  try {
    const date = req.query.date === undefined ? pakistanDay(new Date()) : req.query.date;
    const bounds = dayBounds(date);
    if (!bounds) return res.status(400).json({ success: false, message: 'A valid YYYY-MM-DD date is required' });
    const [venues, sports, paid] = await Promise.all([
      prisma.venue.findMany({
        orderBy: { name: 'asc' },
        include: {
          sport: { select: { id: true, name: true, isActive: true, imageUrl: true } },
          slots: {
            where: { date: bounds.date }, orderBy: { startTime: 'asc' },
            include: { bookings: {
              orderBy: { createdAt: 'desc' },
              select: {
                id: true, status: true, finalPrice: true, notes: true,
                user: { select: { id: true, name: true, phone: true } },
                payment: { select: { id: true, status: true, amount: true } },
              },
            } },
          },
        },
      }),
      prisma.sport.findMany({ orderBy: { name: 'asc' }, select: { id: true, name: true, isActive: true, imageUrl: true } }),
      prisma.payment.aggregate({
        where: { status: 'PAID', updatedAt: { gte: bounds.start, lt: bounds.end } },
        _sum: { amount: true }, _count: { id: true },
      }),
    ]);
    const bookings = venues.flatMap(venue => venue.slots.flatMap(slot => slot.bookings.map(booking => ({
      ...booking,
      slot: {
        id: slot.id, venueId: venue.id, date: slot.date, startTime: slot.startTime, endTime: slot.endTime,
        venue: { id: venue.id, name: venue.name, imageUrl: venue.imageUrl, sport: venue.sport },
      },
    }))));
    bookings.sort((a, b) => a.slot.startTime.localeCompare(b.slot.startTime) || a.id - b.id);
    const active = bookings.filter(b => b.status !== 'CANCELLED');
    res.json({ success: true, data: {
      date, timezone: 'Asia/Karachi', generatedAt: new Date().toISOString(), venues, sports, bookings,
      summary: {
        bookings: active.length,
        pendingBookings: active.filter(b => b.status === 'PENDING_PAYMENT').length,
        collected: paid._sum.amount || 0,
        paymentCount: paid._count.id,
      },
    } });
  } catch (error) { handleError(error, req, res); }
};

module.exports = { getArenaDesk, dayBounds, pakistanDay };
