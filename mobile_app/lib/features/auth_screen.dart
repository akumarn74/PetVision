import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_client.dart';
import 'home_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> submit() async {
    final auth = ref.read(authProvider.notifier);
    final client = ref.read(apiClientProvider);

    setState(() => isLoading = true);
    
    try {
      String token;
      if (isLogin) {
        token = await client.login(emailController.text.trim(), passwordController.text);
      } else {
        token = await client.register(emailController.text.trim(), passwordController.text);
      }
      
      // Save Token Natively
      await auth.setToken(token);
      
      // Navigate to Home safely bypassing the Navigator history
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                child: const Icon(Icons.psychology, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),
              Text(isLogin ? "Welcome back." : "Create an account.", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1)),
              const SizedBox(height: 8),
              Text("Sign in to access your AI Veterinary dashboard and pet profiles safely.", style: GoogleFonts.plusJakartaSans(color: Colors.grey[600], fontSize: 16, height: 1.5)),
              const SizedBox(height: 48),

              // Inputs
              _buildInput("Email Address", emailController, false),
              const SizedBox(height: 24),
              _buildInput("Password", passwordController, true),
              const SizedBox(height: 48),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    elevation: 10,
                    shadowColor: Colors.black38,
                  ),
                  onPressed: isLoading ? null : submit,
                  child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text(isLogin ? 'Sign In' : 'Register', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? "Don't have an account? Sign up" : "Already have an account? Sign in",
                    style: GoogleFonts.plusJakartaSans(color: Colors.blueAccent, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              )
            ],
          ),
        )
      )
    );
  }

  Widget _buildInput(String label, TextEditingController controller, bool isPassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          ),
        ),
      ],
    );
  }
}
