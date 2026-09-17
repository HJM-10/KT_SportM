import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';

import Layout from './components/Layout';
import ProtectedRoute from './components/ProtectedRoute';

import LoginPage from './pages/LoginPage';
import SignupPage from './pages/SignupPage';
import DashboardPage from './pages/DashboardPage';
import SportsPage from './pages/SportsPage';
import TournamentsPage from './pages/TournamentsPage';
import MatchesPage from './pages/MatchesPage';
import BookingsPage from './pages/BookingsPage';
import MyBookingsPage from './pages/MyBookingsPage';
import ScanBookingPage from './pages/ScanBookingPage';
import SettingsPage from './pages/SettingsPage';

import EventsPage from './pages/EventsPage';
import EquipmentPage from './pages/EquipmentPage';
import ComplaintsPage from './pages/ComplaintsPage';
import PromoCodesPage from './pages/PromoCodesPage';
import ReportsPage from './pages/ReportsPage';
import PaymentsPage from './pages/PaymentsPage';
import UsersPage from './pages/UsersPage';

function App() {
  return (
    <Router>
      <Toaster position="top-right" toastOptions={{ style: { background: '#16162a', color: '#fff', border: '1px solid rgba(255,255,255,0.1)' } }} />
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route path="/signup" element={<SignupPage />} />

        <Route path="/" element={<ProtectedRoute><Layout /></ProtectedRoute>}>
          <Route index element={<DashboardPage />} />
          <Route path="sports" element={<SportsPage />} />
          <Route path="tournaments" element={<TournamentsPage />} />
          <Route path="matches" element={<MatchesPage />} />
          <Route path="my-bookings" element={<MyBookingsPage />} />
          <Route path="settings" element={<SettingsPage />} />
          
          <Route path="events" element={<EventsPage />} />
          <Route path="equipment" element={<EquipmentPage />} />
          <Route path="complaints" element={<ComplaintsPage />} />
          
          {/* Admin Routes */}
          <Route path="bookings" element={<ProtectedRoute adminOnly><BookingsPage /></ProtectedRoute>} />
          <Route path="scan" element={<ProtectedRoute adminOnly><ScanBookingPage /></ProtectedRoute>} />
          <Route path="promo" element={<ProtectedRoute adminOnly><PromoCodesPage /></ProtectedRoute>} />
          <Route path="reports" element={<ProtectedRoute adminOnly><ReportsPage /></ProtectedRoute>} />
          <Route path="payments" element={<ProtectedRoute adminOnly><PaymentsPage /></ProtectedRoute>} />
          <Route path="users" element={<ProtectedRoute adminOnly><UsersPage /></ProtectedRoute>} />
        </Route>

        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Router>
  );
}

export default App;
