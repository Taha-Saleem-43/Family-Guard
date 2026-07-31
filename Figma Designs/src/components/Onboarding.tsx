import { useState } from 'react';
import type { Role } from '../types';

interface Props {
  onComplete: (role: Role) => void;
}

const SLIDES = [
  {
    emoji: '📍',
    title: "See your family's location",
    body: 'Know where everyone is, updated in real time — even when the app is closed.',
    bg: 'from-blue-500 to-blue-600',
  },
  {
    emoji: '🔔',
    title: 'Get alerts when they arrive',
    body: 'Set up Places like Home and School and get notified the moment someone arrives or leaves.',
    bg: 'from-teal-500 to-teal-600',
  },
  {
    emoji: '🆘',
    title: 'SOS for emergencies',
    body: 'One tap sends an emergency alert with a live location to every family member instantly.',
    bg: 'from-violet-500 to-violet-600',
  },
];

type Screen = 'splash' | 'carousel' | 'auth' | 'role' | 'circle' | 'consent';

export default function Onboarding({ onComplete }: Props) {
  const [screen, setScreen] = useState<Screen>('splash');
  const [slide, setSlide] = useState(0);
  const [authMode, setAuthMode] = useState<'signin' | 'signup'>('signup');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [selectedRole, setSelectedRole] = useState<Role | null>(null);

  if (screen === 'splash') {
    return (
      <div className="flex flex-col items-center justify-center h-full bg-blue-500 text-white animate-fade-in">
        <div className="text-7xl mb-6">🗺️</div>
        <h1 className="text-4xl font-black tracking-tight mb-2">FamilyLink</h1>
        <p className="text-blue-100 text-lg font-medium">Stay connected. Stay safe.</p>
        <button
          onClick={() => setScreen('carousel')}
          className="mt-16 bg-white text-blue-600 font-bold text-lg px-10 py-4 rounded-full shadow-lg active:scale-95 transition-transform"
        >
          Get started
        </button>
        <p className="mt-6 text-blue-200 text-sm">
          Already have an account?{' '}
          <button onClick={() => { setAuthMode('signin'); setScreen('auth'); }} className="underline text-white font-semibold">
            Sign in
          </button>
        </p>
      </div>
    );
  }

  if (screen === 'carousel') {
    const s = SLIDES[slide];
    return (
      <div className={`flex flex-col h-full bg-gradient-to-br ${s.bg} text-white animate-fade-in`}>
        <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
          <div className="text-8xl mb-8">{s.emoji}</div>
          <h2 className="text-3xl font-black mb-4 leading-tight">{s.title}</h2>
          <p className="text-white/80 text-lg font-medium leading-relaxed">{s.body}</p>
        </div>
        {/* Dots */}
        <div className="flex justify-center gap-2 mb-8">
          {SLIDES.map((_, i) => (
            <div key={i} className={`h-2 rounded-full transition-all duration-300 ${i === slide ? 'w-8 bg-white' : 'w-2 bg-white/40'}`} />
          ))}
        </div>
        <div className="px-6 pb-10 flex gap-3">
          {slide > 0 && (
            <button
              onClick={() => setSlide(slide - 1)}
              className="flex-1 bg-white/20 text-white font-bold text-lg py-4 rounded-2xl active:scale-95 transition-transform"
            >
              Back
            </button>
          )}
          <button
            onClick={() => slide < SLIDES.length - 1 ? setSlide(slide + 1) : setScreen('auth')}
            className="flex-1 bg-white text-blue-600 font-bold text-lg py-4 rounded-2xl shadow-lg active:scale-95 transition-transform"
          >
            {slide < SLIDES.length - 1 ? 'Next' : 'Continue'}
          </button>
        </div>
      </div>
    );
  }

  if (screen === 'auth') {
    return (
      <div className="flex flex-col h-full bg-bg animate-fade-in">
        <div className="px-6 pt-14 pb-6">
          <button onClick={() => setScreen('carousel')} className="text-muted mb-8 flex items-center gap-1 text-sm font-semibold">
            ← Back
          </button>
          <h2 className="text-3xl font-black text-text mb-1">
            {authMode === 'signup' ? 'Create account' : 'Welcome back'}
          </h2>
          <p className="text-muted font-medium">
            {authMode === 'signup' ? 'Join FamilyLink in seconds.' : 'Sign in to your family Circle.'}
          </p>
        </div>
        <div className="flex-1 px-6 space-y-4">
          {authMode === 'signup' && (
            <div>
              <label className="text-sm font-bold text-text-muted block mb-1.5">Your name</label>
              <input
                value={name}
                onChange={e => setName(e.target.value)}
                placeholder="Alex Johnson"
                className="w-full bg-white border-2 border-border rounded-2xl px-4 py-3.5 text-text font-semibold placeholder:text-border focus:outline-none focus:border-primary transition-colors"
              />
            </div>
          )}
          <div>
            <label className="text-sm font-bold text-muted block mb-1.5">Email address</label>
            <input
              type="email"
              value={email}
              onChange={e => setEmail(e.target.value)}
              placeholder="you@example.com"
              className="w-full bg-white border-2 border-border rounded-2xl px-4 py-3.5 text-text font-semibold placeholder:text-border focus:outline-none focus:border-primary transition-colors"
            />
          </div>
          <div>
            <label className="text-sm font-bold text-muted block mb-1.5">Password</label>
            <input
              type="password"
              value={password}
              onChange={e => setPassword(e.target.value)}
              placeholder="••••••••"
              className="w-full bg-white border-2 border-border rounded-2xl px-4 py-3.5 text-text font-semibold placeholder:text-border focus:outline-none focus:border-primary transition-colors"
            />
          </div>
          <button
            onClick={() => setScreen('role')}
            className="w-full bg-primary text-white font-bold text-lg py-4 rounded-2xl shadow-lg shadow-blue-200 active:scale-95 transition-transform mt-2"
          >
            {authMode === 'signup' ? 'Create account' : 'Sign in'}
          </button>
          <p className="text-center text-muted text-sm font-medium pt-2">
            {authMode === 'signup' ? 'Already have an account?' : "Don't have an account?"}{' '}
            <button
              onClick={() => setAuthMode(authMode === 'signup' ? 'signin' : 'signup')}
              className="text-primary font-bold"
            >
              {authMode === 'signup' ? 'Sign in' : 'Sign up'}
            </button>
          </p>
        </div>
      </div>
    );
  }

  if (screen === 'role') {
    return (
      <div className="flex flex-col h-full bg-bg animate-fade-in">
        <div className="px-6 pt-14 pb-6">
          <h2 className="text-3xl font-black text-text mb-2">How are you joining?</h2>
          <p className="text-muted font-medium">This sets your role in the family Circle. You can always invite others later.</p>
        </div>
        <div className="flex-1 px-6 space-y-4">
          <button
            onClick={() => { setSelectedRole('parent'); setScreen('circle'); }}
            className="w-full bg-white border-2 border-border rounded-2xl p-5 text-left active:scale-98 transition-all hover:border-primary group"
          >
            <div className="text-3xl mb-3">👨‍👩‍👧‍👦</div>
            <div className="font-black text-text text-lg mb-1">I'm a parent / guardian</div>
            <div className="text-muted text-sm font-medium">Create a new family Circle and invite your children. You'll see everyone's location.</div>
          </button>
          <button
            onClick={() => { setSelectedRole('child'); setScreen('consent'); }}
            className="w-full bg-white border-2 border-border rounded-2xl p-5 text-left active:scale-98 transition-all hover:border-teal"
          >
            <div className="text-3xl mb-3">🧒</div>
            <div className="font-black text-text text-lg mb-1">I'm joining a Circle</div>
            <div className="text-muted text-sm font-medium">Enter an invite code from a parent. You'll see your own location and get place alerts.</div>
          </button>
        </div>
      </div>
    );
  }

  if (screen === 'circle') {
    return (
      <div className="flex flex-col h-full bg-bg animate-fade-in">
        <div className="px-6 pt-14 pb-6">
          <button onClick={() => setScreen('role')} className="text-muted mb-8 text-sm font-semibold">← Back</button>
          <h2 className="text-3xl font-black text-text mb-2">Name your Circle</h2>
          <p className="text-muted font-medium">Your family name — everyone you invite will join this Circle.</p>
        </div>
        <div className="flex-1 px-6">
          <label className="text-sm font-bold text-muted block mb-1.5">Circle name</label>
          <input
            defaultValue="The Johnson Family"
            className="w-full bg-white border-2 border-border rounded-2xl px-4 py-3.5 text-text font-semibold focus:outline-none focus:border-primary transition-colors mb-6"
          />
          <button
            onClick={() => onComplete('parent')}
            className="w-full bg-primary text-white font-bold text-lg py-4 rounded-2xl shadow-lg shadow-blue-200 active:scale-95 transition-transform"
          >
            Create Circle
          </button>
        </div>
      </div>
    );
  }

  if (screen === 'consent') {
    return (
      <div className="flex flex-col h-full bg-bg animate-fade-in">
        <div className="px-6 pt-14 pb-4">
          <button onClick={() => setScreen('role')} className="text-muted mb-6 text-sm font-semibold">← Back</button>
          <h2 className="text-2xl font-black text-text mb-2">Before you join</h2>
          <p className="text-muted font-medium text-sm">Here's exactly what happens when you join a Circle as a child member.</p>
        </div>
        <div className="flex-1 px-6 overflow-y-auto">
          <div className="bg-white rounded-2xl p-5 space-y-4 border-2 border-border mb-6">
            {[
              { icon: '📍', title: 'Location always shared', body: 'Your parent will see your location continuously, including when the app is in the background or the screen is off.' },
              { icon: '🔔', title: 'Persistent notification', body: "You'll always see a notification in your status bar while location sharing is active, so you know when it's running." },
              { icon: '📖', title: 'History is recorded', body: 'Your location history is stored and your parent can review where you\'ve been over the past 30 days.' },
              { icon: '🔒', title: 'You\'re in control of SOS', body: 'The SOS button is always available to you — one tap alerts every Circle member with your live location.' },
            ].map(item => (
              <div key={item.icon} className="flex gap-3">
                <span className="text-xl flex-shrink-0 mt-0.5">{item.icon}</span>
                <div>
                  <div className="font-bold text-text text-sm">{item.title}</div>
                  <div className="text-muted text-sm font-medium mt-0.5">{item.body}</div>
                </div>
              </div>
            ))}
          </div>
          <div className="bg-primary-light rounded-2xl p-4 mb-6">
            <div className="text-primary font-bold text-sm">💬 Enter your invite code to join</div>
            <input
              defaultValue="FAMILY-7K4X"
              className="w-full bg-white border-2 border-primary-light rounded-xl px-3 py-3 text-text font-bold font-mono text-center mt-3 focus:outline-none focus:border-primary transition-colors tracking-widest"
            />
          </div>
          <button
            onClick={() => onComplete('child')}
            className="w-full bg-teal text-white font-bold text-lg py-4 rounded-2xl shadow-lg shadow-teal-200 active:scale-95 transition-transform mb-8"
          >
            I understand — Join Circle
          </button>
        </div>
      </div>
    );
  }

  return null;
}
