import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usuarios_screen.dart';
import 'cliente_screen.dart';
import 'trabajador_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final nombreController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _cargando = false;

  void login() async {
    setState(() => _cargando = true);
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: correoController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final rol = doc.data()?['rol'] ?? 'cliente';

      if (!mounted) return;

      switch (rol) {
        case 'admin':
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const UsuariosScreen()));
          break;
        case 'trabajador':
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => TrabajadorScreen(uid: uid)));
          break;
        default:
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => ClienteScreen(uid: uid)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void registrar() async {
    if (nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu nombre')),
      );
      return;
    }
    if (correoController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: correoController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = cred.user!.uid;
      final correo = correoController.text.trim();
      final nombre = nombreController.text.trim();

      final clienteRef = await FirebaseFirestore.instance.collection('clientes').add({
        'nombre': nombre,
        'correo': correo,
        'telefono': '',
        'empresa': '',
        'estado': 'activo',
        'creadoEn': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'correo': correo,
        'nombre': nombre,
        'rol': 'cliente',
        'cliente_id': clienteRef.id,
        'creadoEn': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ClienteScreen(uid: uid)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TechSolutions",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Bienvenido, inicia sesión o regístrate",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      labelText: "Nombre completo",
                      hintText: "Solo requerido al registrarse",
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: correoController,
                    decoration: InputDecoration(
                      labelText: "Correo",
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  if (_cargando)
                    const CircularProgressIndicator()
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: login,
                        icon: const Icon(Icons.login),
                        label: const Text("Iniciar Sesión"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: registrar,
                        icon: const Icon(Icons.person_add),
                        label: const Text("Registrarse"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: theme.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
