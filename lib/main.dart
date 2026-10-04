// chamada principal para iniciar o app e o banco de dados

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 

import 'screens/auth/auth_screen.dart'; 
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import '../app_loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('---> Firebase conectado com sucesso!');
    
    print('⏳ Iniciando o salvamento no banco de dados...');
    
  } catch (e) {
    print('---> ERRO CRÍTICO NO FIREBASE: $e');
  }

  runApp(const DietAIApp());
}


class DietAIApp extends StatelessWidget {
  const DietAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diet AI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingScreen();
          }
          
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(snapshot.data!.uid).get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingScreen();
                }
                
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  var data = userSnapshot.data!.data() as Map<String, dynamic>;
                  bool onboarding = data['onboardingCompleto'] ?? false;
                  String nomeMascote = data['nomeMascote'] ?? 'Bixinho';
                  
                  if (onboarding) {
                    return HomeScreen(mascotName: nomeMascote);
                  } else {
                    return const OnboardingScreen();
                  }
                }
                return const OnboardingScreen();
              },
            );
          }
          
          return const AuthScreen();
        },
      ),
    );
  }
}