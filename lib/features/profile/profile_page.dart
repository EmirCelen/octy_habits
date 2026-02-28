import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ElevatedButton.icon(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.settings),
          label: const Text('Settings'),
        ),
      ),
    );
  }
}
