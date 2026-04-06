import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home_screen.dart';
import 'features/auth_screen.dart';
import 'core/api_client.dart';

void main() {
  // Overarching Riverpod scope.
  runApp(const ProviderScope(child: PetVisionApp()));
}

class PetVisionApp extends ConsumerWidget {
  const PetVisionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the overarching token natively.
    final token = ref.watch(authProvider);

    return MaterialApp(
      title: 'PetVision AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF02569B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // If token is null, block the application routing.
      home: token == null ? const AuthScreen() : const HomeScreen(),
    );
  }
}
