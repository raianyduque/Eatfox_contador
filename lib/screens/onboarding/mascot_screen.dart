// pagina do mascote, aqui seleciona o nome e direciona para a home

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart'; 

class MascotScreen extends StatefulWidget {
  final String userName;
  const MascotScreen({super.key, required this.userName});

  @override
  State<MascotScreen> createState() => _MascotScreenState();
}

class _MascotScreenState extends State<MascotScreen> with TickerProviderStateMixin {
  final TextEditingController _mascotNameController = TextEditingController();
  late VideoPlayerController _videoController;
  
  late AnimationController _revealController;
  
  int _step = 0;
  String _typedGreeting = "";
  late String _fullGreeting;

  @override
  void initState() {
    super.initState();
    _fullGreeting = 'Olá, ${widget.userName}!';
    
    _revealController = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _videoController = VideoPlayerController.asset('assets/mascote.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {});
      });

    _startTypingSequence();
  }

  void _startTypingSequence() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_typedGreeting.length < _fullGreeting.length) {
        setState(() {
          _typedGreeting = _fullGreeting.substring(0, _typedGreeting.length + 1);
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 600), () {
          setState(() => _step = 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _mascotNameController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryOrange, 
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _typedGreeting,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.pureWhite),
                    ),
                    const SizedBox(height: 20),
                    
                    AnimatedOpacity(
                      opacity: _step >= 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: const Text(
                        'O que você acha de ganhar um amigo nessa jornada?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    AnimatedOpacity(
                      opacity: _step >= 1 ? 1.0 : 0.0,
                      duration: const Duration(seconds: 1),
                      child: Container(
                        height: 220,
                        width: 220,
                        decoration: BoxDecoration(
                          color: AppTheme.pureWhite,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)],
                        ),
                        child: ClipOval(
                          child: _videoController.value.isInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _videoController.value.size.width,
                                    height: _videoController.value.size.height,
                                    child: VideoPlayer(_videoController),
                                  ),
                                )
                              : const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    AnimatedOpacity(
                      opacity: _step >= 1 ? 1.0 : 0.0,
                      duration: const Duration(seconds: 1),
                      child: TextField(
                        controller: _mascotNameController,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Dê nome ao seu amigo!',
                          filled: true,
                          fillColor: AppTheme.pureWhite,
                          prefixIcon: const Icon(Icons.pets, color: AppTheme.primaryOrange),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30), 
                            borderSide: BorderSide.none
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    if (_step >= 1)
                      GestureDetector(
                        onTapDown: (_) async {
                          if (_mascotNameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, dê um nome ao seu mascote!')));
                            return;
                          }
                          
                          // Salva o nome do mascote no Firebase
                          User? user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
                              'nomeMascote': _mascotNameController.text.trim(),
                            });
                          }

                          _revealController.forward().then((_) {
                            if (_revealController.isCompleted) {
                              Navigator.pushReplacement(
                                context, 
                                MaterialPageRoute(builder: (context) => HomeScreen(mascotName: _mascotNameController.text.trim()))
                              );
                            }
                          });
                        },
                        onTapUp: (_) {
                          if (!_revealController.isCompleted) {
                            _revealController.reverse();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Continue segurando para iniciar a jornada!'),
                              duration: Duration(milliseconds: 1500),
                            ));
                          }
                        },
                        onTapCancel: () => _revealController.reverse(),
                        child: AnimatedBuilder(
                          animation: _revealController,
                          builder: (context, child) {
                            return Container(
                              height: 55,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppTheme.pureWhite,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                              ),
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    widthFactor: _revealController.value,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade200,
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.rocket_launch, color: AppTheme.primaryOrange),
                                        SizedBox(width: 8),
                                        Text('Segure para Iniciar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryOrange)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}