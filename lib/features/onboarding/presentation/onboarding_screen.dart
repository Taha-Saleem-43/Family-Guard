import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_state_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/presentation/setup_scroll_view.dart';
import '../../../core/services/sharing_consent_service.dart';
import '../../auth/domain/circle_model.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/presentation/account_deletion_control.dart';
import 'permission_gate_screen.dart';
import 'interactive_intro.dart';

enum OnboardingStep {
  intro,
  auth,
  role,
  createCircle,
  circleCreated,
  joinCircle,
  childConsent,
  permissions,
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.consentService});
  final SharingConsentService? consentService;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  OnboardingStep _currentStep = OnboardingStep.intro;
  bool _isSignUp = true;
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _errorMessage;
  CircleModel? _createdCircle;
  // Carries the user's role to PermissionGateScreen after circle setup.
  UserRole? _pendingRole;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _circleNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final account = ref.read(appStateProvider);
    if (account.userId.isNotEmpty) {
      _pendingRole = account.role;
      _currentStep = account.circleId.isEmpty
          ? OnboardingStep.role
          : account.role == UserRole.child
          ? OnboardingStep.childConsent
          : OnboardingStep.permissions;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _circleNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSubmit() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    try {
      if (_isSignUp) {
        final displayName = _nameController.text.trim();
        final account = await authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: displayName,
        );
        if (!mounted) return;
        ref
            .read(appStateProvider.notifier)
            .setUserSession(
              userId: account.uid,
              circleId: '',
              userName: displayName,
            );
        // After sign-up, user picks role (create or join circle)
        setState(() => _currentStep = OnboardingStep.role);
      } else {
        final account = await authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        ref
            .read(appStateProvider.notifier)
            .setUserSession(
              userId: account.uid,
              circleId: account.circleId ?? '',
              userName: account.displayName,
              role: account.role,
            );
        // Signed-in user — check if they already have a circle
        if (account.circleId != null && account.circleId!.isNotEmpty) {
          if (account.role == UserRole.child) {
            setState(() {
              _pendingRole = UserRole.child;
              _currentStep = OnboardingStep.childConsent;
            });
          } else {
            ref
                .read(appStateProvider.notifier)
                .completeOnboarding(UserRole.parent);
          }
        } else {
          // Signed in but no circle yet — let them create or join
          setState(() => _currentStep = OnboardingStep.role);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleCreateCircle() async {
    if (_isLoading) return;
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
      final uid = authService.currentUser?.uid;
      if (uid == null) throw Exception('Please sign in.');
      final circle = await authService.createCircle(circleName: circleName);
      if (!mounted) return;
      ref
          .read(appStateProvider.notifier)
          .setUserSession(
            userId: uid,
            circleId: circle.id,
            circleName: circle.name,
            childCode: circle.childInviteCode,
            parentCode: circle.parentInviteCode,
            role: UserRole.parent,
          );
      setState(() {
        _createdCircle = circle;
        _pendingRole = UserRole.parent;
        _currentStep = OnboardingStep.circleCreated;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleJoinCircle() async {
    if (_isLoading) return;
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
      if (!mounted) return;
      // Role is assigned server-side from the invite code — never user-selected.
      final role = account.role == UserRole.child
          ? UserRole.child
          : UserRole.parent;
      ref
          .read(appStateProvider.notifier)
          .setUserSession(
            userId: account.uid,
            circleId: account.circleId ?? '',
            userName: account.displayName,
            role: role,
          );
      setState(() {
        _pendingRole = role;
        _currentStep = role == UserRole.child
            ? OnboardingStep.childConsent
            : OnboardingStep.permissions;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptExistingSharing() async {
    if (_isLoading) return;
    final account = ref.read(appStateProvider);
    setState(() => _isLoading = true);
    try {
      await (widget.consentService ?? SharingConsentService()).accept(
        account.userId,
        account.circleId,
      );
      if (!mounted ||
          ref.read(appStateProvider).userId != account.userId ||
          ref.read(appStateProvider).circleId != account.circleId) {
        return;
      }
      setState(() => _currentStep = OnboardingStep.permissions);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save consent. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:
          ref.watch(appStateProvider).userId.isNotEmpty &&
              [
                OnboardingStep.role,
                OnboardingStep.createCircle,
                OnboardingStep.joinCircle,
              ].contains(_currentStep)
          ? const SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: AccountDeletionControl(),
              ),
            )
          : null,
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
      case OnboardingStep.intro:
        return InteractiveIntro(
          key: const ValueKey('interactive-intro'),
          onStart: () => setState(() {
            _isSignUp = true;
            _currentStep = OnboardingStep.auth;
          }),
          onSignIn: () => setState(() {
            _isSignUp = false;
            _currentStep = OnboardingStep.auth;
          }),
        );
      case OnboardingStep.auth:
        return _buildAuth();
      case OnboardingStep.role:
        return _buildRoleSelection();
      case OnboardingStep.createCircle:
        return _buildCreateCircle();
      case OnboardingStep.circleCreated:
        return _buildCircleCreated();
      case OnboardingStep.joinCircle:
        return _buildJoinCircle();
      case OnboardingStep.childConsent:
        return _buildChildConsent();
      case OnboardingStep.permissions:
        // Role is carried through state; the gate screen calls completeOnboarding.
        return PermissionGateScreen(role: _pendingRole ?? UserRole.parent);
    }
  }

  // 3. Auth Screen (Sign Up / Sign In)
  Widget _buildAuth() {
    return SetupScrollView(
      child: Container(
        key: const ValueKey('auth'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _currentStep = OnboardingStep.intro),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isSignUp ? 'Create account' : 'Welcome back',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? 'Join FamilyGuard in seconds.'
                  : 'Sign in to your family Circle.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sosRedLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sosRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.sosRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.sosRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isSignUp) ...[
                  _buildTextField(
                    label: 'Your name',
                    controller: _nameController,
                    hint: 'Alex Johnson',
                  ),
                  const SizedBox(height: 16),
                ],
                _buildTextField(
                  label: 'Email address',
                  controller: _emailController,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Password',
                  controller: _passwordController,
                  hint: '••••••••',
                  obscureText: true,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuthSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isSignUp ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'Already have an account? '
                          : "Don't have an account? ",
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _passwordVisible = false;
                              _errorMessage = null;
                            }),
                      child: Text(
                        _isSignUp ? 'Sign in' : 'Sign up',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. Role Choice Screen
  Widget _buildRoleSelection() {
    return SetupScrollView(
      child: Container(
        key: const ValueKey('role'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _currentStep = OnboardingStep.auth),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'How are you joining?',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This sets your role in the family Circle. You can always invite others later.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            _buildRoleCard(
              icon: Icons.family_restroom_rounded,
              iconColor: AppColors.primary,
              title: "Create a new Circle",
              description:
                  "Create a new family Circle as a parent/creator and generate invite codes for your family.",
              onTap: () {
                setState(() {
                  _currentStep = OnboardingStep.createCircle;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              icon: Icons.vpn_key_rounded,
              iconColor: AppColors.teal,
              title: "Join an existing Circle",
              description:
                  "Enter the complete invite code shared by a parent in your family.",
              onTap: () {
                setState(() {
                  _errorMessage = null;
                  _currentStep = OnboardingStep.joinCircle;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // 5c. Join Circle Screen (Enter Invite Code)
  Widget _buildJoinCircle() {
    return SetupScrollView(
      child: Container(
        key: const ValueKey('joinCircle'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _currentStep = OnboardingStep.role),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter Invite Code',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the invite code provided by your family member.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sosRedLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.sosRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.sosRed,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.sosRed,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Family Invite Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. FAMILY-7K4X or PARENT-39M1',
                          hintStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: AppColors.bg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Supports both FAMILY (Child) and PARENT (Co-Parent) codes.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleJoinCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Join Circle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
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
    return SetupScrollView(
      child: Container(
        key: const ValueKey('createCircle'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _currentStep = OnboardingStep.role),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Name your Circle',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your family name — everyone you invite will join this Circle.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                _buildTextField(
                  label: 'Circle name',
                  controller: _circleNameController,
                  hint: 'The Johnson Family',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleCreateCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Create Circle',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 5b. Circle Created Screen (Displays generated 6-character Invite Codes)
  Widget _buildCircleCreated() {
    final childCode = _createdCircle?.childInviteCode ?? 'FAMILY-XXXX';
    final parentCode = _createdCircle?.parentInviteCode ?? 'PARENT-XXXX';

    return SetupScrollView(
      child: Container(
        key: const ValueKey('circleCreated'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.tealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Circle Created! 🎉',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Share this invite code with your family members so they can join your Circle.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                // Child Invite Code Card
                Card(
                  color: AppColors.primaryLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.child_care_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Child Member Invite Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                childCode,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: childCode),
                                  );
                                  ScaffoldMessenger.of(
                                    context,
                                  ).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Child invite code ($childCode) copied to clipboard!',
                                      ),
                                      backgroundColor: AppColors.primary,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Parent Invite Code Card
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.supervisor_account_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Co-Parent Invite Code (Full Admin)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              parentCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: parentCode),
                                );
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Co-Parent invite code ($parentCode) copied to clipboard!',
                                    ),
                                    backgroundColor: AppColors.primary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text(
                                'Copy',
                                style: TextStyle(fontWeight: FontWeight.w700),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _currentStep = OnboardingStep.permissions);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Permissions',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // 6. Child Consent Screen (Child)
  Widget _buildChildConsent() {
    final hasCircle = ref
        .watch(appStateProvider.select((state) => state.circleId))
        .isNotEmpty;
    return SetupScrollView(
      child: Container(
        key: const ValueKey('childConsent'),
        color: AppColors.bg,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              onPressed: () =>
                  setState(() => _currentStep = OnboardingStep.role),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasCircle ? 'Before sharing your location' : 'Before you join',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasCircle
                  ? 'Review what location sharing allows in your current circle.'
                  : "Here's what happens when you join a Circle as a child member.",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildConsentRow(
                          Icons.location_on_rounded,
                          'Location sharing',
                          'With your permission, parents in your circle receive your recent location, including in the background when Android allows it.',
                        ),
                        const Divider(height: 24),
                        _buildConsentRow(
                          Icons.notifications_active_rounded,
                          'Tracking notice',
                          'Android shows a tracking notice while sharing is active. Its placement depends on your notification settings.',
                        ),
                        const Divider(height: 24),
                        _buildConsentRow(
                          Icons.history_rounded,
                          'History is recorded',
                          'Recent location history is stored for your circle’s parents to review. It is scheduled for deletion after 30 days.',
                        ),
                        const Divider(height: 24),
                        _buildConsentRow(
                          Icons.sos_rounded,
                          'You are in control of SOS',
                          'Use SOS to ask your circle for help. Sending requires a connection, and alerts may be delayed.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (!hasCircle)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '💬 Enter your invite code to join',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _inviteCodeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
                    onPressed: _isLoading
                        ? null
                        : hasCircle
                        ? _acceptExistingSharing
                        : _handleJoinCircle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            hasCircle
                                ? 'I understand — Continue'
                                : 'I understand — Join Circle',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText && !_passwordVisible,
          enabled: !_isLoading,
          autocorrect:
              !obscureText && keyboardType != TextInputType.emailAddress,
          enableSuggestions: !obscureText,
          textCapitalization: label == 'Your name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          autofillHints: obscureText
              ? [_isSignUp ? AutofillHints.newPassword : AutofillHints.password]
              : keyboardType == TextInputType.emailAddress
              ? [AutofillHints.email]
              : label == 'Your name'
              ? [AutofillHints.name]
              : null,
          textInputAction: obscureText
              ? TextInputAction.done
              : TextInputAction.next,
          onSubmitted: obscureText ? (_) => _handleAuthSubmit() : null,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            labelText: label,
            suffixIcon: obscureText
                ? IconButton(
                    tooltip: _passwordVisible
                        ? 'Hide password'
                        : 'Show password',
                    onPressed: _isLoading
                        ? null
                        : () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  )
                : null,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
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
