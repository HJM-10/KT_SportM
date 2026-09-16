import React from 'react';
import { AlertTriangle } from 'lucide-react';

const ConfirmModal = ({ isOpen, title, message, onConfirm, onCancel, confirmText = 'Confirm', cancelText = 'Cancel' }) => {
  if (!isOpen) return null;

  return (
    <div className="modal-overlay">
      <div className="modal" style={{ maxWidth: '400px' }}>
        <div className="modal-header" style={{ marginBottom: '16px' }}>
          <h2 className="modal-title flex items-center gap-8" style={{ color: 'var(--danger)' }}>
            <AlertTriangle size={24} /> {title}
          </h2>
        </div>
        <div className="modal-body" style={{ marginBottom: '24px', color: 'var(--text-muted)' }}>
          {message}
        </div>
        <div className="modal-actions">
          <button className="btn btn-secondary" onClick={onCancel}>{cancelText}</button>
          <button className="btn btn-danger" onClick={onConfirm}>{confirmText}</button>
        </div>
      </div>
    </div>
  );
};

export default ConfirmModal;
