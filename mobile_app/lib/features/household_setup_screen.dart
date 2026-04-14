import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/api_client.dart';
import 'add_pet_screen.dart';

class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  String joinCode = "";
  bool isJoining = false;

  Future<void> submitJoinCode() async {
    if (joinCode.isEmpty) return;
    setState(() => isJoining = true);
    
    try {
      await ref.read(apiClientProvider).joinPetHousehold(joinCode.trim());
      ref.invalidate(petsListProvider);
      if (mounted) Navigator.pop(context);
    } catch(e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text(e.toString().replaceAll('Exception: ', '')),
           backgroundColor: Colors.redAccent,
           behavior: SnackBarBehavior.floating,
         ));
      }
    } finally {
      if (mounted) setState(() => isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text("Household Setup", style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add a Pet to Your Account", style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1, height: 1.2)),
              const SizedBox(height: 12),
              Text("Are you creating a brand new profile, or joining an existing pet's household?", style: GoogleFonts.plusJakartaSans(fontSize: 16, color: Colors.grey.shade600, height: 1.5)),
              const SizedBox(height: 40),
              
              // Option 1: Primary Owner (Create New)
              GestureDetector(
                onTap: () {
                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AddPetScreen()));
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 2)
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Create New Profile", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(height: 4),
                            Text("I am the primary owner establishing a new pet AI profile.", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600, height: 1.4)),
                          ],
                        )
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey)
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                   Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                   ),
                   Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 24),
              
              // Option 2: Join Partner (Co-Parent)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))],
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 2)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.purpleAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.family_restroom, color: Colors.purpleAccent, size: 32),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Join Co-Parent", style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                              const SizedBox(height: 4),
                              Text("Join a pet heavily tracked by your partner.", style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.grey.shade600)),
                            ],
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                       child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                             const SizedBox(width: 12),
                             Expanded(child: Text("Ask your partner to open their PetVision Home Screen. The 6-digit invite code is displayed directly on the Pet's Hero Card.", style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.orange.shade900, height: 1.5, fontWeight: FontWeight.w600)))
                          ],
                       )
                    ),
                    const SizedBox(height: 24),
                    Text("Enter Invite Code", style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => joinCode = val,
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 4.0),
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              counterText: "",
                              hintText: "XXXXXX",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.purpleAccent, width: 2)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                       width: double.infinity,
                       height: 56,
                       child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.purpleAccent,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                             elevation: 0
                          ),
                          onPressed: isJoining ? null : submitJoinCode,
                          child: isJoining ? const CircularProgressIndicator(color: Colors.white) : Text("Connect to Household", style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))
                       )
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
