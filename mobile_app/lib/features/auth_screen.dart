import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      
      await auth.setToken(token);
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
           content: Text(e.toString().replaceAll('Exception: ', ''), style: const TextStyle(color: Colors.white)),
           backgroundColor: Colors.redAccent,
           behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark base
      body: Stack(
        children: [
          // 1. IMMERSIVE EDGE-TO-EDGE HERO BACKDROP
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, Colors.transparent], 
                  stops: [0.3, 0.9]
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: Image.network(
                'https://images.unsplash.com/photo-1543466835-00a7907e9de1?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                   if (progress == null) return child;
                   return Container(color: Colors.black);
                },
              ),
            ),
          ),

          // 2. FOREGROUND CONTENT
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Push container to bottom
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // BRAND LOGO
                             Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2))
                               ),
                               child: const Icon(Icons.psychology, color: Colors.white, size: 36),
                             ),
                             const SizedBox(height: 24),
                             Text("PetVision AI", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                             const SizedBox(height: 4),
                             Text(isLogin ? "Welcome back." : "Create Account.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white70)),
                             const SizedBox(height: 12),
                             Text("Sign in to access your deeply integrated veterinary engine.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[400], fontSize: 15, height: 1.4)),
                             const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      
                      // GLASSMORPHISM AUTH CARD
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(32, 48, 32, 64),
                            decoration: BoxDecoration(
                               color: Colors.black.withValues(alpha: 0.6),
                               border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5))
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // SSO Buttons
                                SizedBox(
                                   width: double.infinity, height: 56,
                                   child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                      icon: const Icon(Icons.g_mobiledata, size: 32),
                                      label: Text("Continue with Google", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                      onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firebase Auth coming soon'))); }
                                   )
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                   width: double.infinity, height: 56,
                                   child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                      icon: const Icon(Icons.apple, size: 28),
                                      label: Text("Continue with Apple", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 16)),
                                      onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Apple Auth coming soon'))); }
                                   )
                                ),
                                
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                     Expanded(child: Container(color: Colors.white24, height: 1)),
                                     Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR EMAIL", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13))),
                                     Expanded(child: Container(color: Colors.white24, height: 1)),
                                  ]
                                ),
                                const SizedBox(height: 32),
                                
                                _buildInput("Email Address", emailController, false, Icons.email_rounded),
                                const SizedBox(height: 24),
                                _buildInput("Password", passwordController, true, Icons.lock_rounded),
                                const SizedBox(height: 40),
                                
                                // Glowing Main CTA
                                SizedBox(
                                  width: double.infinity,
                                  height: 64,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]),
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [BoxShadow(color: const Color(0xFF1BFFFF).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                                      ),
                                      onPressed: isLoading ? null : submit,
                                      child: isLoading 
                                          ? const CircularProgressIndicator(color: Colors.white) 
                                          : Text(isLogin ? 'Activate Engine' : 'Initialize Account', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 16)),
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                Center(
                                  child: TextButton(
                                    style: TextButton.styleFrom(splashFactory: NoSplash.splashFactory),
                                    onPressed: () => setState(() => isLogin = !isLogin),
                                    child: RichText(
                                       text: TextSpan(
                                          text: isLogin ? "Don't have an account? " : "Already have an account? ",
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade400, fontWeight: FontWeight.w500, fontSize: 14),
                                          children: [
                                             TextSpan(text: isLogin ? "Sign up" : "Sign in", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))
                                          ]
                                       )
                                    )
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, bool isPassword, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
          keyboardAppearance: Brightness.dark,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white60, size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF1BFFFF), width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            hintText: isPassword ? '••••••••' : 'owner@petvision.com',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
      ],
    );
  }
}
