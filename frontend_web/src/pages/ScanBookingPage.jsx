import { useState } from 'react';
import api from '../api/axios';
import { ScanLine, CheckCircle, XCircle } from 'lucide-react';
import toast from 'react-hot-toast';

const ScanBookingPage = () => {
  const [qrToken, setQrToken] = useState('');
  const [loading, setLoading] = useState(false);
  const [scanResult, setScanResult] = useState(null);

  const handleScan = async (e) => {
    e.preventDefault();
    if (!qrToken) return;
    
    setLoading(true);
    setScanResult(null);
    try {
      const res = await api.post('/bookings/scan', { qrToken });
      setScanResult({ success: true, data: res.data.data });
      toast.success('Booking verified successfully!');
    } catch (err) {
      setScanResult({ success: false, message: err.response?.data?.message || 'Invalid QR Token' });
      toast.error('Scan failed');
    } finally {
      setLoading(false);
      setQrToken('');
    }
  };

  return (
    <div>
      <div className="page-header text-center">
        <h1 className="page-title">Scan Booking QR</h1>
        <div className="page-subtitle">Verify customer bookings at the venue</div>
      </div>

      <div className="scan-box">
        <div className="card">
          <div style={{ fontSize: 48, marginBottom: 16 }}><ScanLine size={48} className="mx-auto text-primary" /></div>
          
          <form onSubmit={handleScan} className="flex-col gap-16">
            <input
              type="text"
              className="form-input"
              style={{ textAlign: 'center', fontSize: 18, padding: 16 }}
              placeholder="Enter QR Token manually..."
              value={qrToken}
              onChange={e => setQrToken(e.target.value)}
              autoFocus
            />
            <button type="submit" className="btn btn-primary btn-lg btn-full" disabled={loading || !qrToken}>
              {loading ? 'Verifying...' : 'Verify Token'}
            </button>
          </form>
        </div>

        {scanResult && (
          <div className={`scan-result ${scanResult.success ? 'success' : 'error'}`}>
            {scanResult.success ? (
              <>
                <CheckCircle size={48} className="text-success mx-auto mb-16" />
                <h3 className="text-success" style={{ fontSize: 24, marginBottom: 16 }}>Valid Booking!</h3>
                <div className="flex-col gap-8 text-left">
                  <div><strong>Customer:</strong> {scanResult.data.user?.name}</div>
                  <div><strong>Sport:</strong> {scanResult.data.slot?.venue?.sport?.name}</div>
                  <div><strong>Venue:</strong> {scanResult.data.slot?.venue?.name}</div>
                  <div><strong>Time:</strong> {scanResult.data.slot?.startTime} - {scanResult.data.slot?.endTime}</div>
                  <div><strong>Status is now:</strong> SCANNED</div>
                </div>
              </>
            ) : (
              <>
                <XCircle size={48} className="text-danger mx-auto mb-16" />
                <h3 className="text-danger" style={{ fontSize: 24, marginBottom: 8 }}>Invalid QR</h3>
                <p className="text-muted">{scanResult.message}</p>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
};

export default ScanBookingPage;
