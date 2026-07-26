import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:videon/common/utils/snackbar_utils.dart';
import 'package:videon/components/button/t_primary_button.dart';
import 'package:videon/components/textfield/t_text_field.dart';
import 'package:videon/features/auth/screens/login_screen.dart';
import 'package:videon/features/services/wrapper.dart';
import 'package:videon/styles/app_assets.dart';
import 'package:videon/styles/app_colors.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isPasswordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signup() async {
    final name = nameController.text.trim();

    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: emailController.text,
      password: passwordController.text,
    );

    // Save the display name on the Firebase user...
    await credential.user?.updateDisplayName(name);
    await credential.user?.reload();

    // ...and also locally in Hive, so ProfileScreen can show/edit it
    // the same way it already does for the phone number.
    final profileBox = Hive.box('profileBox');
    await profileBox.put('name', name);

    Get.offAll(() => const Wrapper());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  AppAssets.logo,
                  height: 100,
                ),
                const SizedBox(height: 48),
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up your account',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TTextField(
                        textEditingController: nameController,
                        prefixIcon: const Icon(Icons.person_outline),
                        label: 'Name',
                        hint: 'Enter your name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TTextField(
                        textEditingController: emailController,
                        prefixIcon: const Icon(Icons.email_outlined),
                        label: 'Email',
                        hint: 'Enter your email',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TTextField(
                        textEditingController: passwordController,
                        obscureText: !isPasswordVisible,
                        prefixIcon: const Icon(Icons.lock_outline),
                        label: 'Password',
                        hint: 'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      TPrimaryButton(
                        label: 'Sign up',
                        isBusy: false,
                        onPressed: () async {
                          try {
                            await signup();
                          } catch (e) {
                            SnackBarUtils.showCustomSnackBar(
                              // ignore: use_build_context_synchronously
                              context: context,
                              // content: 'Something went wrong',
                              content: e.toString(),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            text: "Already have an account? ",
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: const [
                              TextSpan(
                                text: 'Login',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}