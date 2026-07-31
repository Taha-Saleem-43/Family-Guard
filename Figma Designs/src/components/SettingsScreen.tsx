import type { Role } from '../types';

interface Props {
  role: Role;
  onRoleChange: (r: Role) => void;
}

function PermissionRow({ icon, label, status, ok }: { icon: string; label: string; status: string; ok: boolean }) {
  return (
    <div className="flex items-center gap-3 py-3 border-b border-border last:border-0">
      <span className="text-xl w-8 text-center">{icon}</span>
      <div className="flex-1">
        <div className="font-bold text-text text-sm">{label}</div>
        <div className="text-xs font-medium mt-0.5" style={{ color: ok ? '#16A34A' : '#D97706' }}>{status}</div>
      </div>
      <span className="text-lg">{ok ? '✅' : '⚠️'}</span>
    </div>
  );
}

function SectionHeader({ title }: { title: string }) {
  return <div className="text-xs font-black text-muted uppercase tracking-wider mt-6 mb-2 px-1">{title}</div>;
}

function SettingRow({ icon, label, value, action }: { icon: string; label: string; value?: string; action?: string }) {
  return (
    <button className="w-full flex items-center gap-3 px-4 py-3.5 bg-white rounded-xl active:bg-bg transition-colors">
      <span className="text-xl w-8 text-center">{icon}</span>
      <div className="flex-1 text-left">
        <div className="font-bold text-text text-sm">{label}</div>
        {value && <div className="text-muted text-xs font-medium">{value}</div>}
      </div>
      {action ? (
        <span className="text-primary font-bold text-sm">{action}</span>
      ) : (
        <span className="text-border text-xl">›</span>
      )}
    </button>
  );
}

export default function SettingsScreen({ role, onRoleChange }: Props) {
  return (
    <div className="flex flex-col h-full bg-bg overflow-y-auto">
      <div className="px-5 pt-12 pb-4">
        <h1 className="text-2xl font-black text-text mb-1">Settings</h1>
        <p className="text-muted text-sm font-medium">The Johnson Family Circle</p>
      </div>

      <div className="px-5 pb-8">
        {/* Profile card */}
        <div className="bg-white rounded-2xl p-4 flex items-center gap-4 shadow-sm mb-2">
          <div
            className="w-14 h-14 rounded-full flex items-center justify-center text-white font-black text-xl"
            style={{ background: role === 'parent' ? '#7C3AED' : '#2563EB' }}
          >
            {role === 'parent' ? 'AJ' : 'EM'}
          </div>
          <div>
            <div className="font-black text-text">{role === 'parent' ? 'Alex Johnson' : 'Emma Johnson'}</div>
            <div className="text-muted text-sm font-medium">{role === 'parent' ? 'Parent · Circle owner' : 'Child member'}</div>
          </div>
        </div>

        {/* Demo role switcher */}
        <div className="bg-warning-light border border-warning/20 rounded-2xl p-3 mb-2 flex items-center gap-2">
          <span className="text-lg">🧪</span>
          <div className="flex-1">
            <div className="text-warning font-bold text-xs">Demo mode — switch role</div>
          </div>
          <button
            onClick={() => onRoleChange(role === 'parent' ? 'child' : 'parent')}
            className="bg-warning text-white font-bold text-xs px-3 py-1.5 rounded-full active:scale-95 transition-transform"
          >
            Switch to {role === 'parent' ? 'Child' : 'Parent'}
          </button>
        </div>

        {/* Permission status */}
        <SectionHeader title="Permission Status" />
        <div className="bg-white rounded-2xl px-4 shadow-sm">
          <PermissionRow icon="📍" label="Location" status="Always allowed" ok={true} />
          <PermissionRow icon="🔋" label="Battery optimization" status="Unrestricted" ok={true} />
          <PermissionRow icon="🔔" label="Notifications" status="Enabled" ok={true} />
          <PermissionRow icon="🔄" label="Background app refresh" status="Enabled" ok={true} />
        </div>

        {/* Circle members (parent view) */}
        {role === 'parent' && (
          <>
            <SectionHeader title="Circle Members" />
            <div className="bg-white rounded-2xl shadow-sm overflow-hidden">
              {[
                { name: 'Alex Johnson', role: 'Parent (You)', color: '#7C3AED', initials: 'AJ' },
                { name: 'Emma Johnson', role: 'Child', color: '#2563EB', initials: 'EM' },
                { name: 'Jake Johnson', role: 'Child', color: '#D97706', initials: 'JK' },
              ].map((m, i) => (
                <div key={m.name} className={`flex items-center gap-3 px-4 py-3.5 ${i > 0 ? 'border-t border-border' : ''}`}>
                  <div className="w-9 h-9 rounded-full flex items-center justify-center text-white font-black text-sm" style={{ background: m.color }}>
                    {m.initials}
                  </div>
                  <div className="flex-1">
                    <div className="font-bold text-text text-sm">{m.name}</div>
                    <div className="text-muted text-xs font-medium">{m.role}</div>
                  </div>
                  {m.name !== 'Alex Johnson' && (
                    <button className="text-danger text-xs font-bold px-2 py-1 rounded-lg bg-danger-light active:scale-95 transition-transform">Remove</button>
                  )}
                </div>
              ))}
            </div>
          </>
        )}

        {/* Settings sections */}
        <SectionHeader title="Notifications" />
        <div className="bg-white rounded-2xl shadow-sm space-y-px">
          <SettingRow icon="🔔" label="Place alerts" value="On for all members" />
          <SettingRow icon="🆘" label="SOS alerts" value="Enabled · High priority" />
          <SettingRow icon="🔋" label="Low battery alerts" value="Below 20%" />
        </div>

        <SectionHeader title="Privacy & Data" />
        <div className="bg-white rounded-2xl shadow-sm space-y-px">
          <SettingRow icon="📂" label="Location history" value="Saved for 30 days" />
          <SettingRow icon="🗑️" label="Delete my data" />
          <SettingRow icon="📄" label="Privacy policy" />
        </div>

        <SectionHeader title="Account" />
        <div className="bg-white rounded-2xl shadow-sm space-y-px">
          <SettingRow icon="✉️" label="Email" value={role === 'parent' ? 'alex@example.com' : 'emma@example.com'} />
          <SettingRow icon="🔑" label="Change password" />
          <SettingRow icon="🚪" label="Sign out" action="Sign out" />
        </div>

        <div className="mt-6 text-center text-muted text-xs font-medium">
          FamilyLink v1.0.0 · Made with ❤️ for family safety
        </div>
      </div>
    </div>
  );
}
