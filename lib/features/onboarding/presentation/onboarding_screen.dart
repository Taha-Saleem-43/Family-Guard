import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_providers.dart';
import 'permission_gate_screen.dart';

enum OnboardingStep { splash, carousel, auth, role, createCircle, childConsent, permissions }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _currentStep = OnboardingStep.splash;
  int _carouselIndex = 0;
  bool _isSignUp = true;
  bool _isLoading = false;
  String? _errorMessage;
  // Carries the user's role to PermissionGateScreen after circle setup.
  UserRole? _pendingRole;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _circleNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _circleNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.my_location_rounded,
      'title': "See your family's location",
      'body': 'Know where everyone is, updated in real time — even when the app is closed.',
      'gradient': [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
    },
    {
      'icon': Icons.notifications_active_rounded,
      'title': 'Get alerts when they arrive',
      'body': 'Set up Places like Home and School and get notified the moment someone arrives or leaves.',
      'gradient': [const Color(0xFF0D9488), const Color(0xFF0F766E)],
    },
    {
      'icon': Icons.sos_rounded,
      'title': 'SOS for emergencies',
      'body': 'One tap sends an emergency alert with a live location to every family member instantly.',
      'gradient': [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
    },
  ];

  Future<void> _handleAuthSubmit() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      if (_isSignUp) {
        await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _nameController.text.trim(),
        );
        // After sign-up, user picks role (create or join circle)
        setState(() => _currentStep = OnboardingStep.role);
      } else {
        final account = await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Signed-in user — check if they already have a circle
        if (account.circleId != null && account.circleId!.isNotEmpty) {
          // Already in a circle — go straight to main app
          ref.read(appStateProvider.notifier).completeOnboarding(
            account.role == UserRole.parent ? UserRole.parent : UserRole.child,
          );
        } else {
          // Signed in but no circle yet — let them create or join
          setState(() => _currentStep = OnboardingStep.role);
        }
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCreateCircle() async {
    final circleName = _circleNameController.text.trim();
    if (circleName.isEmpty) {
      setState(() => _errorMessage = 'Please enter a name for your circle');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      final circle = await authService.createCircle(circleName: circleName);
      // Store circle name so completeOnboarding can use it after permissions.
      ref.read(appStateProvider.notifier).setCircleName(circle.name);
      setState(() {
        _pendingRole = UserRole.parent;
        _currentStep = OnboardingStep.permissions;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinCircle() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid invite code');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      final account = await authService.joinCircleByCode(inviteCode: code);
      // Role is assigned server-side from the invite code — never user-selected.
      final role = account.role == UserRole.child ? UserRole.child : UserRole.parent;
      setState(() {
        _pendingRole = role;
        // Children already saw the consent screen; both roles go to permissions.
        _currentStep = OnboardingStep.permissions;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStepContent(),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case OnboardingStep.splash:
        return _buildSplash();
      case OnboardingStep.carousel:
        return _buildCarousel();
      case OnboardingStep.auth:
        return _buildAuth();
      case OnboardingStep.role:
        return _buildRoleSelection();
      case OnboardingStep.createCircle:
        return _buildCreateCircle();
      case OnboardingStep.childConsent:
        return _buildChildConsent();
      case OnboardingStep.permissions:
        // Role is carried through state; the gate screen calls completeOnboarding.
        return PermissionGateScreen(role: _pendingRole ?? UserRole.parent);
    }
  }

  // 1. Splash Screen
  Widget _buildSplash() {
    return Container(
      key: const ValueKey('splash'),
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, size: 72, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'FamilyGuard',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stay connected. Stay safe.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
              onPressed: () => setState(() => _currentStep = OnboardingStep.carousel),
              child: const Text(
                'Get started',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSignUp = false;
                    _currentStep = OnboardingStep.auth;
                  });
                },
                child: const Text(
                  'Sign in',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // 2. Carousel Screen
  Widget _buildCarousel() {
    final slide = _slides[_carouselIndex];
    final gradientColors = slide['gradient'] as List<Color>;

    return Container(
      key: ValueKey('carousel_$_carouselIndex'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        children: [
          const Spacer(),
          Icon(slide['icon'] as IconData, size: 84, color: Colors.white),
          const SizedBox(height: 32),
          Text(
            slide['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide['body'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const Spacer(),
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _carouselIndex ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _carouselIndex ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              if (_carouselIndex > 0) ...[
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => setState(() => _carouselIndex--),
                    child: const Text('Back', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_carouselIndex < _slides.length - 1) {
                      setState(() => _carouselIndex++);
                    } else {
                      setState(() => _currentStep = OnboardingStep.auth);
                    }
                  },
                  child: Text(
                    _carouselIndex < _slides.length - 1 ? 'Next' : 'Continue',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Auth Screen (Sign Up / Sign In)
  Widget _buildAuth() {
    return Container(
      key: const ValueKey('auth'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentStep = OnboardingStep.carousel),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            _isSignUp ? 'Create account' : 'Welcome back',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _isSignUp ? 'Join FamilyGuard in seconds.' : 'Sign in to your family Circle.',
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.sosRedLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.sosRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.sosRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.sosRed, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_isSignUp) ...[
                    _buildTextField(label: 'Your name', controller: _nameController, hint: 'Alex Johnson'),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField(label: 'Email address', controller: _emailController, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildTextField(label: 'Password', controller: _passwordController, hint: '••••••••', obscureText: true),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuthSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              _isSignUp ? 'Create account' : 'Sign in',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp ? 'Sign in' : 'Sign up',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Role Choice Screen
  Widget _buildRoleSelection() {
    return Container(
      key: const ValueKey('role'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentStep = OnboardingStep.auth),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            'How are you joining?',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'This sets your role in the family Circle. You can always invite others later.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _buildRoleCard(
            icon: Icons.family_restroom_rounded,
            iconColor: AppColors.primary,
            title: "I'm a parent / guardian",
            description: "Create a new family Circle and invite your children. You'll see everyone's location.",
            onTap: () {
              setState(() {
                _currentStep = OnboardingStep.createCircle;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildRoleCard(
            icon: Icons.child_care_rounded,
            iconColor: AppColors.teal,
            title: "I'm joining a Circle",
            description: "Enter an invite code from a parent. You'll see your own location and get place alerts.",
            onTap: () {
              setState(() {
                _currentStep = OnboardingStep.childConsent;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Create Circle Screen (Parent)
  Widget _buildCreateCircle() {
    return Container(
      key: const ValueKey('createCircle'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentStep = OnboardingStep.role),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            'Name your Circle',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your family name — everyone you invite will join this Circle.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),
          _buildTextField(label: 'Circle name', controller: _circleNameController, hint: 'The Johnson Family'),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleCreateCircle,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Create Circle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Child Consent Screen (Child)
  Widget _buildChildConsent() {
    return Container(
      key: const ValueKey('childConsent'),
      color: AppColors.bg,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentStep = OnboardingStep.role),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Before you join',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            "Here's exactly what happens when you join a Circle as a child member.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildConsentRow(Icons.location_on_rounded, 'Location always shared', 'Your parent will see your location continuously, including when the app is in the background or screen is off.'),
                          const Divider(height: 24),
                          _buildConsentRow(Icons.notifications_active_rounded, 'Persistent notification', "You'll always see a notification in your status bar while location sharing is active."),
                          const Divider(height: 24),
                          _buildConsentRow(Icons.history_rounded, 'History is recorded', 'Your location history is stored so your parent can review past activity.'),
                          const Divider(height: 24),
                          _buildConsentRow(Icons.sos_rounded, 'You are in control of SOS', 'The SOS button is always available to you — one tap alerts every member instantly.'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💬 Enter your invite code to join',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _inviteCodeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleJoinCircle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text(
                              'I understand — Join Circle',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentRow(IconData icon, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
