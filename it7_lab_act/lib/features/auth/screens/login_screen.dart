import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../providers/auth_provider.dart';
import '../validators.dart';
import '../widgets/forgot_password_sheet.dart';
import '../widgets/password_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    if (success) {
      navigator.pop();
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
      appBar: AppBar(title: const Text('Account Login')),
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
                    'https://assets3.lottiefiles.com/packages/lf20_m95223ed.json',
                    height: 160,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.lock_person_outlined,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                  ) as Widget)
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 16),

                  Text(
                    'Welcome Back!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 6),

                  Text(
                    'Sign in to access your saved profile and track orders',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 32),

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
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  PasswordField(
                    controller: _passwordController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => isLoading ? null : _submitLogin(),
                    autofillHints: const [AutofillHints.password],
                    validator: AuthValidators.loginPassword,
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => ForgotPasswordSheet.show(
                                context,
                                initialEmail: _emailController.text,
                              ),
                      child: const Text('Forgot password?'),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitLogin,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 550.ms)
                      .scale(begin: const Offset(0.95, 0.95)),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 650.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
