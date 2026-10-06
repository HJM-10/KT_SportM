const prisma = require('../lib/prisma');
exports.generate = async (req, res, next) => {
  try {
    const id = Number(req.params.id);
    const start = new Date(req.body.scheduledAt);
    const interval = Number(req.body.intervalMinutes || 120);
    if (!Number.isSafeInteger(id) || id < 1 || !Number.isFinite(start.getTime()) || start <= new Date() || !Number.isInteger(interval) || interval < 15) return res.status(400).json({ success: false, message: 'Choose a future first match time and an interval of at least 15 minutes' });
    const matches = await prisma.$transaction(async tx => {
      // Updating the tournament locks this row before inspecting its bracket.
      await tx.tournament.update({ where: { id }, data: { updatedAt: new Date() } });
      const tournament = await tx.tournament.findUnique({ where: { id }, include: { registrations: { include: { payment: true }, orderBy: { id: 'asc' } }, matches: { orderBy: { id: 'asc' } } } });
      if (tournament.status === 'COMPLETED') throw Object.assign(new Error('Tournament is completed'), { status: 409 });
      let teams = tournament.registrations.filter(r => tournament.entryFee === 0 || r.payment?.status === 'PAID').map(r => r.teamName);
      let round = 1;
      if (tournament.matches.length) {
        if (tournament.format === 'LEAGUE') throw Object.assign(new Error('League fixtures already exist'), { status: 409 });
        if (tournament.matches.some(m => !/^Round \d+$/.test(m.round || ''))) throw Object.assign(new Error('Existing manual fixtures require manual bracket management'), { status: 409 });
        round = Math.max(...tournament.matches.map(m => Number(m.round.split(' ')[1]))) + 1;
        const previous = tournament.matches.filter(m => m.round === `Round ${round - 1}`);
        if (previous.some(m => !m.isCompleted || !m.winner || m.winner === 'draw')) throw Object.assign(new Error('Complete the current round with a winner for every match first'), { status: 409 });
        teams = previous.map(m => m.winner === 'team1' ? m.team1 : m.winner === 'team2' ? m.team2 : m.winner);
      }
      if (teams.length < 2 || new Set(teams.map(t => t.trim().toLowerCase())).size !== teams.length) throw Object.assign(new Error('At least two distinct eligible teams are required'), { status: 400 });
      if (tournament.format === 'KNOCKOUT' && (teams.length & (teams.length - 1)) !== 0) throw Object.assign(new Error('Knockout generation requires 2, 4, 8, 16 or another power of two teams'), { status: 400 });
      const pairs = [];
      if (tournament.format === 'LEAGUE') { for (let a = 0; a < teams.length; a++) for (let b = a + 1; b < teams.length; b++) pairs.push([teams[a], teams[b]]); }
      else { for (let a = 0; a < teams.length; a += 2) pairs.push([teams[a], teams[a + 1]]); }
      const final = new Date(start.getTime() + (pairs.length - 1) * interval * 60000);
      if (start < tournament.startDate || (tournament.endDate && final > tournament.endDate)) throw Object.assign(new Error('Match times must be inside the tournament date range'), { status: 400 });
      const created = [];
      for (const [i, pair] of pairs.entries()) created.push(await tx.match.create({ data: { tournamentId: id, team1: pair[0], team2: pair[1], round: tournament.format === 'LEAGUE' ? 'League' : `Round ${round}`, scheduledAt: new Date(start.getTime() + i * interval * 60000), venue: req.body.venue || null } }));
      await tx.tournament.update({ where: { id }, data: { status: 'ONGOING' } });
      return created;
    });
    res.status(201).json({ success: true, data: matches });
  } catch (e) { if (e.code === 'P2025') e.status = 404; next(e); }
};
