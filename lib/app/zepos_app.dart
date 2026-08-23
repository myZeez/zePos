import 'package:flutter/material.dart';
import 'package:zepos/app/routing/zepos_shell.dart';
import 'package:zepos/app/widgets/app_status_pages.dart';
import 'package:zepos/data/zepos_database.dart';
import 'package:zepos/domain/store_profile.dart';
import 'package:zepos/features/auth/change_password_page.dart';
import 'package:zepos/features/auth/credential_setup_page.dart';
import 'package:zepos/features/auth/login_page.dart';
import 'package:zepos/features/auth/onboarding_page.dart';
import 'package:zepos/ui/zepos_tokens.dart';

class ZePosApp extends StatefulWidget {
  const ZePosApp({super.key, this.database});

  final ZePosDatabase? database;

  @override
  State<ZePosApp> createState() => _ZePosAppState();
}

class _ZePosAppState extends State<ZePosApp> {
  late Future<ZePosDatabase> _databaseFuture;
  var _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _openDatabase();
  }

  void _openDatabase() {
    _databaseFuture = widget.database == null
        ? ZePosDatabase.open()
        : Future<ZePosDatabase>.value(widget.database);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZePOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ZeColors.primary,
          brightness: Brightness.light,
          surface: ZeColors.surface,
        ),
        scaffoldBackgroundColor: ZeColors.background,
        textTheme: ThemeData.light().textTheme
            .apply(
              bodyColor: ZeColors.body,
              displayColor: ZeColors.ink,
              fontFamily: 'Arial',
            )
            .copyWith(
              headlineSmall: ZeText.pageTitle,
              titleLarge: ZeText.sectionTitle,
              titleMedium: ZeText.cardTitle,
              bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
              bodyMedium: ZeText.body,
              bodySmall: ZeText.meta,
              labelLarge: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              labelMedium: ZeText.label,
            ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ZeColors.background,
          foregroundColor: ZeColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(44, 46),
            backgroundColor: ZeColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: ZeRadius.control),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 46),
            foregroundColor: ZeColors.primaryDark,
            side: const BorderSide(color: ZeColors.primary, width: 1.25),
            shape: RoundedRectangleBorder(borderRadius: ZeRadius.control),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ZeColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: const OutlineInputBorder(
            borderRadius: ZeRadius.control,
            borderSide: BorderSide(color: ZeColors.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: ZeRadius.control,
            borderSide: BorderSide(color: ZeColors.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: ZeRadius.control,
            borderSide: BorderSide(color: ZeColors.primary, width: 2),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: ZeColors.borderSoft,
          thickness: 1,
          space: 1,
        ),
        cardTheme: const CardThemeData(
          color: ZeColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: ZeRadius.panel,
            side: BorderSide(color: ZeColors.border),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: ZeColors.surface,
          indicatorColor: ZeColors.surfaceSelected,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? ZeColors.primaryDark
                  : ZeColors.navigationInk,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: FutureBuilder<ZePosDatabase>(
        future: _databaseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingPage();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return AppDatabaseErrorPage(onRetry: () => setState(_openDatabase));
          }
          return FutureBuilder<StoreProfile?>(
            future: snapshot.data!.loadStoreProfile(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState != ConnectionState.done) {
                return const AppLoadingPage();
              }
              if (profileSnapshot.hasError) {
                return AppDatabaseErrorPage(
                  onRetry: () => setState(_openDatabase),
                );
              }
              if (profileSnapshot.data == null) {
                return OnboardingPage(
                  database: snapshot.data!,
                  onCompleted: () => setState(() {
                    _isAuthenticated = false;
                    _openDatabase();
                  }),
                );
              }
              return FutureBuilder<CredentialInfo?>(
                future: snapshot.data!.loadCredentialInfo(),
                builder: (context, credentialSnapshot) {
                  if (credentialSnapshot.connectionState !=
                      ConnectionState.done) {
                    return const AppLoadingPage();
                  }
                  if (credentialSnapshot.hasError) {
                    return AppDatabaseErrorPage(
                      onRetry: () => setState(_openDatabase),
                    );
                  }
                  final credentials = credentialSnapshot.data;
                  if (credentials == null) {
                    return CredentialSetupPage(
                      database: snapshot.data!,
                      onCompleted: () => setState(_openDatabase),
                    );
                  }
                  if (!_isAuthenticated) {
                    return LoginPage(
                      database: snapshot.data!,
                      onAuthenticated: () =>
                          setState(() => _isAuthenticated = true),
                    );
                  }
                  if (credentials.mustChangePassword) {
                    return ChangePasswordPage(
                      database: snapshot.data!,
                      username: credentials.username,
                      onCompleted: () => setState(_openDatabase),
                    );
                  }
                  return ZePosShell(
                    database: snapshot.data!,
                    onDatabaseRestored: () => setState(_openDatabase),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
