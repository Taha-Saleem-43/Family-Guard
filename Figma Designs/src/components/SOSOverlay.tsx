import { useEffect, useState } from 'react';
import type { SOSState, Member } from '../types';

interface Props {
  state: SOSState;
  onStateChange: (s: SOSState) => void;
  sender: Member;
}

export default function SOSOverlay({ state, onStateChange, sender }: Props) {
  const [countdown, setCountdown] = useState(3);

  useEffect(() => {
    if (state !== 'countdown') return;
    if (countdown <= 0) { onStateChange('active'); return; }
    const t = setTimeout(() => setCountdown(c => c - 1), 1000);
    return () => clearTimeout(t);
  }, [state, countdown]);

  if (state === 'countdown') {
    return (
      <div className="absolute inset-0 z-50 bg-danger flex flex-col items-center justify-center animate-fade-in">
        <div className="text-white/80 font-bold text-lg mb-8">Sending SOS in…</div>
        <div className="relative w-40 h-40 flex items-center justify-center mb-8">
          <svg className="absolute inset-0 -rotate-90" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="45" fill="none" stroke="rgba(255,255,255,0.2)" strokeWidth="6" />
            <circle
              cx="50" cy="50" r="45" fill="none" stroke="white" strokeWidth="6"
              strokeDasharray="283"
              strokeDashoffset={283 - (countdown / 3) * 283}
              strokeLinecap="round"
              style={{ transition: 'stroke-dashoffset 0.9s linear' }}
            />
          </svg>
          <span className="text-white font-black" style={{ fontSize: 72 }}>{countdown}</span>
        </div>
        <button
          onClick={() => { onStateChange('none'); setCountdown(3); }}
          className="bg-white/20 text-white font-bold text-xl px-12 py-5 rounded-full border-2 border-white/40 active:scale-95 transition-transform"
        >
          Cancel
        </button>
        <p className="text-white/60 text-sm font-medium mt-6 px-8 text-center">
          Tap Cancel to stop. Letting the countdown finish sends your live location to all Circle members.
        </p>
      </div>
    );
  }

  if (state === 'active') {
    return (
      <div className="absolute inset-0 z-50 bg-danger flex flex-col animate-fade-in">
        {/* Header */}
        <div className="flex flex-col items-center pt-16 pb-6 px-6 text-white text-center">
          <div className="w-20 h-20 rounded-full bg-white/20 flex items-center justify-center mb-4 sos-beat">
            <span className="text-4xl">🆘</span>
          </div>
          <h2 className="text-3xl font-black mb-2">SOS Alert Active</h2>
          <p className="text-white/80 font-medium">Your live location is being sent to all Circle members.</p>
        </div>

        {/* Live location card */}
        <div className="mx-5 bg-white/10 rounded-2xl p-4 mb-4">
          <div className="flex items-center gap-3 text-white">
            <span className="text-2xl">📍</span>
            <div>
              <div className="font-black text-lg">142 Maple Street</div>
              <div className="text-white/80 text-sm font-medium">Sending real-time updates · Now</div>
            </div>
            <span className="ml-auto text-white/80 font-bold text-sm">LIVE</span>
          </div>
        </div>

        {/* Notified members */}
        <div className="mx-5 bg-white/10 rounded-2xl p-4 mb-6">
          <div className="text-white/70 text-xs font-bold mb-3 uppercase tracking-wider">Notified</div>
          {[
            { name: 'Emma', initials: 'EM', color: '#2563EB', status: '✓ Seen' },
            { name: 'Jake', initials: 'JK', color: '#D97706', status: 'Pending…' },
          ].map(m => (
            <div key={m.name} className="flex items-center gap-3 py-2">
              <div className="w-9 h-9 rounded-full flex items-center justify-center text-white font-black text-sm" style={{ background: m.color + '88' }}>
                {m.initials}
              </div>
              <span className="text-white font-bold flex-1">{m.name}</span>
              <span className="text-white/70 text-sm font-medium">{m.status}</span>
            </div>
          ))}
        </div>

        <div className="flex-1" />

        <div className="px-5 pb-10 space-y-3">
          <button className="w-full bg-white text-danger font-black text-lg py-4 rounded-2xl active:scale-95 transition-transform shadow-lg">
            📞 Call 911
          </button>
          <button
            onClick={() => onStateChange('resolved')}
            className="w-full bg-white/20 text-white font-bold text-lg py-4 rounded-2xl border border-white/30 active:scale-95 transition-transform"
          >
            ✓ I'm safe — Cancel SOS
          </button>
        </div>
      </div>
    );
  }

  if (state === 'received') {
    return (
      <div className="absolute inset-0 z-50 bg-danger flex flex-col animate-fade-in">
        <div className="flex flex-col items-center pt-16 pb-6 px-6 text-white text-center">
          <div className="w-20 h-20 rounded-full bg-white/20 flex items-center justify-center mb-4 sos-beat">
            <span className="text-5xl">⚠️</span>
          </div>
          <div className="text-white/80 font-bold text-sm uppercase tracking-wider mb-2">Emergency Alert</div>
          <h2 className="text-3xl font-black mb-2">{sender.name} needs help</h2>
          <p className="text-white/80 font-medium">SOS sent at 3:42 PM · Live location below</p>
        </div>
        <div className="mx-5 bg-white/10 rounded-2xl p-4 mb-6">
          <div className="flex items-center gap-3 text-white mb-3">
            <span className="text-2xl">📍</span>
            <div>
              <div className="font-black">142 Maple Street</div>
              <div className="text-white/70 text-sm font-medium">Updated just now · LIVE</div>
            </div>
          </div>
        </div>
        <div className="px-5 space-y-3 pb-10">
          <button className="w-full bg-white text-danger font-black text-lg py-4 rounded-2xl active:scale-95 transition-transform">📞 Call {sender.name}</button>
          <button className="w-full bg-white/20 text-white font-bold text-lg py-4 rounded-2xl border border-white/30 active:scale-95 transition-transform">🗺️ Get Directions</button>
          <button onClick={() => onStateChange('resolved')} className="w-full bg-white/10 text-white font-bold py-3 rounded-2xl active:scale-95 transition-transform text-sm">
            ✓ Acknowledge — I'm responding
          </button>
        </div>
      </div>
    );
  }

  if (state === 'resolved') {
    return (
      <div className="absolute inset-0 z-50 bg-success flex flex-col items-center justify-center animate-fade-in">
        <div className="text-6xl mb-6">✅</div>
        <h2 className="text-3xl font-black text-white mb-3">All clear</h2>
        <p className="text-white/80 font-medium text-center px-8">The SOS alert has been cancelled. Everyone is safe.</p>
        <button
          onClick={() => onStateChange('none')}
          className="mt-12 bg-white text-success font-black text-lg px-10 py-4 rounded-full shadow-lg active:scale-95 transition-transform"
        >
          Back to map
        </button>
      </div>
    );
  }

  return null;
}
