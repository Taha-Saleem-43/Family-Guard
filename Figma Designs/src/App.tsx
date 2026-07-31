import { useState } from 'react';
import type { Role, Tab } from './types';
import Onboarding from './components/Onboarding';
import MapScreen from './components/MapScreen';
import HistoryScreen from './components/HistoryScreen';
import PlacesScreen from './components/PlacesScreen';
import AlertsScreen from './components/AlertsScreen';
import SettingsScreen from './components/SettingsScreen';
import BottomNav from './components/BottomNav';

type AppState = 'onboarding' | 'main';

export default function App() {
  const [appState, setAppState] = useState<AppState>('onboarding');
  const [role, setRole] = useState<Role>('parent');
  const [activeTab, setActiveTab] = useState<Tab>('map');

  function handleOnboardingComplete(r: Role) {
    setRole(r);
    setActiveTab('map');
    setAppState('main');
  }

  return (
    /* Outer shell: centers the 390px mobile frame on desktop */
    <div
      style={{
        width: '100%',
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: '#0F172A',
      }}
    >
      {/* Mobile device frame */}
      <div
        style={{
          width: 390,
          height: 844,
          position: 'relative',
          overflow: 'hidden',
          borderRadius: 44,
          boxShadow: '0 0 0 10px #1E293B, 0 30px 80px rgba(0,0,0,0.6)',
          display: 'flex',
          flexDirection: 'column',
          background: '#EFF6FF',
        }}
      >
        {/* Status bar */}
        <div
          style={{
            height: 44,
            flexShrink: 0,
            background: appState === 'onboarding' ? 'transparent' : 'transparent',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 24px',
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            zIndex: 100,
            pointerEvents: 'none',
          }}
        >
          <span style={{ fontSize: 13, fontWeight: 700, color: activeTab === 'map' ? '#1E293B' : '#1E293B' }}>9:41</span>
          <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
            <span style={{ fontSize: 12 }}>●●●●</span>
            <span style={{ fontSize: 12 }}>WiFi</span>
            <span style={{ fontSize: 12 }}>🔋</span>
          </div>
        </div>

        {/* Screen content */}
        {appState === 'onboarding' ? (
          <div style={{ flex: 1, overflow: 'hidden' }}>
            <Onboarding onComplete={handleOnboardingComplete} />
          </div>
        ) : (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', paddingTop: 0 }}>
            <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>
              {activeTab === 'map' && <MapScreen role={role} />}
              {activeTab === 'history' && <HistoryScreen />}
              {activeTab === 'places' && <PlacesScreen />}
              {activeTab === 'alerts' && <AlertsScreen />}
              {activeTab === 'settings' && (
                <SettingsScreen
                  role={role}
                  onRoleChange={r => { setRole(r); setActiveTab('map'); }}
                />
              )}
            </div>
            <BottomNav active={activeTab} onChange={setActiveTab} />
          </div>
        )}

        {/* Home indicator bar */}
        {appState === 'main' && (
          <div
            style={{
              height: 20,
              flexShrink: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              background: '#fff',
            }}
          >
            <div style={{ width: 120, height: 4, background: '#CBD5E1', borderRadius: 2 }} />
          </div>
        )}
      </div>
    </div>
  );
}
