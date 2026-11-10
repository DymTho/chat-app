import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/auth_service.dart';
import '../theme/app_palette.dart';
import '../widgets/image_source_sheet.dart';

/// Login and registration in one screen with an animated mode switch.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLogin = true;
  bool _busy = false;
  bool _obscure = true;
  bool _missingImage = false;
  Uint8List? _image;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final bytes = await pickAvatarImage(context);
    if (bytes != null) {
      setState(() {
        _image = bytes;
        _missingImage = false;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    if (!_isLogin && _image == null) setState(() => _missingImage = true);
    if (!valid || (!_isLogin && _image == null)) return;

    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (_isLogin) {
        await auth.login(email: _emailCtrl.text, password: _passwordCtrl.text);
      } else {
        await auth.signUp(
          email: _emailCtrl.text,
          username: _usernameCtrl.text,
          password: _passwordCtrl.text,
          avatarBytes: _image!,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(AuthService.messageFor(e))),
            ],
          ),
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: palette.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const _FloatingBubbles(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        const _Logo(),
                        const SizedBox(height: 14),
                        Text(
                          'Chatloop',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.3, end: 0),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isLogin
                                ? 'Welcome back! Sign in to continue'
                                : 'Create an account to start chatting',
                            key: ValueKey(_isLogin),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ),
                        const SizedBox(height: 26),
                        _buildCard(context)
                            .animate()
                            .fadeIn(delay: 250.ms, duration: 500.ms)
                            .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeToggle(
                isLogin: _isLogin,
                onChanged: _busy
                    ? null
                    : (login) => setState(() {
                          _isLogin = login;
                          _missingImage = false;
                          _formKey.currentState?.reset();
                        }),
              ),
              const SizedBox(height: 22),
              if (!_isLogin) ...[
                Center(child: _AvatarPicker(image: _image, error: _missingImage, onTap: _pickImage)),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Please enter your email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.length < 4) return 'At least 4 characters';
                    if (value.length > 24) return 'At most 24 characters';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                autofillHints: [_isLogin ? AutofillHints.password : AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _busy
                      ? const SizedBox(
                          key: ValueKey('busy'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(_isLogin ? 'Log in' : 'Create account', key: ValueKey(_isLogin)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => setState(() => _isLogin = !_isLogin),
                child: Text.rich(
                  TextSpan(
                    text: _isLogin ? "Don't have an account? " : 'Already have an account? ',
                    style: TextStyle(color: palette.muted, fontWeight: FontWeight.w400),
                    children: [
                      TextSpan(
                        text: _isLogin ? 'Sign up' : 'Log in',
                        style: TextStyle(
                            color: palette.spec.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.isLogin, required this.onChanged});

  final bool isLogin;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    Widget tab(String label, bool login) => Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onChanged == null ? null : () => onChanged!(login),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: theme.textTheme.labelLarge!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isLogin == login ? Colors.white : palette.muted,
                ),
                child: Text(label),
              ),
            ),
          ),
        );

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.spec.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: palette.spec.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(children: [tab('Log in', true), tab('Sign up', false)]),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({required this.image, required this.error, required this.onTap});

  final Uint8List? image;
  final bool error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.spec.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: error ? errorColor : palette.spec.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  image: image == null
                      ? null
                      : DecorationImage(image: MemoryImage(image!), fit: BoxFit.cover),
                ),
                child: image == null
                    ? Icon(Icons.person_rounded, size: 48, color: palette.spec.primary)
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: palette.spec.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).colorScheme.surface, width: 3),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          error
              ? 'Please add a profile picture'
              : image == null
                  ? 'Add profile picture'
                  : 'Tap to change',
          style: TextStyle(
            fontSize: 12,
            color: error ? errorColor : palette.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate(target: error ? 1 : 0).shakeX(hz: 5, amount: 4);
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.chat_bubble_rounded, size: 52, color: palette.spec.primary),
          Positioned(
            top: 39,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .moveY(begin: 0, end: -4, delay: (i * 150).ms, duration: 300.ms)
                    .then()
                    .moveY(begin: -4, end: 0, duration: 300.ms)
                    .then(delay: 600.ms),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(begin: const Offset(0.6, 0.6), duration: 600.ms, curve: Curves.easeOutBack)
        .fadeIn();
  }
}

/// Decorative, slowly drifting translucent circles behind the auth card.
class _FloatingBubbles extends StatelessWidget {
  const _FloatingBubbles();

  @override
  Widget build(BuildContext context) {
    const specs = [
      (0.08, 0.10, 90.0, 0),
      (0.78, 0.06, 60.0, 400),
      (0.70, 0.78, 130.0, 200),
      (0.02, 0.70, 70.0, 700),
      (0.45, 0.92, 50.0, 300),
    ];
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          for (final (x, y, size, delay) in specs)
            Positioned(
              left: c.maxWidth * x,
              top: c.maxHeight * y,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              )
                  .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                  .moveY(begin: 0, end: 18, delay: delay.ms, duration: 3.seconds, curve: Curves.easeInOut),
            ),
        ],
      ),
    );
  }
}
