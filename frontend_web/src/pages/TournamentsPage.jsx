import { useState, useEffect } from 'react';
import api from '../api/axios';
import { Calendar, Users, Trophy } from 'lucide-react';
import toast from 'react-hot-toast';
import SportIcon from '../components/SportIcon';
import PaymentModal from '../components/PaymentModal';
import useAuthStore from '../store/authStore';

const TournamentsPage = () => {
  const [tournaments, setTournaments] = useState([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';
  
  const [paymentData, setPaymentData] = useState(null);
  const [showPayment, setShowPayment] = useState(false);

  const [adminTournament, setAdminTournament] = useState(null);
  const [showAdminModal, setShowAdminModal] = useState(false);

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
      const res = await api.post(`/tournaments/${tournamentId}/register`, { teamName: `${user.name}'s Team` });
      const { paymentId, clientSecret } = res.data.data;
      
      if (paymentId && clientSecret) {
        setPaymentData({ 
          paymentId, 
          paymentIntentId: clientSecret.split('_secret_')[0],
          amount: tournaments.find(t => t.id === tournamentId).entryFee
        });
        setShowPayment(true);
      } else {
        toast.success('Successfully registered for tournament!');
        fetchTournaments();
      }
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to register');
    }
  };

  const handlePaymentSuccess = () => {
    setShowPayment(false);
    fetchTournaments();
  };

  const handleViewRegistrations = async (id) => {
    try {
      const res = await api.get(`/tournaments/${id}`);
      if (res.data.success) {
        setAdminTournament(res.data.data);
        setShowAdminModal(true);
      }
    } catch (err) {
      toast.error('Failed to load tournament details');
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
                  {isAdmin && (
                    <button className="btn btn-outline btn-sm" onClick={() => handleViewRegistrations(t.id)}>
                      View Registrations
                    </button>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {showPayment && paymentData && (
        <PaymentModal 
          isOpen={showPayment}
          onClose={() => setShowPayment(false)}
          amount={paymentData.amount}
          paymentId={paymentData.paymentId}
          paymentIntentId={paymentData.paymentIntentId}
          onSuccess={handlePaymentSuccess}
        />
      )}

      {showAdminModal && adminTournament && (
        <div className="modal-backdrop">
          <div className="modal-content" style={{maxWidth: 700}}>
            <div style={{display: 'flex', justifyContent: 'space-between', marginBottom: 24}}>
              <h2>Registrations: {adminTournament.name}</h2>
              <button onClick={() => setShowAdminModal(false)} className="btn btn-sm btn-outline">Close</button>
            </div>
            
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Team Name</th>
                    <th>Captain</th>
                    <th>Payment Status</th>
                  </tr>
                </thead>
                <tbody>
                  {adminTournament.registrations.map(r => (
                    <tr key={r.id}>
                      <td style={{fontWeight: 600}}>{r.teamName}</td>
                      <td>{r.user?.name}</td>
                      <td>
                        {r.payment ? (
                          <span className={`badge badge-${r.payment.status === 'PAID' ? 'success' : 'warning'}`}>
                            {r.payment.status}
                          </span>
                        ) : (
                          <span className="badge badge-secondary">FREE</span>
                        )}
                      </td>
                    </tr>
                  ))}
                  {adminTournament.registrations.length === 0 && (
                    <tr><td colSpan="3" className="text-center py-8">No registrations yet</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default TournamentsPage;
