// pagina de sumario, calculos sao feitos com base nas informaçoes do usuario do cadastro, e mostrado dados com get, imc, tmb, consumo de agua etc.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import 'mascot_screen.dart';

class SummaryScreen extends StatelessWidget {
  final UserProfile profile;
  final bool isRedefining;

  const SummaryScreen({
    super.key,
    required this.profile,
    this.isRedefining = false,
  });

  double calcularIMC() {
    if (profile.altura == 0 || profile.peso == 0) return 0;
    double alturaMetros = profile.altura / 100;
    return profile.peso / (alturaMetros * alturaMetros);
  }

  int calcularTMB() {
    if (profile.sexo == 'Masculino') {
      return (10 * profile.peso + 6.25 * profile.altura - 5 * profile.idade + 5).round();
    } else {
      return (10 * profile.peso + 6.25 * profile.altura - 5 * profile.idade - 161).round();
    }
  }

  double calcularGET(int tmb) {
    double multiplier = 1.2;
    switch (profile.nivelEsporte) {
      case 'Não ativo':
        multiplier = 1.2;
        break;
      case 'Pouco ativo':
        multiplier = 1.375;
        break;
      case 'Moderadamente ativo':
        multiplier = 1.55;
        break;
      case 'Muito ativo':
        multiplier = 1.725;
        break;
      case 'Extremamente ativo':
        multiplier = 1.9;
        break;
    }
    return tmb * multiplier;
  }

  int calcularCaloriasAlvo(int tmb, double get) {
    double calorias = get;

    double taxaSemanal = 0.50; // Ideal
    if (profile.ritmoMeta == 'Lento') taxaSemanal = 0.25;
    if (profile.ritmoMeta == 'Rápido') taxaSemanal = 0.75;

    double ajusteDiario = (taxaSemanal * 7700) / 7;

    if (profile.objetivo == 'Perder peso') {
      calorias -= ajusteDiario;
      if (calorias < tmb) calorias = tmb.toDouble();
    } else if (profile.objetivo == 'Ganhar peso' || profile.objetivo == 'Ganhar massa') {
      calorias += ajusteDiario;
    }

    return calorias.round();
  }

  Map<String, int> calcularMacros(int calorias) {
    double protPorKg = 1.0;
    if (profile.objetivo == 'Ganhar massa' || profile.objetivo == 'Ganhar peso') {
      protPorKg = 2.0;
    } else if (profile.objetivo == 'Perder peso') {
      protPorKg = 2.2;
    }

    int proteinaGramas = (profile.peso * protPorKg).round();
    int gorduraGramas = (profile.peso * 1.0).round();

    int calProteina = proteinaGramas * 4;
    int calGordura = gorduraGramas * 9;

    int calRestante = calorias - (calProteina + calGordura);
    int carboGramas = (calRestante > 0) ? (calRestante / 4).round() : 0;

    return {
      'proteina': proteinaGramas,
      'gordura': gorduraGramas,
      'carbo': carboGramas,
    };
  }

  int calcularMetaGastoAtividade() {
    if (profile.objetivo == 'Perder peso') return 400;
    if (profile.objetivo == 'Ganhar peso' || profile.objetivo == 'Ganhar massa') return 200;
    return 300;
  }

  int calcularAgua() {
    return (profile.peso * 35).round();
  }

  String _feedbackIMC(double imc) {
    if (imc < 17) return 'Desnutrição';
    if (imc >= 17 && imc < 18.5) return 'Abaixo do peso';
    if (imc >= 18.5 && imc < 24.9) return 'Saudável (Normal)';
    if (imc >= 25 && imc < 29.9) return 'Sobrepeso (Atenção)';
    if (imc >= 30 && imc < 34.9) return 'Obesidade Grau 1';
    if (imc >= 35 && imc < 39.9) return 'Obesidade Grau 2';
    return 'Obesidade Grau 3 (Mórbida)';
  }

  String _descricaoIMC(double imc) {
    if (imc < 17)
      return 'Atenção: Seu IMC indica desnutrição. É essencial procurar orientação médica e nutricional urgente.';
    if (imc >= 17 && imc < 18.5)
      return 'Seu peso está abaixo do recomendado. Isso pode indicar deficiência nutricional. Busque ganhar massa de forma saudável.';
    if (imc >= 18.5 && imc < 24.9)
      return 'Excelente! Você está dentro do peso ideal. Continue com hábitos saudáveis para manter seu corpo forte.';
    if (imc >= 25 && imc < 29.9)
      return 'Você está um pouco acima do peso. Uma dieta balanceada e exercícios ajudarão a reduzir riscos cardiovasculares.';
    if (imc >= 30 && imc < 34.9)
      return 'Seu IMC indica Obesidade Grau 1. É importante acompanhamento médico, pois há maiores riscos de diabetes e hipertensão.';
    if (imc >= 35 && imc < 39.9)
      return 'Seu IMC indica Obesidade Grau 2. Recomenda-se acompanhamento profissional para melhorar sua saúde e qualidade de vida.';
    return 'Seu IMC indica Obesidade Grau 3. Procure ajuda médica urgente para evitar complicações graves à sua saúde.';
  }

