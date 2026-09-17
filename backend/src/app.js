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
const paymentsRoutes = require('./routes/payments.routes');
const reviewsRoutes = require('./routes/reviews.routes');
const complaintsRoutes = require('./routes/complaints.routes');
const eventsRoutes = require('./routes/events.routes');
const equipmentRoutes = require('./routes/equipment.routes');
const promoRoutes = require('./routes/promo.routes');
const membershipRoutes = require('./routes/membership.routes');
const notificationsRoutes = require('./routes/notifications.routes');
const recommendationsRoutes = require('./routes/recommendations.routes');
const reportsRoutes = require('./routes/reports.routes');
const usersRoutes = require('./routes/users.routes');
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
app.use('/api/payments', paymentsRoutes);
app.use('/api/reviews', reviewsRoutes);
app.use('/api/complaints', complaintsRoutes);
app.use('/api/events', eventsRoutes);
app.use('/api/equipment', equipmentRoutes);
app.use('/api/promo', promoRoutes);
app.use('/api/membership', membershipRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/recommendations', recommendationsRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/users', usersRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.method} ${req.path} not found` });
});

// Error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: 'Internal server error' });
});

const http = require('http');
const socket = require('./lib/socket');

const PORT = process.env.PORT || 5000;
const server = http.createServer(app);

// Initialize Socket.io
socket.init(server);

server.listen(PORT, () => {
  console.log(`\n🚀 Smart Sports Hub API running on http://localhost:${PORT}`);
  console.log(`   Health: http://localhost:${PORT}/api/health\n`);
});

module.exports = { app, server };
