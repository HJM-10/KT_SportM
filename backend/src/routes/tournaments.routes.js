const router = require('express').Router();
const { getTournaments, getTournamentById, createTournament, updateTournament, registerForTournament } = require('../controllers/tournaments.controller');
const { authenticate, requireAdmin } = require('../middleware/auth');

router.get('/', getTournaments);
router.get('/:id', getTournamentById);
router.post('/', authenticate, requireAdmin, createTournament);
router.put('/:id', authenticate, requireAdmin, updateTournament);
router.post('/:id/register', authenticate, registerForTournament);

module.exports = router;
