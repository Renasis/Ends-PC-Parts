import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../providers/auth_provider.dart';
import '../validators.dart';
import '../widgets/password_field.dart';
import '../widgets/privacy_consent_field.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submitSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final success = await auth.signUp(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Welcome, ${_nameController.text.trim()}!'),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(auth.errorMessage),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cast needed: LottieBuilder has its own `animate` field that
                  // hides flutter_animate's `.animate()` extension.
                  (Lottie.network(
                    'https://assets3.lottiefiles.com/packages/lf20_ucby125k.json',
                    height: 150,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.person_add_alt_1_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ) as Widget)
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 16),

                  Text(
                    'Join PC Parts Store',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 6),

                  Text(
                    'Create an account to save shipping profiles and place orders',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 28),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: AuthValidators.name,
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: AuthValidators.email,
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  PasswordField(
                    controller: _passwordController,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.newPassword,
                  ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  PasswordField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => isLoading ? null : _submitSignUp(),
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.confirmPassword(
                      () => _passwordController.text,
                    ),
                  ).animate().fadeIn(delay: 650.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 12),

                  PrivacyConsentField(enabled: !isLoading)
                      .animate()
                      .fadeIn(delay: 700.ms),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitSignUp,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 750.ms)
                      .scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                ),
                        child: const Text('Login'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 850.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
