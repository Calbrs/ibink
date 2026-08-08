import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme.dart';
import 'core/session.dart';
import 'core/api_client.dart';
import 'core/local_storage.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Session.instance.init();
  await LocalStorage.instance.init();
  ApiClient.instance.restoreTokenFromSession();

  runApp(const IBinkSellerApp());
}

class IBinkSellerApp extends StatelessWidget {
  const IBinkSellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'iBink.me Seller',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.theme,
    );
  }
}