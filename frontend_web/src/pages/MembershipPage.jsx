import { useEffect, useState } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';
import PaymentModal from '../components/PaymentModal';
export default function MembershipPage() {
  const [membership, setMembership] = useState(null);
  const [payment, setPayment] = useState(null);
  const [busy, setBusy] = useState(false);
  const load = () => api.get('/membership/my').then(r => setMembership(r.data.data)).catch(() => toast.error('Could not load membership'));
  useEffect(() => { load(); }, []);
  const purchase = async tier => {
    setBusy(true);
    try { const r = await api.post('/membership/purchase', { tier }); if (r.data.data.paymentId) setPayment({ paymentId: r.data.data.paymentId, amount: tier === 'GOLD' ? 2500 : 1000 }); await load(); }
    catch (e) { toast.error(e.response?.data?.message || 'Could not request membership'); }
    finally { setBusy(false); }
  };
  return <div><div className="page-header"><h1 className="page-title">Membership</h1><p className="page-subtitle">Your arena membership card and booking benefits</p></div>
    {membership && <div className="card mb-24"><h2>{membership.tier}</h2><p>{membership.cardNumber}</p><p>{membership.isActive ? 'Active' : 'Awaiting payment'}</p><button className="btn btn-secondary" onClick={load}>Refresh status</button></div>}
    <div className="grid-3">{[['BASIC', 0, 0], ['SILVER', 1000, 10], ['GOLD', 2500, 20]].map(([tier, price, discount]) => <div key={tier} className="card"><h2>{tier}</h2><p>PKR {price}</p><p className="mb-16">{discount}% off venue bookings</p><button className="btn btn-primary" disabled={busy} onClick={() => purchase(tier)}>Choose {tier}</button></div>)}</div>
    <PaymentModal isOpen={!!payment} {...payment} onClose={() => setPayment(null)} /></div>;
}
