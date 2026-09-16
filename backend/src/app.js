require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const authRoutes = require('./routes/auth.routes');
const sportsRoutes = require('./routes/sports.routes');
const venuesRoutes = require('./routes/venues.routes');
const bookingsRoutes = require('./routes/bookings.routes');
const tournamentsRoutes = require('./routes/tournaments.routes');
const matchesRoutes = require('./routes/matches.routes');
const errorHandler = require('./middleware/errorHandler');

const app = express();

// Middleware
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000'],
  credentials: true
}));
app.use(express.json());
app.use(morgan('dev'));

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    status: 'ok',
    message: 'Smart Sports Hub API is running!',
    timestamp: new Date().toISOString()
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/sports', sportsRoutes);
app.use('/api/venues', venuesRoutes);
app.use('/api/bookings', bookingsRoutes);
app.use('/api/tournaments', tournamentsRoutes);
app.use('/api/matches', matchesRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found` });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`\n🚀 Smart Sports Hub API running on http://localhost:${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/api/health\n`);
});

module.exports = app;
