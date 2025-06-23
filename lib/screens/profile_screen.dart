import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tourify_flutter/services/auth_service.dart';
import 'package:tourify_flutter/services/user_service.dart';
import 'package:tourify_flutter/screens/login_screen.dart';
import 'package:tourify_flutter/services/navigation_service.dart';
import '../widgets/common/custom_bottom_navigation_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  final Map<String, String> _formData = {
    'name': '',
    'username': '',
    'location': '',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, authSnapshot) {
        // Si no hay usuario autenticado, mostrar pantalla de login
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return _buildLoginScreen(context);
        }

        final user = authSnapshot.data!;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: UserService.getUserDataStream(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error: ${userSnapshot.error}'),
                ),
              );
            }

            // Si no existe el documento del usuario, créalo
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return FutureBuilder(
                future: UserService.createUserDocument(user),
                builder: (context, createSnapshot) {
                  if (createSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  // Después de crear, se actualizará automáticamente el stream
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                },
              );
            }

            final userData = userSnapshot.data!.data()!;

            // Inicializar formData si no está en modo edición
            if (!_isEditing) {
              _formData['name'] =
                  userData['name']?.toString().isNotEmpty == true
                      ? userData['name'].toString()
                      : (user.displayName?.isNotEmpty == true
                          ? user.displayName!
                          : 'Usuario');
              _formData['username'] =
                  userData['username']?.toString().isNotEmpty == true
                      ? userData['username'].toString()
                      : (user.email?.split('@')[0] ?? 'usuario');
              _formData['location'] = userData['location']?.toString() ?? '';
            }

            return _buildProfileScreen(context, user, userData);
          },
        );
      },
    );
  }

  Future<void> _handleSave(User user, Map<String, dynamic> userData) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final success = await UserService.updateUserProfile(
          userId: user.uid,
          name: _formData['name'],
          username: _formData['username'],
          location: _formData['location'],
        );

        if (success) {
          setState(() {
            _isEditing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al guardar los cambios')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      // Navegar a la pantalla de login directamente y limpiar el historial
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  Widget _buildProfileScreen(
      BuildContext context, User user, Map<String, dynamic> userData) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  // Sección de perfil
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                              ),
                              child: (userData['photoURL'] != null &&
                                      userData['photoURL']
                                          .toString()
                                          .isNotEmpty)
                                  ? ClipOval(
                                      child: Image.network(
                                        userData['photoURL'],
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Text(
                                              userData['name'] != null &&
                                                      userData['name']
                                                          .toString()
                                                          .isNotEmpty
                                                  ? userData['name']
                                                      .toString()[0]
                                                      .toUpperCase()
                                                  : (user.displayName != null &&
                                                          user.displayName!
                                                              .isNotEmpty
                                                      ? user.displayName![0]
                                                          .toUpperCase()
                                                      : 'U'),
                                              style: const TextStyle(
                                                fontSize: 48,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        userData['name'] != null &&
                                                userData['name']
                                                    .toString()
                                                    .isNotEmpty
                                            ? userData['name']
                                                .toString()[0]
                                                .toUpperCase()
                                            : (user.displayName != null &&
                                                    user.displayName!.isNotEmpty
                                                ? user.displayName![0]
                                                    .toUpperCase()
                                                : 'U'),
                                        style: const TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          userData['name']?.toString().isNotEmpty == true
                              ? userData['name'].toString()
                              : (user.displayName?.isNotEmpty == true
                                  ? user.displayName!
                                  : 'Usuario'),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${userData['username']?.toString().isNotEmpty == true ? userData['username'].toString() : (user.email?.split('@')[0] ?? 'usuario')}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              userData['location']?.toString().isNotEmpty ==
                                      true
                                  ? userData['location'].toString()
                                  : 'Sin ubicación',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta de estadísticas
                  FutureBuilder<int>(
                    future: UserService.getUserGuidesCount(user.uid),
                    builder: (context, guidesSnapshot) {
                      final guidesCount = guidesSnapshot.data ?? 0;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resumen de Actividad',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.map,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Guías',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Total de guías creadas',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  guidesCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Sección de configuración
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configuración de la Cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditing) ...[
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: _formData['name'],
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre',
                                    hintText: 'Tu nombre',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu nombre';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    _formData['name'] = value;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: _formData['username'],
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre de usuario',
                                    hintText: 'Tu nombre de usuario',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor ingresa tu nombre de usuario';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    _formData['username'] = value;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  initialValue: _formData['location'],
                                  decoration: const InputDecoration(
                                    labelText: 'Ubicación',
                                    hintText: 'Tu ubicación',
                                  ),
                                  onChanged: (value) {
                                    _formData['location'] = value;
                                  },
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditing = false;
                                            // Restaurar valores originales
                                            _formData['name'] =
                                                userData['name'];
                                            _formData['username'] =
                                                userData['username'];
                                            _formData['location'] =
                                                userData['location'];
                                          });
                                        },
                                        child: const Text('Cancelar'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : () => _handleSave(user, userData),
                                        icon: const Icon(Icons.save),
                                        label: const Text('Guardar'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Editar perfil'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _handleLogout,
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text(
                                'Cerrar sesión',
                                style: TextStyle(color: Colors.red),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(
                      height: 80), // Espacio para la barra de navegación
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              NavigationService.navigateToMainScreen('/home');
              break;
            case 1:
              NavigationService.navigateToMainScreen('/my-guides');
              break;
            case 2:
              // Already on profile, do nothing
              break;
          }
        },
      ),
    );
  }

  Widget _buildLoginScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o icono
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E8B57),
                  borderRadius: BorderRadius.circular(60),
                ),
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Título
              const Text(
                'Accede a tu perfil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              const Text(
                'Inicia sesión para acceder a tu perfil, gestionar tus viajes y personalizar tu experiencia',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Botón de iniciar sesión
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToLogin(context),
                  icon: const Icon(
                    Icons.login,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Iniciar sesión',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Botón para continuar sin cuenta
              TextButton(
                onPressed: () {
                  NavigationService.navigateToMainScreen('/home');
                },
                child: const Text(
                  'Continuar sin cuenta',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
