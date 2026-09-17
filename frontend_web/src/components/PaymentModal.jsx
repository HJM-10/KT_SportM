import { useState } from 'react';
import { CreditCard, Lock, X } from 'lucide-react';
import toast from 'react-hot-toast';
import api from '../api/axios';

const PaymentModal = ({ isOpen, onClose, amount, paymentId, paymentIntentId, onSuccess }) => {
  const [loading, setLoading] = useState(false);
  const [card, setCard] = useState({ number: '', expiry: '', cvc: '', name: '' });

  if (!isOpen) return null;

  const handlePayment = async (e) => {
    e.preventDefault();
    if (card.number.length < 16) {
      toast.error('Invalid card number');
      return;
    }
    
    try {
      setLoading(true);
      // Simulate network delay for stripe dummy
      await new Promise(r => setTimeout(r, 1500));
      
      const res = await api.put('/payments/confirm', {
        paymentId,
        paymentIntentId
      });
      
      toast.success('Payment successful!');
      onSuccess(res.data.data);
    } catch (err) {
      toast.error(err.response?.data?.message || 'Payment failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop">
      <div className="modal-content" style={{maxWidth: 450, padding: '24px 32px'}}>
        <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24}}>
          <div style={{display: 'flex', alignItems: 'center', gap: 12}}>
            <div style={{
              width: 40, height: 40, borderRadius: '8px', 
              background: 'rgba(99,102,241,0.1)', color: 'var(--primary)',
              display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>
              <CreditCard size={24} />
            </div>
            <div>
              <h2 style={{margin: 0, fontSize: 18}}>Complete Payment</h2>
              <div className="text-muted" style={{fontSize: 13}}>Dummy Stripe Integration</div>
            </div>
          </div>
          <button onClick={onClose} style={{background: 'transparent', border: 'none', color: '#888', cursor: 'pointer'}}>
            <X size={24} />
          </button>
        </div>

        <div style={{background: 'var(--bg-lighter)', padding: 16, borderRadius: 8, marginBottom: 24, textAlign: 'center'}}>
          <div className="text-muted" style={{marginBottom: 4}}>Total Amount Due</div>
          <div style={{fontSize: 32, fontWeight: 700, color: 'var(--success)'}}>Rs. {amount}</div>
        </div>

        <form onSubmit={handlePayment}>
          <div className="form-group">
            <label>Cardholder Name</label>
            <input 
              type="text" 
              className="form-control" 
              placeholder="e.g. John Doe"
              value={card.name}
              onChange={e => setCard({...card, name: e.target.value})}
              required
            />
          </div>
          <div className="form-group">
            <label>Card Number</label>
            <div style={{position: 'relative'}}>
              <input 
                type="text" 
                className="form-control" 
                placeholder="0000 0000 0000 0000"
                maxLength={16}
                value={card.number}
                onChange={e => setCard({...card, number: e.target.value.replace(/\D/g, '')})}
                required
                style={{paddingLeft: 40}}
              />
              <CreditCard size={18} style={{position: 'absolute', left: 12, top: 11, color: '#888'}} />
            </div>
          </div>
          <div style={{display: 'flex', gap: 16}}>
            <div className="form-group" style={{flex: 1}}>
              <label>Expiry Date</label>
              <input 
                type="text" 
                className="form-control" 
                placeholder="MM/YY"
                maxLength={5}
                value={card.expiry}
                onChange={e => setCard({...card, expiry: e.target.value})}
                required
              />
            </div>
            <div className="form-group" style={{flex: 1}}>
              <label>CVC</label>
              <input 
                type="text" 
                className="form-control" 
                placeholder="123"
                maxLength={4}
                value={card.cvc}
                onChange={e => setCard({...card, cvc: e.target.value.replace(/\D/g, '')})}
                required
              />
            </div>
          </div>

          <button 
            type="submit" 
            className="btn btn-primary" 
            style={{width: '100%', padding: '14px', marginTop: 12, fontSize: 16, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8}}
            disabled={loading}
          >
            {loading ? <div className="spinner" style={{width: 20, height: 20, borderWidth: 2}}></div> : (
              <>
                <Lock size={16} /> Pay Rs. {amount}
              </>
            )}
          </button>
        </form>
      </div>
    </div>
  );
};

export default PaymentModal;
