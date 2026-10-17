const handleError = require('../middleware/errorHandler');
const prisma = require('../lib/prisma');

const getVenues = async (req, res) => {
  try {
    const { sportId } = req.query;
    const where = { isActive: true };
    if (sportId) where.sportId = parseInt(sportId);

    const venues = await prisma.venue.findMany({
      where,
      include: { sport: { select: { id: true, name: true, icon: true } } },
      orderBy: { name: 'asc' }
    });
    res.json({ success: true, data: venues });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const getVenueById = async (req, res) => {
  try {
    const venue = await prisma.venue.findUnique({
      where: { id: parseInt(req.params.id) },
      include: { sport: true }
    });
    if (!venue) return res.status(404).json({ success: false, message: 'Venue not found' });
    res.json({ success: true, data: venue });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const createVenue = async (req, res) => {
  try {
    const { name, description, sportId, capacity, pricePerSlot, imageUrl } = req.body;
    if (!name || !sportId) {
      return res.status(400).json({ success: false, message: 'Name and sportId are required' });
    }
    const venue = await prisma.venue.create({
      data: { name, description, sportId: parseInt(sportId), capacity, pricePerSlot, imageUrl },
      include: { sport: { select: { id: true, name: true } } }
    });
    res.status(201).json({ success: true, data: venue });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
  }
};

const updateVenue = async (req, res) => {
  try {
    const { name, description, sportId, capacity, pricePerSlot, imageUrl, isActive } = req.body;
    const venue = await prisma.venue.update({
      where: { id: parseInt(req.params.id) },
      data: { name, description, sportId: sportId ? parseInt(sportId) : undefined, capacity, pricePerSlot, imageUrl, isActive },
      include: { sport: { select: { id: true, name: true } } }
    });
    res.json({ success: true, data: venue });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Venue not found' });
    console.error(err);
    handleError(err, req, res);
  }
};

const deleteVenue = async (req, res) => {
  try {
    await prisma.venue.update({ where: { id: parseInt(req.params.id) }, data: { isActive: false } });
    res.json({ success: true, message: 'Venue deactivated' });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Venue not found' });
    console.error(err);
    handleError(err, req, res);
  }
};

module.exports = { getVenues, getVenueById, createVenue, updateVenue, deleteVenue };

