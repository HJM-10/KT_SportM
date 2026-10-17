const handleError = require('../middleware/errorHandler');
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
    handleError(err, req, res);
  }
};

const getTournamentById = async (req, res) => {
  try {
    const tournament = await prisma.tournament.findUnique({
      where: { id: parseInt(req.params.id) },
      include: {
        sport: true,
        matches: { orderBy: { scheduledAt: 'asc' } },
        registrations: { include: { user: { select: { id: true, name: true } }, payment: { select: { status: true } } } }
      }
    });
    if (!tournament) return res.status(404).json({ success: false, message: 'Tournament not found' });
    res.json({ success: true, data: tournament });
  } catch (err) {
    console.error(err);
    handleError(err, req, res);
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
    handleError(err, req, res);
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
        entryFee: entryFee !== undefined ? parseFloat(entryFee) : undefined,
        imageUrl
      },
      include: { sport: { select: { id: true, name: true } } }
    });
    res.json({ success: true, data: tournament });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Tournament not found' });
    console.error(err);
    handleError(err, req, res);
  }
};

const deleteTournament = async (req, res) => {
  try {
    const tournamentId = parseInt(req.params.id);
    const registrationCount = await prisma.teamRegistration.count({ where: { tournamentId } });
    if (registrationCount > 0) return res.status(409).json({ success: false, message: 'Tournament has registrations. Retain it to preserve payment and match history.' });
    
    await prisma.$transaction(async (tx) => {
      // Find registrations for this tournament
      const regs = await tx.teamRegistration.findMany({
        where: { tournamentId },
        select: { id: true }
      });
      const regIds = regs.map(r => r.id);

      // Delete payments related to these registrations
      if (regIds.length > 0) {
        await tx.payment.deleteMany({
          where: { tournamentRegId: { in: regIds } }
        });
      }

      // Delete registrations
      await tx.teamRegistration.deleteMany({
        where: { tournamentId }
      });

      // Delete matches
      await tx.match.deleteMany({
        where: { tournamentId }
      });

      // Finally, delete the tournament
      await tx.tournament.delete({
        where: { id: tournamentId }
      });
    });

    res.json({ success: true, message: 'Tournament deleted successfully' });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Tournament not found' });
    console.error(err);
    handleError(err, req, res);
  }
};


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
      await tx.tournament.update({ where: { id: tournamentId }, data: { updatedAt: new Date() } });
      const current = await tx.tournament.findUnique({ where: { id: tournamentId } });
      const count = await tx.teamRegistration.count({ where: { tournamentId } });
      if (current.status !== 'UPCOMING' || count >= current.maxTeams) throw Object.assign(new Error('Tournament registration is closed or full'), { status: 409 });
      const reg = await tx.teamRegistration.create({
        data: { 
          tournamentId, 
          userId: req.user.id, 
          teamName: teamName || `Team ${req.user.id}`
        },
        include: { tournament: { select: { id: true, name: true, entryFee: true } } }
      });

      if (tournament.entryFee > 0) {

        const payment = await tx.payment.create({
          data: {
            userId: req.user.id,
            amount: tournament.entryFee,
            purpose: 'TOURNAMENT_REGISTRATION',
            tournamentRegId: reg.id,
            status: 'PENDING'
          }
        });
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
    handleError(err, req, res);
  }
};

const manualRegister = async (req, res) => {
  try {
    const { teamName, userId, paymentStatus } = req.body;
    const tournamentId = parseInt(req.params.id);

    const tournament = await prisma.tournament.findUnique({
      where: { id: tournamentId },
      include: { _count: { select: { registrations: true } } }
    });
    
    if (!tournament) return res.status(404).json({ success: false, message: 'Tournament not found' });
    if (tournament._count.registrations >= tournament.maxTeams) {
      return res.status(400).json({ success: false, message: 'Tournament has reached maximum capacity' });
    }

    const regUserId = userId ? parseInt(userId) : req.user.id;

    const result = await prisma.$transaction(async (tx) => {
      const reg = await tx.teamRegistration.create({
        data: { 
          tournamentId, 
          userId: regUserId, 
          teamName: teamName || `Team ${regUserId}`
        }
      });

      if (tournament.entryFee > 0 && paymentStatus !== 'FREE') {
        const payment = await tx.payment.create({
          data: {
            userId: regUserId,
            amount: tournament.entryFee,
            purpose: 'TOURNAMENT_REGISTRATION',
            tournamentRegId: reg.id,
            status: paymentStatus || 'PAID'
          }
        });
        reg.paymentId = payment.id;
      }
      return reg;
    });

    res.status(201).json({ success: true, data: result });
  } catch (err) {
    if (err.code === 'P2002') return res.status(409).json({ success: false, message: 'User is already registered for this tournament' });
    console.error(err);
    handleError(err, req, res);
  }
};

module.exports = { getTournaments, getTournamentById, createTournament, updateTournament, deleteTournament, registerForTournament, manualRegister };