  @override
  Widget build(BuildContext context) {
    double imc = calcularIMC();
    int tmb = calcularTMB();
    double get = calcularGET(tmb);
    int calorias = calcularCaloriasAlvo(tmb, get);
    int agua = calcularAgua();
    int metaAtividade = calcularMetaGastoAtividade();
    var macros = calcularMacros(calorias);

    bool sedentario = profile.nivelEsporte == 'Não ativo' || profile.nivelEsporte == 'Pouco ativo';

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: Text('Resumo de ${profile.nome}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (sedentario)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Alerta da OMS',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.deepOrange)),
                          SizedBox(height: 4),
                          Text(
                            'A Organização Mundial da Saúde recomenda 150 a 300 minutos de atividade física semanal. Que tal começar com caminhadas de 20 min?',
                            style: TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (profile.metaPeso > 0 && profile.prazoMeta != null)
              _buildAnimatedLineChart(),

            _buildFastingCard(),

            _buildResultCard(
              'Consumo Diário (Meta)',
              '$calorias kcal',
              Icons.flag_rounded,
              'Calorias ajustadas no ritmo "${profile.ritmoMeta}" para o objetivo de "${profile.objetivo}".',
            ),

            if (profile.objetivo == 'Perder peso')
              _buildResultCard(
                'Déficit Calórico',
                '${(get.round() - calorias).abs()} kcal / dia',
                Icons.trending_down,
                'Quantidade de calorias economizadas diariamente para emagrecer com saúde.',
              )
            else if (profile.objetivo == 'Ganhar peso' || profile.objetivo == 'Ganhar massa')
              _buildResultCard(
                'Superávit Calórico',
                '${(calorias - get.round()).abs()} kcal / dia',
                Icons.trending_up,
                'Calorias extras consumidas diariamente para focar no ganho muscular/peso.',
              ),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart, color: AppTheme.primaryOrange),
                      SizedBox(width: 8),
                      Text('Seus Macronutrientes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Baseado na sua meta, esta é a divisão ideal:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: _buildMacroItem(
                              'Proteínas', '${macros['proteina']}g', Colors.redAccent, 'Músculos', Icons.set_meal)),
                      Expanded(
                          child: _buildMacroItem(
                              'Carbos', '${macros['carbo']}g', Colors.orange, 'Energia', Icons.bakery_dining)),
                      Expanded(
                          child: _buildMacroItem(
                              'Gorduras', '${macros['gordura']}g', Colors.amber, 'Hormônios', Icons.water_drop)),
                    ],
                  ),
                ],
              ),
            ),

            _buildResultCard(
              'Taxa Metabólica Basal (TMB)',
              '$tmb kcal',
              Icons.local_fire_department,
              'Energia gasta apenas para sobreviver em repouso.',
            ),

            _buildResultCard(
              'Gasto Energético (GET)',
              '${get.round()} kcal',
              Icons.directions_run,
              'Estimativa de calorias que seu corpo gasta na sua rotina atual.',
            ),

            _buildResultCard(
              'Meta de Queima',
              '$metaAtividade kcal / dia',
              Icons.directions_walk_rounded,
              'Para gastar com exercícios ou passos diários.',
            ),
            _buildResultCard(
              'Água Recomendada',
              '${agua}ml',
              Icons.water_drop_rounded,
              'Calculado a ~35ml por kg corporal.',
            ),

            const SizedBox(height: 16),

            _buildAnimatedBMIGauge(imc),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  foregroundColor: AppTheme.pureWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(user.uid)
                        .set({
                      'metaAtividade': metaAtividade,
                    }, SetOptions(merge: true));

                    if (isRedefining) {
                      String dataStr = DateTime.now().toIso8601String().split('T')[0];
                      try {
                        await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(user.uid)
                            .collection('historico_diario')
                            .doc(dataStr)
                            .set({'metaAtividade': metaAtividade}, SetOptions(merge: true));
                            
                        await FirebaseFirestore.instance
                            .collection('usuarios')
                            .doc(user.uid)
                            .collection('historicos')
                            .doc(dataStr)
                            .set({'metaAtividade': metaAtividade}, SetOptions(merge: true));
                      } catch (e) {
                        debugPrint("Erro ao salvar histórico: $e");
                      }
                    }
                  }

                  if (isRedefining) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => MascotScreen(userName: profile.nome)),
                    );
                  }
                },
                icon: Icon(isRedefining ? Icons.check_circle_outline : Icons.celebration),
                label: Text(
                  isRedefining ? 'Concluir Alterações' : 'Conhecer meu Mascote',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFastingCard() {
    if (profile.horaInicioAlimentacao == null || profile.horaFimAlimentacao == null) {
      return const SizedBox.shrink();
    }

    double inicio = profile.horaInicioAlimentacao!.hour + profile.horaInicioAlimentacao!.minute / 60.0;
    double fim = profile.horaFimAlimentacao!.hour + profile.horaFimAlimentacao!.minute / 60.0;

    double janela = fim - inicio;
    if (janela < 0) janela += 24.0;

    int horasJejum = (24.0 - janela).round();
    int horasAlimentacao = janela.round();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.deepPurple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.nightlight_round, color: Colors.yellowAccent, size: 28),
              SizedBox(width: 8),
              Icon(Icons.wb_sunny, color: Colors.orangeAccent, size: 28),
              SizedBox(width: 12),
              Text('Seu Ciclo Diário', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Você faz $horasJejum horas de jejum e tem uma janela de alimentação de $horasAlimentacao horas.',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'O jejum (período noturno) ajuda na regeneração celular e na queima de gordura. O ciclo sincronizado regula seu relógio biológico e energia.',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLineChart() {
    int diasDesejados = profile.prazoMeta!.difference(DateTime.now()).inDays;
    String dataAlvo =
        '${profile.prazoMeta!.day.toString().padLeft(2, '0')}/${profile.prazoMeta!.month.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.indigo.shade100, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progresso da sua Meta',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text('Ritmo: ${profile.ritmoMeta}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
              )
            ],
          ),
          const SizedBox(height: 4),
          const Text('Gráfico projetando o seu caminho até o objetivo.', style: TextStyle(fontSize: 12, color: AppTheme.textGray)),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _LineChartPainter(value, profile.peso, profile.metaPeso),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimelineLabel('Hoje', '${profile.peso} kg'),
              _buildTimelineLabel('Estimativa', '$diasDesejados dias', color: AppTheme.primaryOrange),
              _buildTimelineLabel('Meta ($dataAlvo)', '${profile.metaPeso} kg', color: Colors.green),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildAnimatedBMIGauge(double imc) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.monitor_weight_outlined, color: AppTheme.textGray),
                SizedBox(width: 8),
                Text('Índice de Massa Corporal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textGray)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 120,
            width: 240,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: _BMIGaugePainter(value, imc),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(imc.toStringAsFixed(1),
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          Text(_feedbackIMC(imc),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: imc > 24.9 || imc < 18.5 ? Colors.redAccent : Colors.green)),
          const SizedBox(height: 16),
          Text(
            _descricaoIMC(imc),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textDark, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineLabel(String title, String subtitle, {Color color = AppTheme.textGray}) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _buildMacroItem(String nome, String valor, Color cor, String desc, IconData icone) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icone, color: cor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, color: cor, fontSize: 16)),
        Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
        Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.textGray), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildResultCard(String title, String value, IconData icon, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.primaryOrange, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textGray, fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textGray, height: 1.3)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final double progress;
  final double start;
  final double end;

  _LineChartPainter(this.progress, this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final paintLine = Paint()
      ..color = AppTheme.primaryOrange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final paintFill = Paint()
      ..shader = LinearGradient(
              colors: [AppTheme.primaryOrange.withOpacity(0.5), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final paintPoint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;

    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paintGrid);

    Path linePath = Path();
    Path fillPath = Path();

    double startY = start > end ? 20.0 : size.height - 20;
    double endY = start > end ? size.height - 20 : 20.0;

    linePath.moveTo(0, startY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, startY);

    double currentX = size.width * progress;
    double currentY = startY + (endY - startY) * progress;

    linePath.quadraticBezierTo(currentX * 0.5, startY, currentX, currentY);
    fillPath.quadraticBezierTo(currentX * 0.5, startY, currentX, currentY);

    fillPath.lineTo(currentX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(linePath, paintLine);

    if (progress > 0) {
      canvas.drawCircle(Offset(currentX, currentY), 6, paintPoint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BMIGaugePainter extends CustomPainter {
  final double progress;
  final double imc;

  _BMIGaugePainter(this.progress, this.imc);

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 15;
    Rect rect = Rect.fromCenter(center: Offset(size.width / 2, size.height), width: size.width, height: size.width);

    _drawArc(canvas, rect, pi, pi * 0.25, Colors.blue, strokeWidth);
    _drawArc(canvas, rect, pi * 1.25, pi * 0.25, Colors.green, strokeWidth);
    _drawArc(canvas, rect, pi * 1.5, pi * 0.2, Colors.orange, strokeWidth);
    _drawArc(canvas, rect, pi * 1.7, pi * 0.3, Colors.red, strokeWidth);

    double clampedImc = imc.clamp(15.0, 40.0);
    double targetAngle = pi + ((clampedImc - 15) / 25) * pi;
    double currentAngle = pi + (targetAngle - pi) * progress;

    final paintNeedle = Paint()
      ..color = AppTheme.textDark
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    double pointerLen = size.width / 2 - 10;
    Offset pointerEnd = Offset(
      size.width / 2 + pointerLen * cos(currentAngle),
      size.height + pointerLen * sin(currentAngle),
    );

    canvas.drawLine(Offset(size.width / 2, size.height), pointerEnd, paintNeedle);
    canvas.drawCircle(Offset(size.width / 2, size.height), 8, Paint()..color = AppTheme.textDark);
  }

  void _drawArc(Canvas canvas, Rect rect, double startAngle, double sweepAngle, Color color, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}