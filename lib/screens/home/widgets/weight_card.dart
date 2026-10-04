// card de peso, atualiza com meta de peso.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../theme/app_theme.dart';
import '../../../services/database_service.dart';

class WeightCard extends StatelessWidget {
  final Map<String, dynamic> perfil;
  final Map<String, dynamic>? historico; 
  final DateTime? date;

  WeightCard({super.key, required this.perfil, this.historico, this.date});

  final DatabaseService _db = DatabaseService();

  static void updateWeight(BuildContext context, double pesoAtual, DatabaseService db, {DateTime? date}) {
    int currentInt = pesoAtual.floor();
    int currentDec = ((pesoAtual - currentInt) * 10).round();

    int selectedInt = currentInt;
    int selectedDec = currentDec;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 24),
            const Text('Seu peso atual', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 70,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: currentInt),
                      itemExtent: 50,
                      onSelectedItemChanged: (int index) => selectedInt = index,
                      children: List.generate(250, (index) => Center(
                        child: Text(index.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      )),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('.', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(
                    width: 50,
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: currentDec),
                      itemExtent: 50,
                      onSelectedItemChanged: (int index) => selectedDec = index,
                      children: List.generate(10, (index) => Center(
                        child: Text(index.toString(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('kg', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    double nPeso = double.parse("$selectedInt.$selectedDec");
                    db.atualizarPeso(nPeso, data: date);
                    Navigator.pop(context);
                  },
                  child: const Text('Registrar peso', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    double pesoAtual;
    if (historico != null && historico!.containsKey('peso') && historico!['peso'] != null) {
      pesoAtual = (historico!['peso'] as num).toDouble();
    } else {
      pesoAtual = (perfil['peso'] as num? ?? 0).toDouble();
    }

    double meta = (perfil['metaPeso'] as num? ?? 0).toDouble();
    double diff = pesoAtual - meta;
    String status = diff == 0 ? "Meta alcançada!" : (diff > 0 ? "Faltam ${diff.toStringAsFixed(1)} kg" : "Faltam ${(diff * -1).toStringAsFixed(1)} kg para ganho");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.pureWhite, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seu Peso', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 20, color: AppTheme.textDark)),
              InkWell(
                onTap: () => updateWeight(context, pesoAtual, _db, date: date),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.black, size: 28),
                ),
              ),
            ],
          ),
          Text('${pesoAtual.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(status, style: TextStyle(color: diff == 0 ? Colors.green : AppTheme.textGray)),
        ],
      ),
    );
  }
}