import { useState } from 'react';
import type { Role, Member, SOSState } from '../types';
import { MEMBERS, PLACES } from '../data';
import MapBackground from './MapBackground';
import MapPin from './MapPin';
import PlaceMarker from './PlaceMarker';
import MemberDetailSheet from './MemberDetailSheet';
import SOSOverlay from './SOSOverlay';

interface Props {
  role: Role;
}

export default function MapScreen({ role }: Props) {
  const [selectedMember, setSelectedMember] = useState<Member | null>(null);
  const [sosState, setSosState] = useState<SOSState>('none');
  const [sheetExpanded, setSheetExpanded] = useState(false);

  const self = MEMBERS.find(m => m.role === role && m.id === (role === 'parent' ? 'parent' : 'emma'))!;
  const visibleMembers = role === 'parent' ? MEMBERS : [self];
  const children = MEMBERS.filter(m => m.role === 'child');

  function handleSOSPress() {
    setSosState('countdown');
  }

  return (
    <div className="relative flex flex-col h-full overflow-hidden">
      {/* Full-screen map */}
      <div className="absolute inset-0">
        <MapBackground />

        {/* Place markers */}
        {PLACES.map(p => <PlaceMarker key={p.id} place={p} />)}

        {/* Member pins */}
        {visibleMembers.map(m => (
          <MapPin
            key={m.id}
            member={m}
            isSelected={selectedMember?.id === m.id}
            showSelf={m.id === self.id}
            onClick={() => setSelectedMember(m.id === selectedMember?.id ? null : m)}
          />
        ))}
      </div>

      {/* Top bar */}
      <div className="relative z-10 flex items-center justify-between px-4 pt-12 pb-3 pointer-events-none">
        <div className="bg-white/90 backdrop-blur rounded-2xl px-4 py-2.5 shadow-sm pointer-events-auto">
          <div className="font-black text-text text-sm">🏠 The Johnson Family</div>
          <div className="text-muted text-xs font-semibold">{role === 'parent' ? '3 members' : 'Shared with Alex'}</div>
        </div>
        {role === 'child' && (
          <div className="bg-primary/10 backdrop-blur border border-primary/20 rounded-full px-3 py-1.5 flex items-center gap-1.5 pointer-events-auto">
            <span className="w-2 h-2 rounded-full bg-primary animate-pulse" />
            <span className="text-primary text-xs font-bold">Sharing location</span>
            <button className="text-primary text-xs ml-0.5">ℹ</button>
          </div>
        )}
      </div>

      {/* Error banner example (offline warning) — hidden by default */}

      {/* Bottom section */}
      <div className="absolute bottom-0 left-0 right-0 z-10">
        {/* SOS button */}
        {sosState === 'none' && (
          <button
            onClick={handleSOSPress}
            className="absolute right-4 sos-beat"
            style={{ bottom: sheetExpanded ? 320 : (role === 'parent' ? 220 : 90) }}
          >
            <div className="w-14 h-14 rounded-full bg-danger shadow-lg shadow-red-300 flex items-center justify-center border-3 border-white">
              <span className="text-white font-black text-xs leading-none text-center">
                S<br/>O<br/>S
              </span>
            </div>
          </button>
        )}

        {role === 'parent' && !selectedMember ? (
          /* Parent: compact member list */
          <div
            className={`bg-white rounded-t-3xl shadow-2xl transition-all duration-300 ${sheetExpanded ? 'max-h-80' : 'max-h-48'}`}
          >
            <button className="w-full" onClick={() => setSheetExpanded(!sheetExpanded)}>
              <div className="drag-handle mt-3" />
            </button>
            <div className="px-5 pb-3 flex items-center justify-between">
              <span className="font-black text-text text-base">Family</span>
              <span className="text-muted text-xs font-semibold">{children.length} members</span>
            </div>
            <div className="overflow-y-auto" style={{ maxHeight: sheetExpanded ? 220 : 130 }}>
              {children.map(m => (
                <button
                  key={m.id}
                  onClick={() => setSelectedMember(m)}
                  className="w-full flex items-center gap-3 px-5 py-3 border-t border-border active:bg-bg transition-colors"
                >
                  <div
                    className="w-10 h-10 rounded-full flex items-center justify-center text-white font-black text-sm flex-shrink-0"
                    style={{ background: m.pinColor }}
                  >
                    {m.initials}
                  </div>
                  <div className="flex-1 text-left">
                    <div className="font-bold text-text text-sm">{m.name}</div>
                    <div className="text-muted text-xs font-medium truncate">{m.location}</div>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <div className="text-xs text-muted font-semibold">{m.lastSeen}</div>
                    <div className="text-xs font-bold" style={{ color: m.battery < 20 ? '#DC2626' : '#94A3B8' }}>
                      🔋 {m.battery}%
                    </div>
                  </div>
                  <span className="text-border text-lg ml-1">›</span>
                </button>
              ))}
            </div>
          </div>
        ) : role === 'child' ? (
          /* Child: minimal chip */
          <div className="pb-4 px-4">
            <div className="bg-white/90 backdrop-blur rounded-2xl px-4 py-3 flex items-center gap-3 shadow-sm">
              <div className="w-2 h-2 rounded-full bg-success animate-pulse" />
              <div className="flex-1">
                <div className="text-text font-bold text-sm">Location active</div>
                <div className="text-muted text-xs font-medium">Sharing with Alex · Updated now</div>
              </div>
              <span className="text-xs text-muted font-semibold">🔋 {self.battery}%</span>
            </div>
          </div>
        ) : null}
      </div>

      {/* Member detail sheet overlay */}
      {selectedMember && (
        <div className="absolute inset-0 z-20 flex flex-col justify-end" onClick={e => { if (e.target === e.currentTarget) setSelectedMember(null); }}>
          <div className="absolute inset-0 bg-black/20" onClick={() => setSelectedMember(null)} />
          <div className="relative z-10">
            <MemberDetailSheet member={selectedMember} onClose={() => setSelectedMember(null)} />
          </div>
        </div>
      )}

      {/* SOS overlay */}
      {sosState !== 'none' && (
        <SOSOverlay
          state={sosState}
          onStateChange={setSosState}
          sender={self}
        />
      )}
    </div>
  );
}
