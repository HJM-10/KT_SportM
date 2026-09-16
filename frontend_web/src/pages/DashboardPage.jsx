import { useEffect, useState } from 'react';
import { CalendarCheck, Dumbbell, Trophy, Users } from 'lucide-react';
import useAuthStore from '../store/authStore';
import api from '../api/axios';

const DashboardPage = () => {
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';
  const [stats, setStats] = useState(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        if (isAdmin) {
          const [bookingsRes, sportsRes, tournamentsRes] = await Promise.all([
            api.get('/bookings'),
            api.get('/sports'),
            api.get('/tournaments')
          ]);
          setStats({
            totalBookings: bookingsRes.data.data.length,
            activeSports: sportsRes.data.data.length,
            tournaments: tournamentsRes.data.data.length,
            revenue: bookingsRes.data.data.reduce((acc, b) => acc + (b.status !== 'CANCELLED' ? b.totalPrice : 0), 0)
          });
        } else {
          const bookingsRes = await api.get('/bookings/my');
          setStats({
            myBookings: bookingsRes.data.data.length,
            upcoming: bookingsRes.data.data.filter(b => b.status === 'CONFIRMED' && new Date(b.slot.date) >= new Date()).length
          });
        }
      } catch (err) {
        console.error(err);
      }
    };
    fetchStats();
  }, [isAdmin]);

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Dashboard</h1>
        <div className="page-subtitle">Welcome back, {user?.name}</div>
      </div>

      {stats ? (
        <div className="stats-grid">
          {isAdmin ? (
            <>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(99,102,241,0.15)', color: 'var(--primary-light)' }}><CalendarCheck /></div>
                <div>
                  <div className="stat-value">{stats.totalBookings}</div>
                  <div className="stat-label">Total Bookings</div>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(16,185,129,0.15)', color: 'var(--success)' }}><span>$</span></div>
                <div>
                  <div className="stat-value">${stats.revenue}</div>
                  <div className="stat-label">Total Revenue</div>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(245,158,11,0.15)', color: 'var(--warning)' }}><Dumbbell /></div>
                <div>
                  <div className="stat-value">{stats.activeSports}</div>
                  <div className="stat-label">Active Sports</div>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(6,182,212,0.15)', color: 'var(--secondary)' }}><Trophy /></div>
                <div>
                  <div className="stat-value">{stats.tournaments}</div>
                  <div className="stat-label">Tournaments</div>
                </div>
              </div>
            </>
          ) : (
             <>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(99,102,241,0.15)', color: 'var(--primary-light)' }}><CalendarCheck /></div>
                <div>
                  <div className="stat-value">{stats.myBookings}</div>
                  <div className="stat-label">Total Bookings</div>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon" style={{ background: 'rgba(16,185,129,0.15)', color: 'var(--success)' }}><CalendarCheck /></div>
                <div>
                  <div className="stat-value">{stats.upcoming}</div>
                  <div className="stat-label">Upcoming Bookings</div>
                </div>
              </div>
             </>
          )}
        </div>
      ) : (
        <div className="loader-wrap"><div className="spinner"></div></div>
      )}
    </div>
  );
};

export default DashboardPage;
