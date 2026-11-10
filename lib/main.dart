import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'providers/providers.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'theme/app_palette.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const ChatApp(),
    ),
  );
}

class ChatApp extends ConsumerWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(themeControllerProvider);
    final spec = PaletteSpec.byId(settings.palette);

    return MaterialApp(
      title: 'Chatloop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(spec, Brightness.light),
      darkTheme: AppTheme.build(spec, Brightness.dark),
      themeMode: settings.mode,
      themeAnimationDuration: const Duration(milliseconds: 400),
      home: const AuthGate(),
    );
  }
}

/// Shows the chat UI only to authenticated users (lecture pattern:
/// StreamBuilder over `authStateChanges`).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: auth.when(
        loading: () => const _Splash(key: ValueKey('splash')),
        error: (e, _) => const AuthScreen(key: ValueKey('auth')),
        data: (user) => user == null
            ? const AuthScreen(key: ValueKey('auth'))
            : HomeShell(key: ValueKey(user.uid)),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: palette.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(Icons.chat_bubble_rounded, size: 72, color: Colors.white),
        ),
      ),
    );
  }
}
