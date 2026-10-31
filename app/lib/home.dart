import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/connect_button.dart';

/// Placeholder home screen: the connect button and its state. The core is not
/// wired yet, so the toggle only drives the animation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConnectButton(
                connected: _connected,
                onPressed: () => setState(() => _connected = !_connected),
              ),
              const SizedBox(height: 32),
              Text(
                _connected ? 'Подключено' : 'Не подключено',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _connected ? CrocellColors.primary : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Добавьте подписку, чтобы выбрать ноду',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
