import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/service_provider.dart';
import 'services/service_manager.dart';
import 'ui/login_screen.dart';
import 'ui/home_screen.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = Logger('MAIN');
  logger.info('START', 'App starting');

  try {
    // Initialize dependencies
    final prefs = await SharedPreferences.getInstance();
    final googleSignIn = GoogleSignIn(
      scopes: AppConstants.googleScopes,
    );

    // Initialize service manager
    final serviceManager = ServiceManager.instance;
    await serviceManager.initialize();

    runApp(GmailAlarmApp(
      prefs: prefs,
      googleSignIn: googleSignIn,
      serviceManager: serviceManager,
    ));

    logger.info('START', 'App started successfully');
  } catch (e, stack) {
    logger.exception('START', 'Failed to start app', e, stack);
    rethrow;
  }
}

class GmailAlarmApp extends StatelessWidget {
  final SharedPreferences prefs;
  final GoogleSignIn googleSignIn;
  final ServiceManager serviceManager;

  const GmailAlarmApp({
    super.key,
    required this.prefs,
    required this.googleSignIn,
    required this.serviceManager,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(googleSignIn, prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AlarmProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => ServiceProvider(prefs, serviceManager),
        ),
      ],
      child: MaterialApp(
        title: 'Gmail Alarm',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (!auth.isSignedIn) {
              return const LoginScreen();
            }

            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
