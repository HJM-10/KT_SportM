import { useState, useEffect } from 'react';
import api from '../api/axios';
import { Calendar, Clock, MapPin, CalendarCheck } from 'lucide-react';
import toast from 'react-hot-toast';
import { useNavigate } from 'react-router-dom';
import ConfirmModal from '../components/ConfirmModal';
import SportIcon from '../components/SportIcon';

const MyBookingsPage = () => {
  const [bookings, setBookings] = useState([]);
  const [loading, setLoading] = useState(true);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [bookingToCancel, setBookingToCancel] = useState(null);
  const navigate = useNavigate();

  const fetchBookings = async () => {
    try {
      setLoading(true);
      const res = await api.get('/bookings/my');
      setBookings(res.data.data);
    } catch (err) {
      toast.error('Failed to load your bookings');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchBookings(); }, []);

  const confirmCancel = (id) => {
    setBookingToCancel(id);
    setConfirmOpen(true);
  };

  const handleCancel = async () => {
    if (!bookingToCancel) return;
    try {
      await api.put(`/bookings/${bookingToCancel}/cancel`);
      toast.success('Booking cancelled');
      fetchBookings();
    } catch (err) {
      toast.error(err.response?.data?.message || 'Failed to cancel booking');
    } finally {
      setConfirmOpen(false);
      setBookingToCancel(null);
    }
  };

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">My Bookings</h1>
        <div className="page-subtitle">Your reserved slots and history</div>
      </div>

      {loading ? (
        <div className="loader-wrap"><div className="spinner"></div></div>
      ) : bookings.length === 0 ? (
        <div className="empty-state">
          <div className="empty-icon"><CalendarCheck size={48} className="text-muted" /></div>
          <div className="empty-title">No Bookings Yet</div>
          <div className="text-muted">You haven't made any reservations. Use the mobile app to book a slot.</div>
        </div>
      ) : (
        <div className="grid-3">
          {bookings.map(b => (
            <div key={b.id} className="card">
              <div className="flex justify-between items-center mb-16">
                <span className={`badge badge-${b.status === 'CONFIRMED' ? 'primary' : b.status === 'SCANNED' ? 'success' : 'danger'}`}>
                  {b.status}
                </span>
                <span className="text-muted">#{b.id}</span>
              </div>
              
              <h3 style={{fontSize: 18, fontWeight: 700, marginBottom: 16}}>
                <SportIcon iconName={b.slot?.venue?.sport?.icon} size={18} className="mr-8" /> 
                {b.slot?.venue?.sport?.name}
              </h3>

              <div className="flex-col gap-8 mb-24">
                <div className="flex items-center gap-8 text-muted"><MapPin size={16} /> {b.slot?.venue?.name}</div>
                <div className="flex items-center gap-8 text-muted"><Calendar size={16} /> {new Date(b.slot?.date).toLocaleDateString()}</div>
                <div className="flex items-center gap-8 text-muted"><Clock size={16} /> {b.slot?.startTime} - {b.slot?.endTime}</div>
              </div>

              <div className="flex justify-between items-center mt-16 pt-16" style={{ borderTop: '1px solid var(--border)' }}>
                <div style={{fontWeight: 700, fontSize: 18}}>${b.totalPrice}</div>
                
                <div className="flex gap-8">
                  {b.status === 'CONFIRMED' && (
                    <>
                      <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/my-bookings/${b.id}/qr`)}>
                        Show QR
                      </button>
                      <button className="btn btn-danger btn-sm" onClick={() => confirmCancel(b.id)}>
                        Cancel
                      </button>
                    </>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      <ConfirmModal 
        isOpen={confirmOpen}
        title="Cancel Booking"
        message="Are you sure you want to cancel this booking? This action cannot be undone."
        onConfirm={handleCancel}
        onCancel={() => setConfirmOpen(false)}
        confirmText="Cancel Booking"
      />
    </div>
  );
};

export default MyBookingsPage;
