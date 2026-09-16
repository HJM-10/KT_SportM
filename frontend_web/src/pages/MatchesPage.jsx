import { useState, useEffect } from 'react';
import api from '../api/axios';
import { Calendar, Swords } from 'lucide-react';
import useAuthStore from '../store/authStore';
import toast from 'react-hot-toast';

const MatchesPage = () => {
  const [matches, setMatches] = useState([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuthStore();
  const isAdmin = user?.role === 'ADMIN';
  const [scoreModalOpen, setScoreModalOpen] = useState(false);
  const [selectedMatch, setSelectedMatch] = useState(null);
  const [scores, setScores] = useState({ team1: '', team2: '' });

  const fetchMatches = async () => {
    try {
      setLoading(true);
      const res = await api.get('/matches');
      setMatches(res.data.data);
    } catch (err) {
      toast.error('Failed to load matches');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchMatches(); }, []);

  const openScoreModal = (match) => {
    setSelectedMatch(match);
    setScores({ team1: '', team2: '' });
    setScoreModalOpen(true);
  };

  const handleUpdateScore = async (e) => {
    e.preventDefault();
    const score1 = parseInt(scores.team1);
    const score2 = parseInt(scores.team2);
    if (isNaN(score1) || isNaN(score2)) return;
    
    const winner = score1 > score2 ? 'team1' : score2 > score1 ? 'team2' : 'draw';
    
    try {
      await api.put(`/matches/${selectedMatch.id}/result`, {
        team1Score: score1,
        team2Score: score2,
        result: `${score1} - ${score2}`,
        winner
      });
      toast.success('Match updated');
      fetchMatches();
      setScoreModalOpen(false);
    } catch (err) {
      toast.error('Failed to update match');
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">Matches</h1>
        <div className="page-subtitle">Tournament fixtures and results</div>
      </div>

      {loading ? (
        <div className="loader-wrap"><div className="spinner"></div></div>
      ) : matches.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon"><Swords size={48} className="text-muted" /></div>
          <div className="empty-title">No Matches</div>
          <div className="text-muted">No matches have been scheduled yet.</div>
        </div>
      ) : (
        <div className="grid-2">
          {matches.map(m => (
            <div key={m.id} className="match-card flex-col items-start gap-12">
              <div className="flex justify-between w-full">
                <span className="badge badge-secondary">{m.tournament?.name}</span>
                <span className="text-muted flex items-center gap-8"><Calendar size={14}/> {new Date(m.scheduledAt).toLocaleString()}</span>
              </div>
              
              <div className="match-teams w-full mt-8">
                <div className="flex-1 text-right">{m.team1} {m.team1Score !== null && <span className="match-score ml-8">{m.team1Score}</span>}</div>
                <div className="match-vs">VS</div>
                <div className="flex-1">{m.team2Score !== null && <span className="match-score mr-8">{m.team2Score}</span>} {m.team2}</div>
              </div>

              {isAdmin && !m.isCompleted && (
                <button className="btn btn-primary btn-sm btn-full mt-8" onClick={() => openScoreModal(m)}>
                  Update Result
                </button>
              )}
              {m.isCompleted && (
                <div className="w-full text-center mt-8 text-muted">
                  Winner: <strong>{m.winner === 'team1' ? m.team1 : m.winner === 'team2' ? m.team2 : 'Draw'}</strong>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {scoreModalOpen && selectedMatch && (
        <div className="modal-overlay">
          <div className="modal" style={{ maxWidth: '400px' }}>
            <div className="modal-header">
              <h2 className="modal-title">Update Match Score</h2>
              <button className="modal-close" onClick={() => setScoreModalOpen(false)}>×</button>
            </div>
            <form className="modal-form" onSubmit={handleUpdateScore}>
              <div className="form-group">
                <label className="form-label">{selectedMatch.team1} Score</label>
                <input type="number" required className="form-input" value={scores.team1} onChange={e => setScores({...scores, team1: e.target.value})} />
              </div>
              <div className="form-group">
                <label className="form-label">{selectedMatch.team2} Score</label>
                <input type="number" required className="form-input" value={scores.team2} onChange={e => setScores({...scores, team2: e.target.value})} />
              </div>
              <div className="modal-actions">
                <button type="button" className="btn btn-secondary" onClick={() => setScoreModalOpen(false)}>Cancel</button>
                <button type="submit" className="btn btn-primary">Save Result</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default MatchesPage;
