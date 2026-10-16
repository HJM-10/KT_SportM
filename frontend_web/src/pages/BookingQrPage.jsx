import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import api from '../api/axios';
export default function BookingQrPage() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [error, setError] = useState('');
  useEffect(() => { api.get(`/bookings/${id}/qr`).then(r => setData(r.data.data)).catch(e => setError(e.response?.data?.message || 'Could not load QR code')); }, [id]);
  return <div className="card text-center"><h1>Booking #{id}</h1>{error ? <p role="alert">{error}</p> : !data ? <p>Loading…</p> : data.booking.status !== 'CONFIRMED' ? <p>Check-in is available only for a confirmed booking.</p> : <><img src={data.qrCode} alt={`Check-in QR for booking ${id}`} width="260" /><p>Present this code to arena staff. It can be checked in once.</p></>}</div>;
}
