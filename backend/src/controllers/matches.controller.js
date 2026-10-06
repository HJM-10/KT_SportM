const prisma = require('../lib/prisma');

const getMatches = async (req, res) => {
  try {
    const { tournamentId, isCompleted } = req.query;
    const where = {};
    if (tournamentId) where.tournamentId = parseInt(tournamentId);
    if (isCompleted !== undefined) where.isCompleted = isCompleted === 'true';

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 100;
    const skip = (page - 1) * limit;

    const matches = await prisma.match.findMany({
      where,
      include: { tournament: { select: { id: true, name: true, sport: { select: { name: true } } } } },
      orderBy: { scheduledAt: 'asc' },
      skip,
      take: limit
    });
    res.json({ success: true, data: matches });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const getMatchById = async (req, res) => {
  try {
    const match = await prisma.match.findUnique({
      where: { id: parseInt(req.params.id) },
      include: { tournament: { include: { sport: true } } }
    });
    if (!match) return res.status(404).json({ success: false, message: 'Match not found' });
    res.json({ success: true, data: match });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const createMatch = async (req, res) => {
  try {
    const { tournamentId, team1, team2, scheduledAt, venue, round } = req.body;
    if (!tournamentId || !team1 || !team2 || !scheduledAt) {
      return res.status(400).json({ success: false, message: 'tournamentId, team1, team2, scheduledAt are required' });
    }
    const match = await prisma.match.create({
      data: {
        tournamentId: parseInt(tournamentId),
        team1, team2,
        scheduledAt: new Date(scheduledAt),
        venue, round
      },
      include: { tournament: { select: { id: true, name: true } } }
    });
    res.status(201).json({ success: true, data: match });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

const updateMatchResult = async (req, res) => {
  try {
    const { result, team1Score, team2Score, winner, isCompleted } = req.body;
    const current = await prisma.match.findUnique({ where: { id: Number(req.params.id) } });
    if (!current) return res.status(404).json({ success: false, message: 'Match not found' });
    if (winner && !['team1', 'team2', 'draw', current.team1, current.team2].includes(winner)) return res.status(400).json({ success: false, message: 'Winner must be one of the competing teams or draw' });
    const match = await prisma.match.update({
      where: { id: parseInt(req.params.id) },
      data: { result, team1Score: team1Score == null ? undefined : String(team1Score), team2Score: team2Score == null ? undefined : String(team2Score), winner, isCompleted: isCompleted ?? true },
      include: { tournament: { select: { id: true, name: true } } }
    });
    res.json({ success: true, data: match });
  } catch (err) {
    if (err.code === 'P2025') return res.status(404).json({ success: false, message: 'Match not found' });
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
  }
};

module.exports = { getMatches, getMatchById, createMatch, updateMatchResult };

