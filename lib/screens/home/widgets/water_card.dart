// card de registro de consumo de agua

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../theme/app_theme.dart';
import '../../../services/database_service.dart';

class WaterCard extends StatelessWidget {
  final Map<String, dynamic> perfil;
  final Map<String, dynamic>? historico;
  final DateTime? date;
  
  WaterCard({super.key, required this.perfil, required this.historico, this.date});

  final DatabaseService _db = DatabaseService();

  static void addCustomMl(BuildContext context, DatabaseService db, {DateTime? date}) {
    final TextEditingController mlController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Text('Consumo de água', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: mlController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.grey),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('ml', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, 
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                ),
                onPressed: () {
                  int? ml = int.tryParse(mlController.text);
                  if (ml != null && ml > 0) db.adicionarAgua(ml, data: date);
                  Navigator.pop(context);
                },
                child: const Text('Registrar água', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int consumido = historico?['agua_ml'] ?? 0;
    int metaAgua = (perfil['metaAgua'] != null && (perfil['metaAgua'] as num) > 0) 
        ? (perfil['metaAgua'] as num).toInt() 
        : 2500; 
    double progresso = (consumido / metaAgua).clamp(0.0, 1.0);
    int maxCopos = 4000 ~/ 250; 
    int coposDaMeta = (metaAgua / 250).ceil();
    if (coposDaMeta > maxCopos) coposDaMeta = maxCopos;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite, 
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Água', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 20, color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$consumido', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Text('ml', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60, height: 60,
                    child: CircularProgressIndicator(
                      value: progresso,
                      strokeWidth: 6,
                      backgroundColor: Colors.grey.shade100,
                      color: Colors.blueAccent,
                    ),
                  ),
                  InkWell(
                    onTap: () => addCustomMl(context, _db, date: date),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.black, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: List.generate(coposDaMeta, (index) {
              int limiteCopo = (index + 1) * 250;
              bool estaCheio = consumido >= limiteCopo;
              
              return GestureDetector(
                onTap: () {
                  if (index == 0 && consumido > 0) {
                    _db.adicionarAgua(-consumido, data: date); 
                  } else {
                    _db.adicionarAgua(250, data: date);
                  }
                },
                child: _WaveCopo(estaCheio: estaCheio, mostrarMais: (!estaCheio && consumido >= (index * 250) && consumido < limiteCopo)),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Meta: ${metaAgua.toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} ml", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Cada copo vale 250ml.", style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaveCopo extends StatefulWidget {
  final bool estaCheio;
  final bool mostrarMais;
  const _WaveCopo({required this.estaCheio, required this.mostrarMais});

  @override
  State<_WaveCopo> createState() => _WaveCopoState();
}

class _WaveCopoState extends State<_WaveCopo> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 55,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: widget.estaCheio ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              builder: (context, fillProgress, child) {
                return AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, _) => CustomPaint(
                    painter: _WavePainter(_waveController.value, fillProgress),
                    child: const SizedBox(height: 55, width: 38),
                  )
                );
              }
            ),
          ),
          if (widget.mostrarMais)
            const Center(child: Icon(Icons.add, size: 20, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double waveAnimation;
  final double fillProgress;
  _WavePainter(this.waveAnimation, this.fillProgress);

  @override
  void paint(Canvas canvas, Size size) {
    if (fillProgress == 0) return;
    final paint = Paint()..color = Colors.blue;
    final path = Path();
    
    double waterTop = size.height * (1 - fillProgress);
    
    path.moveTo(0, size.height);
    path.lineTo(0, waterTop);
    
    if (fillProgress < 1.0) {
      for (double i = 0; i <= size.width; i++) {
        path.lineTo(i, waterTop + math.sin((i / size.width * 2 * math.pi) + (waveAnimation * 2 * math.pi)) * 3);
      }
    } else {
      path.lineTo(size.width, waterTop);
    }
    
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}