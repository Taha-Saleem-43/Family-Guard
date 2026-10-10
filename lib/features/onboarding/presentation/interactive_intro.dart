import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/presentation/setup_scroll_view.dart';
import '../../../core/theme/app_colors.dart';

/// A local preview: exploring it never starts tracking or sends an alert.
class InteractiveIntro extends StatefulWidget {
  const InteractiveIntro({
    super.key,
    required this.onStart,
    required this.onSignIn,
  });
  final VoidCallback onStart;
  final VoidCallback onSignIn;
  @override
  State<InteractiveIntro> createState() => _InteractiveIntroState();
}

class _InteractiveIntroState extends State<InteractiveIntro> {
  int _selected = 0;
  bool _tried = false;
  static const _titles = [
    'A little closer, wherever you are.',
    'Small updates. More peace of mind.',
    'A helping hand, one tap away.',
  ];
  static const _details = [
    'Explore a sample family map. Location sharing starts only after setup and consent.',
    'Save familiar places and choose arrival or departure notifications.',
    'SOS can notify your circle when you need help. It does not contact emergency services.',
  ];
  static const _actions = [
    'Try the family map',
    'Try an arrival update',
    'Preview an SOS alert',
  ];
  static const _results = [
    'Alex • updated just now • ±8 m',
    'Alex arrived at Home • sample update',
    'SOS preview • your circle would be notified',
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: SetupScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/branding/icon.png',
                      width: 38,
                      height: 38,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'FamilyGuard',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onSignIn,
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'YOUR PEOPLE. YOUR CIRCLE.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _titles[_selected],
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: const IntroFilm(),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    3,
                    (index) => ChoiceChip(
                      label: Text(['Family map', 'Places', 'SOS'][index]),
                      selected: _selected == index,
                      onSelected: (_) => setState(() {
                        _selected = index;
                        _tried = false;
                      }),
                      selectedColor: AppColors.primaryLight,
                      showCheckmark: false,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _details[_selected],
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _tried = !_tried),
                    icon: Icon(
                      [
                        Icons.my_location_rounded,
                        Icons.home_rounded,
                        Icons.notifications_active_outlined,
                      ][_selected],
                    ),
                    label: Text(_actions[_selected]),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _tried
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'DEMO · NO LIVE DATA',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _results[_selected],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Get started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'You choose when to share.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class IntroFilm extends StatefulWidget {
  const IntroFilm({super.key});
  @override
  State<IntroFilm> createState() => _IntroFilmState();
}

class _IntroFilmState extends State<IntroFilm> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _paused = false;
  bool _reduceMotion = false;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      unawaited(_controller?.pause());
    } else if (_controller == null) {
      unawaited(_initialize());
    } else if (_ready && !_paused && _active) {
      unawaited(_controller?.play());
    }
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/family_intro.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setVolume(0);
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
      if (!_reduceMotion && !_paused && _active) await controller.play();
    } catch (_) {
      /* Keep the bundled poster if the platform cannot play video. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller?.pause());
    } else if (_ready && !_paused && !_reduceMotion) {
      unawaited(_controller?.play());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.25,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: Image.asset(
            'assets/branding/intro_poster.png',
            fit: BoxFit.cover,
          ),
        ),
        if (_ready && !_reduceMotion)
          ExcludeSemantics(child: VideoPlayer(_controller!)),
        Positioned(
          left: 14,
          top: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'A glimpse of your circle',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (_ready && !_reduceMotion)
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filledTonal(
              tooltip: _paused ? 'Play introduction' : 'Pause introduction',
              icon: Icon(
                _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
              onPressed: () {
                setState(() => _paused = !_paused);
                unawaited(_paused ? _controller!.pause() : _controller!.play());
              },
            ),
          ),
      ],
    ),
  );
}
