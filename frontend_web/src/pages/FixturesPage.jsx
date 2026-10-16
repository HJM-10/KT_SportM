import { useEffect, useState } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';
import FormField from '../components/FormField';
export default function FixturesPage() {
  const [tournaments, setTournaments] = useState([]);
  const [form, setForm] = useState({ id: '', scheduledAt: '', intervalMinutes: 120, venue: '' });
  const [busy, setBusy] = useState(false);
  const [matches, setMatches] = useState([]);
  useEffect(() => { api.get('/tournaments').then(r => setTournaments(r.data.data)).catch(() => toast.error('Could not load tournaments')); }, []);
  const generate = async e => { e.preventDefault(); setBusy(true); try { const r = await api.post(`/tournaments/${form.id}/fixtures`, { ...form, scheduledAt: new Date(form.scheduledAt).toISOString() }); setMatches(r.data.data); toast.success('Fixtures saved'); } catch (e) { toast.error(e.response?.data?.message || 'Could not generate fixtures'); } finally { setBusy(false); } };
  return <div><div className="page-header"><h1 className="page-title">Generate fixtures</h1><p className="page-subtitle">League: each team plays every other team once. Knockout: generate the next round after all current results are recorded. Only paid or free registrations are eligible.</p></div><form className="card form-panel modal-form mb-24" onSubmit={generate}>
    <FormField label="Tournament"><select className="form-input" required value={form.id} onChange={e => setForm({ ...form, id: e.target.value })}><option value="">Choose tournament</option>{tournaments.map(t => <option value={t.id} key={t.id}>{t.name} ({t.format})</option>)}</select></FormField>
    <FormField label="First match time"><input type="datetime-local" required className="form-input" value={form.scheduledAt} onChange={e => setForm({ ...form, scheduledAt: e.target.value })} /></FormField>
    <FormField label="Minutes between matches" hint="Leave enough time for play and venue preparation. Minimum 15 minutes."><input type="number" min="15" required className="form-input" value={form.intervalMinutes} onChange={e => setForm({ ...form, intervalMinutes: e.target.value })} /></FormField>
    <FormField label="Venue"><input className="form-input" value={form.venue} onChange={e => setForm({ ...form, venue: e.target.value })} /></FormField><div className="form-footer"><button className="btn btn-primary" disabled={busy}>{busy ? 'Generating…' : 'Generate and save fixtures'}</button></div></form>
    {matches.map(m => <div key={m.id} className="card mb-16">{m.round}: {m.team1} vs {m.team2} · {new Date(m.scheduledAt).toLocaleString()}</div>)}</div>;
}
