import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../services/firebase_service.dart';
import 'sport_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        fullName: _nameCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SportSelectionScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Registration failed. Email may already be in use.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create account 🚀',
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('Join your local sports community',
                  style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 40),
              _buildField(controller: _nameCtrl, label: 'Full Name', icon: Icons.person_rounded),
              const SizedBox(height: 16),
              _buildField(controller: _emailCtrl, label: 'Email', icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField(
                controller: _passwordCtrl,
                label: 'Password',
                icon: Icons.lock_rounded,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: AppColors.textTertiary),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.error_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 14))),
                  ]),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text('Create Account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(text: 'Sign In', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }
}
