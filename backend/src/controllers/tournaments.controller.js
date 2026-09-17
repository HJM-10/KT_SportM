const prisma = require('../lib/prisma');

const getTournaments = async (req, res) => {
  try {
    const { sportId, status } = req.query;
    const where = {};
    if (sportId) where.sportId = parseInt(sportId);
    if (status) where.status = status;

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 100;
    const skip = (page - 1) * limit;

    const tournaments = await prisma.tournament.findMany({
      where,
      include: {
        sport: { select: { id: true, name: true, icon: true } },
        _count: { select: { registrations: true, matches: true } }
      },
      orderBy: { startDate: 'desc' },
      skip,
      take: limit
    });
    res.json({ success: true, data: tournaments });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getTournamentById = async (req, res) => {
  try {
    const tournament = await prisma.tournament.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        sport: true,
        matches: { orderBy: { scheduledAt: 'asc' } },
        registrations: { include: { user: { select: { id: true, name: true } } } }
      }
    });
    if (!tournament) return res.status(404).json({ success: false, message: 'Tournament not found' });
    res.json({ success: true, data: tournament });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const createTournament = async (req, res) => {
  try {
    const { name, description, sportId, format, startDate, endDate, maxTeams, entryFee, imageUrl } = req.body;
    if (!name || !sportId || !startDate) {
      return res.status(400).json({ success: false, message: 'name, sportId, startDate are required' });
    }
    const tournament = await prisma.tournament.create({
      data: {
        name, description,
        sportId: parseInt(sportId),
        format: format || 'KNOCKOUT',
        startDate: new Date(startDate),
        endDate: endDate ? new Date(endDate) : null,
        maxTeams: maxTeams ? parseInt(maxTeams) : 8,
        entryFee: entryFee ? parseFloat(entryFee) : 0,
        imageUrl
      },
      include: { sport: { select: { id: true, name: true } } }
    });
    res.status(201).json({ success: true, data: tournament });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const updateTournament = async (req, res) => {
  try {
    const { name, description, status, startDate, endDate, maxTeams, entryFee, imageUrl } = req.body;
    const tournament = await prisma.tournament.update({
      where: { id: parseInt(req.params.id) },
      data: {
        name, description, status,
        startDate: startDate ? new Date(startDate) : undefined,
        endDate: endDate ? new Date(endDate) : undefined,
        maxTeams: maxTeams ? parseInt(maxTeams) : undefined,
        entryFee: entryFee ? parseFloat(entryFee) : undefined,
        imageUrl
      },
      include: { sport: { select: { id: true, name: true } } }
    });
    res.json({ success: true, data: tournament });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Tournament not found' });
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const { v4: uuidv4 } = require('uuid');

const registerForTournament = async (req, res) => {
  try {
    const { teamName } = req.body;
    const tournamentId = parseInt(req.params.id);

    const tournament = await prisma.tournament.findUnique({
      where: { id: tournamentId },
      include: {
        _count: {
          select: { registrations: true }
        }
      }
    });
    if (!tournament) return res.status(404).json({ success: false, message: 'Tournament not found' });
    if (tournament.status !== 'UPCOMING') {
      return res.status(400).json({ success: false, message: 'Registration is closed' });
    }
    if (tournament._count.registrations >= tournament.maxTeams) {
      return res.status(400).json({ success: false, message: 'Tournament has reached maximum team capacity' });
    }

    const result = await prisma.$transaction(async (tx) => {
      const reg = await tx.teamRegistration.create({
        data: { 
          tournamentId, 
          userId: req.user.id, 
          teamName: teamName || `Team ${req.user.id}`
        },
        include: { tournament: { select: { id: true, name: true, entryFee: true } } }
      });

      if (tournament.entryFee > 0) {
        const stripePaymentIntentId = `pi_dummy_${uuidv4()}`;
        const stripeClientSecret = `${stripePaymentIntentId}_secret_${uuidv4()}`;

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount: tournament.entryFee,
            purpose: 'TOURNAMENT_REGISTRATION',
            tournamentRegId: reg.id,
            stripePaymentIntentId,
            stripeClientSecret,
            status: 'PENDING'
          }
        });
        reg.clientSecret = stripeClientSecret;
        reg.paymentId = payment.id;
      }

      return reg;
    });

    res.status(201).json({ success: true, data: result });
  } catch (err) {
    if (err.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'Already registered for this tournament' });
    }
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getTournaments, getTournamentById, createTournament, updateTournament, registerForTournament };
