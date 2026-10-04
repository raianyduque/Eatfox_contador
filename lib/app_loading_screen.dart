// tela de carregamento com animaçao

import 'package:flutter/material.dart';

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: _animation,
              child: const Icon(
                Icons.restaurant_rounded,
                size: 80,
                color: Color(0xFFFF6B00),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Carregando...',
              style: TextStyle(
                fontFamily: 'LilitaOne',
                fontSize: 22,
                color: Color(0xFFFF6B00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}