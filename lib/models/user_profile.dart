// dados base do usuario

import 'package:flutter/material.dart';

class UserProfile {
  String nome = '';
  String sexo = '';
  int idade = 0;
  double altura = 0.0;
  double peso = 0.0;
  String objetivo = '';
  double metaPeso = 0.0;
  String ritmoMeta = '';
  DateTime? prazoMeta;
  String tipoTrabalho = '';
  String nivelEsporte = '';
  String lembretes = '';
  int refeicoesPorDia = 0;
  String janelaAlimentacao = '';
  TimeOfDay? horaInicioAlimentacao;
  TimeOfDay? horaFimAlimentacao;
  String tipoDieta = '';
  List<String> restricoes = [];
  String modoCalorias = ''; 
}