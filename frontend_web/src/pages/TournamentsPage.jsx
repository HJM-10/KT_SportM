import { useState, useEffect } from 'react';
import api from '../api/axios';
import { Calendar, Users, Trophy } from 'lucide-react';
import useAuthStore from '../store/authStore';
import toast from 'react-hot-toast';
import SportIcon from '../components/SportIcon';

const TournamentsPage = () => {
  const [tournaments, setTournaments] = useState([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';

  const fetchTournaments = async () => {
    try {
      setLoading(true);
      const res = await api.get('/tournaments');
      setTournaments(res.data.data);
    } catch (err) {
      toast.error('Failed to load tournaments');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchTournaments(); }, []);

  const handleRegister = async (tournamentId) => {
    try {
      await api.post(`/tournaments/${tournamentId}/register`, { teamName: `${user.name}'s Team` });
      toast.success('Successfully registered for tournament!');
      fetchTournaments();
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to register');
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Tournaments</h1>
        <div className="page-subtitle">Join or manage upcoming events and tournaments</div>
      </div>

      {loading ? (
        <div className="loader-wrap"><div className="spinner"></div></div>
      ) : tournaments.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon"><Trophy size={48} className="text-muted" /></div>
          <div className="empty-title">No Tournaments</div>
          <div className="text-muted">There are no tournaments at the moment.</div>
        </div>
      ) : (
        <div className="grid-3">
          {tournaments.map(t => (
            <div key={t.id} className="tournament-card">
              <div className="tournament-card-body">
                <div className="tournament-sport-badge">
                  <SportIcon iconName={t.sport?.icon} size={14} /> {t.sport?.name}
                </div>
                <h3 className="tournament-name">{t.name}</h3>
                
                <div className="tournament-meta mb-16">
                  <div className="tournament-meta-item"><Calendar size={14} /> {new Date(t.startDate).toLocaleDateString()}</div>
                  <div className="tournament-meta-item"><Users size={14} /> {t._count?.registrations} / {t.maxTeams} Teams</div>
                  <div className="tournament-meta-item"><Trophy size={14} /> {t.format}</div>
                </div>

                <div className="flex justify-between items-center mt-8 pt-16" style={{ borderTop: '1px solid var(--border)' }}>
                  <span className={`badge badge-${t.status === 'UPCOMING' ? 'primary' : t.status === 'ONGOING' ? 'warning' : 'success'}`}>
                    {t.status}
                  </span>
                  
                  {!isAdmin && t.status === 'UPCOMING' && (
                    <button className="btn btn-primary btn-sm" onClick={() => handleRegister(t.id)}>
                      Register Now
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default TournamentsPage;
