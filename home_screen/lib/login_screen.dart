import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main.dart'; // for HomeManager navigation

class SignUp extends StatefulWidget {
  const SignUp({super.key});
  @override
  State<SignUp> createState() => _SignUp();
}

class _SignUp extends State<SignUp> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String _email = '', _password = '', _name = '', _confirmPassword = '';
  bool _obstxt = true, _obstxt2 = true, _isLoading = false;

  Future<void> _signUp() async {
    if (_password != _confirmPassword) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _email.trim(),
        password: _password.trim(),
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': _name.trim(),
        'email': _email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("User signed up successfully!")));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LogIn()),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message ?? "Signup failed")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            color: Colors.teal,
            child: const Icon(Icons.music_note, color: Colors.white, size: 28),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Text("Sign Up",
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _textField("Name", Icons.person, (v) => _name = v!),
                            _textField("Email", Icons.email, (v) => _email = v!,
                                validator: (v) => v!.contains('@')
                                    ? null
                                    : "Enter valid email"),
                            _passwordField("Password", (v) => _password = v!,
                                isObscure: _obstxt, toggle: () {
                              setState(() => _obstxt = !_obstxt);
                            }),
                            _passwordField("Confirm Password", (v) => _confirmPassword = v!,
                                isObscure: _obstxt2, toggle: () {
                              setState(() => _obstxt2 = !_obstxt2);
                            }),
                            const SizedBox(height: 30),
                            _submitButton("Sign Up", _signUp),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LogIn()),
                              ),
                              child: const Text("Already have an account? Log In"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, IconData icon, Function(String?) onSave,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? (v) => v!.isEmpty ? "Enter $label" : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _passwordField(String label, Function(String?) onSave,
      {required bool isObscure, required VoidCallback toggle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        obscureText: isObscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
            onPressed: toggle,
          ),
          border: const OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? "Enter $label" : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _submitButton(String text, Function() onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: _isLoading
          ? null
          : () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                onPressed();
              }
            },
      child: _isLoading
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
          : Text(text),
    );
  }
}

class LogIn extends StatefulWidget {
  const LogIn({super.key});
  @override
  State<LogIn> createState() => _LogInState();
}

class _LogInState extends State<LogIn> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();

  String _email = '', _password = '';
  bool _obstxt = true, _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _email.trim(),
        password: _password.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Login successful!")));
          Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RootApp()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String error = "Login failed";
      if (e.code == 'user-not-found') error = "No user found with this email";
      if (e.code == 'wrong-password') error = "Incorrect password";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 60),
            color: Colors.teal,
            child: const Icon(Icons.music_note, color: Colors.white, size: 28),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    const Text("Log In",
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _textField("Email", Icons.email, (v) => _email = v!,
                                validator: (v) => v!.contains('@')
                                    ? null
                                    : "Enter valid email"),
                            _passwordField("Password", (v) => _password = v!,
                                isObscure: _obstxt, toggle: () {
                              setState(() => _obstxt = !_obstxt);
                            }),
                            const SizedBox(height: 30),
                            _submitButton("Login", _login),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const SignUp()),
                              ),
                              child: const Text("Don't have an account? Sign Up"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, IconData icon, Function(String?) onSave,
      {String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? (v) => v!.isEmpty ? "Enter $label" : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _passwordField(String label, Function(String?) onSave,
      {required bool isObscure, required VoidCallback toggle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        obscureText: isObscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off),
            onPressed: toggle,
          ),
          border: const OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? "Enter $label" : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _submitButton(String text, Function() onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: _isLoading
          ? null
          : () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                onPressed();
              }
            },
      child: _isLoading
          ? const SizedBox(
              width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
          : Text(text),
    );
  }
}
