import { ALERTS } from '../data';

const TYPE_ICONS: Record<string, string> = { arrive: '🟢', leave: '🟡' };
const TYPE_LABEL: Record<string, string> = { arrive: 'arrived at', leave: 'left' };

function groupByDate(alerts: typeof ALERTS) {
  const groups: Record<string, typeof ALERTS> = {};
  for (const a of alerts) {
    if (!groups[a.date]) groups[a.date] = [];
    groups[a.date].push(a);
  }
  return Object.entries(groups);
}

export default function AlertsScreen() {
  const groups = groupByDate(ALERTS);

  return (
    <div className="flex flex-col h-full bg-bg">
      <div className="px-5 pt-12 pb-4">
        <h1 className="text-2xl font-black text-text mb-1">Activity</h1>
        <p className="text-muted text-sm font-medium">All arrivals and departures across your Circle</p>
      </div>

      <div className="flex-1 overflow-y-auto px-5 pb-6">
        {groups.map(([date, events]) => (
          <div key={date} className="mb-5">
            <div className="text-xs font-black text-muted uppercase tracking-wider mb-3">{date}</div>
            <div className="space-y-2">
              {events.map(e => (
                <div key={e.id} className="bg-white rounded-2xl px-4 py-3.5 flex items-center gap-3 shadow-sm">
                  <div
                    className="w-9 h-9 rounded-full flex items-center justify-center text-white font-black text-sm flex-shrink-0"
                    style={{ background: e.memberColor }}
                  >
                    {e.memberInitials}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="text-text font-bold text-sm">
                      <span>{e.memberName}</span>
                      <span className="text-muted font-medium"> {TYPE_LABEL[e.type]} </span>
                      <span className="font-black">{e.place}</span>
                    </div>
                    <div className="text-muted text-xs font-medium mt-0.5">{e.time}</div>
                  </div>
                  <span className="text-lg flex-shrink-0">{TYPE_ICONS[e.type]}</span>
                </div>
              ))}
            </div>
          </div>
        ))}

        {/* Notification preview card */}
        <div className="mt-2 bg-text rounded-2xl p-4 shadow-lg">
          <div className="text-white/50 text-xs font-bold mb-2 uppercase tracking-wider">Example notification</div>
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary flex items-center justify-center flex-shrink-0">
              <span className="text-white font-black text-sm">EM</span>
            </div>
            <div>
              <div className="text-white font-black text-sm">Emma arrived at School</div>
              <div className="text-white/60 text-xs font-medium mt-0.5">FamilyLink · 8:02 AM</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
