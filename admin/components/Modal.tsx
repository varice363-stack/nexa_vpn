'use client';

import { ReactNode } from 'react';

interface ModalProps {
  title: string;
  onClose: () => void;
  children: ReactNode;
}

export default function Modal({ title, onClose, children }: ModalProps) {
  return (
    <div className="fixed inset-0 z-50 grid place-items-center bg-black/60 backdrop-blur-sm">
      <div className="w-full max-w-lg glass p-6 rounded-2xl bg-elevated/90">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-lg">{title}</h3>
          <button onClick={onClose} className="text-muted hover:text-text text-xl leading-none">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}
