import type { Member } from '../types';

interface Props {
  member: Member;
  onClose: () => void;
}

function BatteryIcon({ level }: { level: number }) {
  const color = level < 20 ? '#DC2626' : level < 50 ? '#D97706' : '#16A34A';
  return (
    <span className="inline-flex items-center gap-1 text-xs font-bold" style={{ color }}>
      <span className="relative inline-block w-5 h-3 rounded-sm border border-current">
        <span
          className="absolute inset-y-0.5 left-0.5 rounded-sm"
          style={{ width: `${Math.max(4, level * 0.8)}%`, background: color, right: 'auto' }}
        />
      </span>
      {level}%
    </span>
  );
}

export default function MemberDetailSheet({ member, onClose }: Props) {
  return (
    <div className="animate-slide-up bg-white rounded-t-3xl shadow-2xl pb-safe">
      <div className="drag-handle" />

      {/* Header */}
      <div className="px-5 pb-4 flex items-start justify-between">
        <div className="flex items-center gap-3">
          <div
            className="w-14 h-14 rounded-full flex items-center justify-center text-white font-black text-xl shadow-lg"
            style={{ background: member.pinColor }}
          >
            {member.initials}
          </div>
          <div>
            <div className="font-black text-text text-xl">{member.name}</div>
            <div className="text-muted font-semibold text-sm flex items-center gap-2">
              <span
                className="inline-block w-2 h-2 rounded-full"
                style={{ background: member.isStale ? '#94A3B8' : '#16A34A' }}
              />
              {member.isStale ? `Last seen ${member.lastSeen}` : 'Live location'}
            </div>
          </div>
        </div>
        <button onClick={onClose} className="w-8 h-8 flex items-center justify-center rounded-full bg-bg text-muted font-bold text-lg">×</button>
      </div>

      {/* Location card */}
      <div className="mx-5 bg-bg rounded-2xl p-4 mb-4">
        <div className="flex items-start gap-3">
          <span className="text-2xl mt-0.5">📍</span>
          <div>
            <div className="font-black text-text">{member.location}</div>
            <div className="text-muted text-sm font-medium">{member.address}</div>
            <div className="text-muted text-xs font-medium mt-1">Updated {member.lastSeen}</div>
          </div>
        </div>
        {member.isMoving && member.speed && (
          <div className="mt-3 pt-3 border-t border-border flex items-center gap-2 text-sm">
            <span>🚶</span>
            <span className="text-text font-bold">Moving</span>
            <span className="text-muted font-medium">at {member.speed} mph</span>
          </div>
        )}
      </div>

      {/* Stats row */}
      <div className="mx-5 flex gap-3 mb-5">
        <div className="flex-1 bg-bg rounded-2xl p-3 text-center">
          <div className="text-xs text-muted font-semibold mb-1">Battery</div>
          <BatteryIcon level={member.battery} />
        </div>
        <div className="flex-1 bg-bg rounded-2xl p-3 text-center">
          <div className="text-xs text-muted font-semibold mb-1">Status</div>
          <span className="text-xs font-bold" style={{ color: member.isMoving ? '#D97706' : '#16A34A' }}>
            {member.isMoving ? '🚶 Moving' : '📍 Stationary'}
          </span>
        </div>
        <div className="flex-1 bg-bg rounded-2xl p-3 text-center">
          <div className="text-xs text-muted font-semibold mb-1">Updated</div>
          <span className="text-xs font-bold text-text">{member.lastSeen}</span>
        </div>
      </div>

      {/* Quick actions */}
      <div className="mx-5 flex gap-3 mb-6">
        <button className="flex-1 flex flex-col items-center gap-1 bg-primary-light text-primary font-bold rounded-2xl py-3.5 active:scale-95 transition-transform">
          <span className="text-xl">📞</span>
          <span className="text-xs">Call</span>
        </button>
        <button className="flex-1 flex flex-col items-center gap-1 bg-teal-light text-teal font-bold rounded-2xl py-3.5 active:scale-95 transition-transform">
          <span className="text-xl">🗺️</span>
          <span className="text-xs">Directions</span>
        </button>
        <button className="flex-1 flex flex-col items-center gap-1 bg-bg text-muted font-bold rounded-2xl py-3.5 active:scale-95 transition-transform">
          <span className="text-xl">📅</span>
          <span className="text-xs">History</span>
        </button>
      </div>

      {/* Stale warning */}
      {member.isStale && (
        <div className="mx-5 mb-5 bg-warning-light rounded-2xl p-3 flex items-center gap-2">
          <span className="text-warning text-xl">⚠️</span>
          <div>
            <div className="text-warning font-bold text-sm">Location may be outdated</div>
            <div className="text-warning/80 text-xs font-medium">Emma's phone may be offline or location access was paused.</div>
          </div>
        </div>
      )}
    </div>
  );
}
