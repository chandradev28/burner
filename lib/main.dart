import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/skins.dart';
import 'providers/addon_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/library_provider.dart';
import 'providers/skin_provider.dart';
import 'providers/sources_provider.dart';
import 'providers/telegram_account_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const BurnerApp());
}

class BurnerApp extends StatelessWidget {
  const BurnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SkinProvider()),
        ChangeNotifierProvider(create: (_) => AddonProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => SourcesProvider()),
        // Restores an existing Telegram session on launch.
        ChangeNotifierProvider(
          create: (_) => TelegramAccountProvider()..init(),
        ),
      ],
      // The whole app is rebuilt with a new ThemeData when the skin changes,
      // so switching UI restyles every screen at once.
      child: Consumer<SkinProvider>(
        builder: (context, skins, _) {
          final skin = skins.skin;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildSkinTheme(skin),
            // Clamp the OS font scale so large accessibility settings can never
            // break layouts / overflow the nav bar on small phones.
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.15,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
