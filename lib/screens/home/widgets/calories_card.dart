// Card de calorias, adicoiona, exclui, edita, modos de contabilizar, informaçoes nutrcionais como imc, tmb, get e macros...

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '/../theme/app_theme.dart';
import '/../services/database_service.dart';
import 'dart:math';
import '../../onboarding/onboarding_screen.dart';
import '../../meals/add_meal_screen.dart';

class CaloriesCard extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Map<String, dynamic>? historico;
  final DateTime? date;

  const CaloriesCard({
    super.key,
    required this.perfil,
    this.historico,
    this.date,
  });

  @override
  State<CaloriesCard> createState() => _CaloriesCardState();
}

class _CaloriesCardState extends State<CaloriesCard> {
  final DatabaseService _db = DatabaseService();
  
  String get _userId {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid;
    final perfilUid = widget.perfil['uid'];
    if (perfilUid != null && perfilUid.toString().trim().isNotEmpty) return perfilUid.toString();
    return '';
  }

  int _calcularMetaFibra(Map<String, dynamic> perfil) {
    final String sexo = (perfil['sexo'] ?? perfil['genero'] ?? 'M').toString().toUpperCase();
    final int idade = (perfil['idade'] as num?)?.toInt() ?? 25;
    
    bool isFeminino = sexo == 'F' || sexo == 'FEMININO';
    
    if (isFeminino) {
      if (idade <= 8) return 19;
      if (idade <= 13) return 22;
      if (idade <= 18) return 25;
      if (idade <= 50) return 25;
      return 21; 
    } else {
      if (idade <= 8) return 19;
      if (idade <= 13) return 25;
      if (idade <= 18) return 31;
      if (idade <= 50) return 38;
      return 30; 
    }
  }

  Map<String, String> _getTipoRefeicaoEHora(String? dataHoraStr) {
    if (dataHoraStr == null || dataHoraStr.isEmpty) {
      return {'hora': '--:--', 'tipo': 'Refeição', 'textoCompleto': 'Adicionado no dia'};
    }
    try {
      DateTime dt = DateTime.parse(dataHoraStr);
      String hora = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      
      int h = dt.hour;
      String tipo;
      if (h >= 5 && h < 11) {
        tipo = 'Café da manhã';
      } else if (h >= 11 && h < 15) {
        tipo = 'Almoço';
      } else if (h >= 15 && h < 18) {
        tipo = 'Lanche';
      } else if (h >= 18 && h < 22) {
        tipo = 'Jantar';
      } else {
        tipo = 'Ceia';
      }
      return {
        'hora': hora,
        'tipo': tipo,
        'textoCompleto': 'Adicionado às $hora no $tipo',
      };
    } catch (e) {
      return {'hora': '--:--', 'tipo': 'Refeição', 'textoCompleto': 'Adicionado no dia'};
    }
  }

  Future<void> _ajustarMacrosHistoricoDelta({
    required num calorias,
    required num proteinas,
    required num carboidratos,
    required num gorduras,
    required num fibras,
  }) async {
    if (_userId.isEmpty) return;
    
    final targetDate = widget.date ?? DateTime.now();
    final targetDateStr = targetDate.toIso8601String().split('T')[0];

    try {
      final docRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_userId)
          .collection('historico_diario')
          .doc(targetDateStr);

      await docRef.set({
        'data_registro': targetDateStr,
        'calorias_consumidas': FieldValue.increment(calorias),
        'proteina_consumida': FieldValue.increment(proteinas),
        'carbo_consumida': FieldValue.increment(carboidratos),
        'gordura_consumida': FieldValue.increment(gorduras),
        'fibra_consumida': FieldValue.increment(fibras),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Erro ao atualizar histórico: $e");
    }
  }

  void _editarItemEspecificoModal(BuildContext context, String docId, Map<String, dynamic> refeicao, int itemIndex) {
    List<Map<String, dynamic>> itens = List<Map<String, dynamic>>.from(
      (refeicao['itens'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))
    );

    if (itemIndex < 0 || itemIndex >= itens.length) return;

    var item = itens[itemIndex];
    bool isGramaModal = item['isGrama'] ?? false;
    double quantidadeModal = ((item['quantidade'] ?? 1) as num).toDouble();

    num kcalBase = item['calorias_base'] ?? item['calorias'] ?? 0;
    num carbBase = item['carboidratos_base'] ?? item['carboidratos'] ?? 0;
    num fatBase = item['gorduras_base'] ?? item['gorduras'] ?? 0;
    num protBase = item['proteinas_base'] ?? item['proteinas'] ?? 0;
    num fibBase = item['fibras_base'] ?? item['fibras'] ?? 0;

    num kcalAntigo = (item['calorias'] as num?) ?? 0;
    num protAntigo = (item['proteinas'] as num?) ?? 0;
    num carbAntigo = (item['carboidratos'] as num?) ?? 0;
    num fatAntigo = (item['gorduras'] as num?) ?? 0;
    num fibAntigo = (item['fibras'] as num?) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateItem) {
            double multiplicador = isGramaModal ? (quantidadeModal / 100.0) : quantidadeModal;
            if (multiplicador <= 0) multiplicador = 0.1;

            return Padding(
              padding: EdgeInsets.only(
                left: 24.0, right: 24.0, top: 20.0, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end, 
                    children: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]
                  ),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: const Color(0xFFF3F4F6),
                    backgroundImage: item['imagem_path'] != null && File(item['imagem_path']).existsSync()
                        ? FileImage(File(item['imagem_path'])) as ImageProvider
                        : const NetworkImage('https://cdn-icons-png.flaticon.com/512/706/706164.png'),
                  ),
                  const SizedBox(height: 12),
                  Text(item['nome'] ?? 'Item', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      Text('${(kcalBase * multiplicador).toStringAsFixed(0)} kcal', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      Text('C ${(carbBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      Text('G ${(fatBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      Text('P ${(protBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('Fi ${(fibBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateItem(() { isGramaModal = false; quantidadeModal = 1.0; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: !isGramaModal ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                              child: Center(child: Text('Unidade', style: TextStyle(fontWeight: FontWeight.bold, color: !isGramaModal ? Colors.black : Colors.grey))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateItem(() { isGramaModal = true; quantidadeModal = 100.0; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: isGramaModal ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30)),
                              child: Center(child: Text('Gramas', style: TextStyle(fontWeight: FontWeight.bold, color: isGramaModal ? Colors.black : Colors.grey))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.remove), onPressed: () => setStateItem(() { if (quantidadeModal > 1) quantidadeModal -= isGramaModal ? 10 : 1; })),
                      Text(isGramaModal ? '${quantidadeModal.toStringAsFixed(0)} g' : '${quantidadeModal.toStringAsFixed(0)} un', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.add), onPressed: () => setStateItem(() { quantidadeModal += isGramaModal ? 10 : 1; })),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: () async {
                      if (_userId.isEmpty) return;

                      num novoKcalItem = (kcalBase * multiplicador).round();
                      num novoProtItem = (protBase * multiplicador).toDouble();
                      num novoCarbItem = (carbBase * multiplicador).toDouble();
                      num novoFatItem = (fatBase * multiplicador).toDouble();
                      num novoFibItem = (fibBase * multiplicador).toDouble();

                      item['isGrama'] = isGramaModal;
                      item['quantidade'] = quantidadeModal;
                      item['calorias'] = novoKcalItem;
                      item['carboidratos'] = novoCarbItem;
                      item['gorduras'] = novoFatItem;
                      item['proteinas'] = novoProtItem;
                      item['fibras'] = novoFibItem;

                      itens[itemIndex] = item;

                      num novoTotalKcal = itens.fold(0, (s, i) => s + ((i['calorias'] as num?) ?? 0));
                      num novoTotalProt = itens.fold(0, (s, i) => s + ((i['proteinas'] as num?) ?? 0));
                      num novoTotalCarb = itens.fold(0, (s, i) => s + ((i['carboidratos'] as num?) ?? 0));
                      num novoTotalGord = itens.fold(0, (s, i) => s + ((i['gorduras'] as num?) ?? 0));
                      num novoTotalFibra = itens.fold(0, (s, i) => s + ((i['fibras'] as num?) ?? 0));

                      num diffCalorias = novoKcalItem - kcalAntigo;
                      num diffProteinas = novoProtItem - protAntigo;
                      num diffCarboidratos = novoCarbItem - carbAntigo;
                      num diffGorduras = novoFatItem - fatAntigo;
                      num diffFibras = novoFibItem - fibAntigo;

                      await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('refeicoes').doc(docId).update({
                        'calorias': novoTotalKcal,
                        'proteinas': novoTotalProt,
                        'carboidratos': novoTotalCarb,
                        'gorduras': novoTotalGord,
                        'fibras': novoTotalFibra,
                        'itens': itens,
                      });

                      await _ajustarMacrosHistoricoDelta(
                        calorias: diffCalorias,
                        proteinas: diffProteinas,
                        carboidratos: diffCarboidratos,
                        gorduras: diffGorduras,
                        fibras: diffFibras,
                      );

                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Confirmar Alteração', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _excluirItemEspecifico(String docId, Map<String, dynamic> refeicao, int itemIndex) async {
    if (_userId.isEmpty) return;
    List<Map<String, dynamic>> itens = List<Map<String, dynamic>>.from(
      (refeicao['itens'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))
    );
    if (itemIndex < 0 || itemIndex >= itens.length) return;

    var itemRemovido = itens[itemIndex];
    num itemKcal = (itemRemovido['calorias'] as num?) ?? 0;
    num itemProt = (itemRemovido['proteinas'] as num?) ?? 0;
    num itemCarb = (itemRemovido['carboidratos'] as num?) ?? 0;
    num itemGord = (itemRemovido['gorduras'] as num?) ?? 0;
    num itemFib = (itemRemovido['fibras'] as num?) ?? 0;

    if (itens.length <= 1) {
      await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('refeicoes').doc(docId).delete();
    } else {
      itens.removeAt(itemIndex);
      num novoKcal = itens.fold(0, (s, i) => s + ((i['calorias'] as num?) ?? 0));
      num novoProt = itens.fold(0, (s, i) => s + ((i['proteinas'] as num?) ?? 0));
      num novoCarb = itens.fold(0, (s, i) => s + ((i['carboidratos'] as num?) ?? 0));
      num novoGord = itens.fold(0, (s, i) => s + ((i['gorduras'] as num?) ?? 0));
      num novoFib = itens.fold(0, (s, i) => s + ((i['fibras'] as num?) ?? 0));

      await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('refeicoes').doc(docId).update({
        'calorias': novoKcal,
        'proteinas': novoProt,
        'carboidratos': novoCarb,
        'gorduras': novoGord,
        'fibras': novoFib,
        'itens': itens,
      });
    }

    await _ajustarMacrosHistoricoDelta(
      calorias: -itemKcal,
      proteinas: -itemProt,
      carboidratos: -itemCarb,
      gorduras: -itemGord,
      fibras: -itemFib,
    );
  }

  void _editarItemUnicoDireto(BuildContext context, String docId, Map<String, dynamic> refeicao) {
    _editarItemEspecificoModal(context, docId, refeicao, 0);
  }

  // ignore: unused_element
  void _mostrarModalEdicaoRefeicaoHistorico(BuildContext context, String docId, Map<String, dynamic> refeicao) {
    List<Map<String, dynamic>> itens = List<Map<String, dynamic>>.from(
      (refeicao['itens'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))
    );

    if (itens.length == 1) {
      _editarItemUnicoDireto(context, docId, refeicao);
      return;
    }

    num caloriasAntigas = (refeicao['calorias'] as num?) ?? 0;
    num proteinasAntigas = (refeicao['proteinas'] as num?) ?? 0;
    num carboidratosAntigos = (refeicao['carboidratos'] as num?) ?? 0;
    num gordurasAntigas = (refeicao['gorduras'] as num?) ?? 0;
    num fibrasAntigas = (refeicao['fibras'] as num?) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            int totalKcal = itens.fold(0, (s, i) => s + ((i['calorias'] as num?)?.toInt() ?? 0));
            int totalProt = itens.fold(0, (s, i) => s + ((i['proteinas'] as num?)?.toInt() ?? 0));
            int totalCarb = itens.fold(0, (s, i) => s + ((i['carboidratos'] as num?)?.toInt() ?? 0));
            int totalGord = itens.fold(0, (s, i) => s + ((i['gorduras'] as num?)?.toInt() ?? 0));
            int totalFibra = itens.fold(0, (s, i) => s + ((i['fibras'] as num?)?.toInt() ?? 0));

            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(refeicao['nome'] ?? 'Editar Refeição', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Total: $totalKcal kcal | P: ${totalProt}g • C: ${totalCarb}g • G: ${totalGord}g • F: ${totalFibra}g',
                    style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: itens.length,
                      itemBuilder: (context, idx) {
                        var it = itens[idx];
                        return ListTile(
                          title: Text(it['nome'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${it['calorias']} kcal • P:${it['proteinas']}g C:${it['carboidratos']}g G:${it['gorduras']}g F:${it['fibras']}g'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () {
                                Navigator.pop(context);
                                _editarItemEspecificoModal(context, docId, refeicao, idx);
                              }),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), onPressed: () async {
                                Navigator.pop(context);
                                await _excluirItemEspecifico(docId, refeicao, idx);
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () async {
                      if (_userId.isEmpty) return;
                      
                      num diffCalorias = totalKcal - caloriasAntigas;
                      num diffProteinas = totalProt - proteinasAntigas;
                      num diffCarboidratos = totalCarb - carboidratosAntigos;
                      num diffGorduras = totalGord - gordurasAntigas;
                      num diffFibras = totalFibra - fibrasAntigas;

                      await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('refeicoes').doc(docId).update({
                        'calorias': totalKcal,
                        'proteinas': totalProt,
                        'carboidratos': totalCarb,
                        'gorduras': totalGord,
                        'fibras': totalFibra,
                        'itens': itens,
                      });

                      await _ajustarMacrosHistoricoDelta(
                        calorias: diffCalorias,
                        proteinas: diffProteinas,
                        carboidratos: diffCarboidratos,
                        gorduras: diffGorduras,
                        fibras: diffFibras,
                      );

                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('Salvar Refeição', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _zerarRefeicoes(List<QueryDocumentSnapshot> docs) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Zerar Refeições?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Isso excluirá todas as refeições do dia e zerará sua contagem. Tem certeza?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              if (_userId.isEmpty) return;
              Navigator.pop(context);
              for (var doc in docs) {
                var refeicao = doc.data() as Map<String, dynamic>;
                await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('refeicoes').doc(doc.id).delete();
                await _ajustarMacrosHistoricoDelta(
                  calorias: -((refeicao['calorias'] as num?) ?? 0),
                  proteinas: -((refeicao['proteinas'] as num?) ?? 0),
                  carboidratos: -((refeicao['carboidratos'] as num?) ?? 0),
                  gorduras: -((refeicao['gorduras'] as num?) ?? 0),
                  fibras: -((refeicao['fibras'] as num?) ?? 0),
                );
              }
            },
            child: const Text('Sim, Zerar', style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  void _mostrarRefeicoesDoDia(BuildContext context) async {
    final targetDate = widget.date ?? DateTime.now();
    final targetDateStr = targetDate.toIso8601String().split('T')[0];
    String searchQuery = '';
    bool exibirFibras = widget.perfil['exibirFibras'] ?? true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey.shade50,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 20
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Refeições do Dia', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Pesquisar refeição do dia...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) {
                      setStateModal(() {
                        searchQuery = val.toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _userId.isEmpty ? null : FirebaseFirestore.instance
                        .collection('usuarios')
                        .doc(_userId)
                        .collection('refeicoes')
                        .where('dia_ref', isEqualTo: targetDateStr)
                        .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                        }
                        
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Nenhuma refeição registrada neste dia.', style: TextStyle(color: Colors.grey))));
                        }

                        var allDocs = snapshot.data!.docs;
                        
                        var docs = allDocs.where((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          String refName = (data['nome'] ?? '').toLowerCase();
                          List<dynamic> itens = data['itens'] ?? [];
                          bool itemMatches = itens.any((item) => (item['nome'] ?? '').toLowerCase().contains(searchQuery));
                          return refName.contains(searchQuery) || itemMatches;
                        }).toList();

                        if (docs.isEmpty) {
                          return const Center(child: Text('Nenhuma refeição encontrada.', style: TextStyle(color: Colors.grey)));
                        }

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _zerarRefeicoes(allDocs),
                                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 20),
                                  label: const Text('Zerar Dia', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: docs.length,
                                separatorBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(color: Colors.grey.shade300, height: 1, thickness: 1.2),
                                ),
                                itemBuilder: (context, index) {
                                  var refeicao = docs[index].data() as Map<String, dynamic>;
                                  var docId = docs[index].id;
                                  List<Map<String, dynamic>> itens = List<Map<String, dynamic>>.from(
                                    (refeicao['itens'] as List? ?? []).map((x) => Map<String, dynamic>.from(x))
                                  );

                                  Map<String, String> infoHora = _getTipoRefeicaoEHora(refeicao['dataHora']);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Minha refeição',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 18,
                                                color: Colors.black,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              infoHora['textoCompleto']!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ...List.generate(itens.length, (itemIdx) {
                                        var item = itens[itemIdx];
                                        String? imagemPath = item['imagem_path'] ?? refeicao['imagem_path'];

                                        num prot = item['proteinas'] ?? 0;
                                        num carb = item['carboidratos'] ?? 0;
                                        num gord = item['gorduras'] ?? 0;
                                        num fibra = item['fibras'] ?? 0;
                                        num cal = item['calorias'] ?? 0;

                                        Widget iconeOuFoto;
                                        if (imagemPath != null && File(imagemPath).existsSync()) {
                                          iconeOuFoto = ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.file(
                                              File(imagemPath),
                                              width: 48,
                                              height: 48,
                                              fit: BoxFit.cover,
                                            ),
                                          );
                                        } else {
                                          iconeOuFoto = Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                                            child: const Icon(Icons.restaurant, color: Colors.orange, size: 24),
                                          );
                                        }

                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))
                                            ],
                                            border: Border.all(color: Colors.grey.shade200)
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              iconeOuFoto,
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      item['nome'] ?? 'Alimento',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${cal} kcal ${item['quantidade'] != null ? '• ${(item['quantidade'] as num).toStringAsFixed(0)}${item['isGrama'] == true ? 'g' : ' un'}' : ''}',
                                                      style: const TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      children: [
                                                        _buildMacroChip('P: ${prot}g', Colors.green, Icons.fitness_center),
                                                        _buildMacroChip('C: ${carb}g', Colors.orange, Icons.grain),
                                                        _buildMacroChip('G: ${gord}g', Colors.amber, Icons.opacity),
                                                        if (exibirFibras)
                                                          _buildMacroChip('F: ${fibra}g', Colors.brown, Icons.grass),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                                                    onPressed: () {
                                                      _editarItemEspecificoModal(context, docId, refeicao, itemIdx);
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                    onPressed: () async {
                                                      await _excluirItemEspecifico(docId, refeicao, itemIdx);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildMacroChip(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _mostrarMenuModoCalorias(BuildContext context, String modoAtualFallback) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _userId.isEmpty ? null : FirebaseFirestore.instance.collection('usuarios').doc(_userId).snapshots(),
          builder: (context, userSnap) {
            Map<String, dynamic> perfilModal = widget.perfil;
            if (userSnap.hasData && userSnap.data!.exists) {
              perfilModal = userSnap.data!.data() as Map<String, dynamic>;
            }
            
            String modoRaw = (perfilModal['modoCalorias'] ?? 'Inteligente').toString().trim();
            bool isInteligente = modoRaw == 'Inteligente' || modoRaw == 'Modo Inteligente' || modoRaw == 'Fixo';
            String modoAtual = isInteligente ? 'Inteligente' : 'Todas as calorias';
            bool exibirFibras = perfilModal['exibirFibras'] ?? true;

            return StatefulBuilder(
              builder: (context, setStateMenu) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                        ),
                        const SizedBox(height: 24),
                        const Text('Opções do Plano', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 24, color: AppTheme.textDark)),
                        const SizedBox(height: 8),
                        const Text('Escolha como deseja que o app calcule sua meta diária de calorias.', style: TextStyle(fontSize: 14, color: AppTheme.textGray)),
                        const SizedBox(height: 24),
                        _buildOpcaoModo(
                          context: context,
                          titulo: 'Modo Inteligente',
                          descricao: 'Só aumenta sua meta diária de comida se o seu treino queimar mais calorias do que a sua rotina base já previa. Evita a contagem dupla de calorias.',
                          icone: Icons.auto_awesome,
                          cor: const Color.fromARGB(255, 227, 109, 5),
                          valor: 'Inteligente',
                          modoAtual: modoAtual,
                        ),
                        const SizedBox(height: 16),
                        _buildOpcaoModo(
                          context: context,
                          titulo: 'Modo Todas as calorias',
                          descricao: 'Soma absolutamente toda caloria gasta no exercício à sua meta, permitindo que você "coma de volta" tudo o que queimou.',
                          icone: Icons.track_changes,
                          cor: const Color.fromARGB(255, 3, 13, 156),
                          valor: 'Todas as calorias', 
                          modoAtual: modoAtual,
                        ),
                        const SizedBox(height: 24),
                        Divider(color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('Detalhes e Ajustes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        const SizedBox(height: 16),
                        _buildAcaoExtra(
                          context: context,
                          titulo: exibirFibras ? 'Ocultar Fibras do Card' : 'Exibir Fibras no Card',
                          descricao: 'Alterna a exibição do consumo de fibras no quadro principal.',
                          icone: Icons.grass,
                          cor: Colors.green,
                          onTap: () async {
                            Navigator.pop(context);
                            bool novoValor = !exibirFibras;
                            setState(() {
                              widget.perfil['exibirFibras'] = novoValor;
                            });
                            await _db.atualizarPerfil({'exibirFibras': novoValor});
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAcaoExtra(
                          context: context,
                          titulo: 'Ver meu TMB, GET e IMC',
                          descricao: 'Análise detalhada do seu metabolismo e peso.',
                          icone: Icons.monitor_heart,
                          cor: Colors.pinkAccent,
                          onTap: () {
                            Navigator.pop(context);
                            _mostrarTMBeGET(context);
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildAcaoExtra(
                          context: context,
                          titulo: 'Redefinir Plano Alimentar',
                          descricao: 'Refazer questionário para recalcular metas.',
                          icone: Icons.restart_alt,
                          cor: Colors.redAccent,
                          onTap: () {
                            Navigator.pop(context);
                            _confirmarRedefinicao(context);
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              }
            );
          }
        );
      },
    );
  }

  Widget _buildAcaoExtra({required BuildContext context, required String titulo, required String descricao, required IconData icone, required Color cor, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icone, color: cor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(descricao, style: const TextStyle(fontSize: 12, color: AppTheme.textGray)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _mostrarTMBeGET(BuildContext context) {
    final double peso = (widget.perfil['peso'] as num?)?.toDouble() ?? 0.0;
    final double altura = (widget.perfil['altura'] as num?)?.toDouble() ?? 0.0;
    final int idade = (widget.perfil['idade'] as num?)?.toInt() ?? 25;
    final String sexo = (widget.perfil['sexo'] ?? widget.perfil['genero'] ?? 'M').toString().toUpperCase();
    final double fatorAtividade = (widget.perfil['fatorAtividade'] as num?)?.toDouble() ?? 1.2;
    final int metaCalorias = (widget.perfil['metaCalorias'] as num?)?.toInt() ?? 0;

    double imc = 0.0;
    if (altura > 0 && peso > 0) {
      double alturaMetros = altura / 100;
      imc = peso / (alturaMetros * alturaMetros);
    }

    double tmbCalc = (10 * peso) + (6.25 * altura) - (5 * idade);
    tmbCalc += (sexo == 'F' || sexo == 'FEMININO') ? -161 : 5;
    int tmb = tmbCalc > 0 ? tmbCalc.round() : ((widget.perfil['tmb'] as num?)?.toInt() ?? 0);
    
    int get = (tmb * fatorAtividade).round();
    if (get <= 0) get = (widget.perfil['get'] as num?)?.toInt() ?? 0;

    int diferenca = get - metaCalorias;
    String tituloDieta = diferenca > 0 ? 'Déficit Calórico' : (diferenca < 0 ? 'Superávit Calórico' : 'Manutenção');
    String descDieta = diferenca > 0
        ? 'Você está consumindo ${diferenca.abs()} kcal a menos que seu gasto diário. Ideal para perda de gordura.'
        : (diferenca < 0
            ? 'Você está consumindo ${diferenca.abs()} kcal a mais que seu gasto diário. Ideal para ganho de massa.'
            : 'Você está consumindo exatamente o que gasta. Ideal para manter o peso atual.');

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 15))],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.analytics_outlined, size: 36, color: Colors.blueAccent),
                        ),
                        const SizedBox(height: 12),
                        const Text('Análise do Corpo', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 26, color: AppTheme.textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildMetricCard(icon: Icons.monitor_weight_rounded, color: Colors.blueAccent, title: 'IMC Atual: ${imc.toStringAsFixed(1)}', subtitle: 'A faixa esperada e saudável é entre 18.5 e 24.9.'),
                  const SizedBox(height: 16),
                  _buildMetricCard(icon: Icons.favorite_rounded, color: Colors.pinkAccent, title: 'TMB: $tmb kcal', subtitle: 'Energia que seu corpo gasta em repouso absoluto.'),
                  const SizedBox(height: 16),
                  _buildMetricCard(icon: Icons.directions_run_rounded, color: Colors.orange, title: 'GET: $get kcal', subtitle: 'Gasto energético total considerando suas atividades.'),
                  const SizedBox(height: 16),
                  _buildMetricCard(icon: diferenca >= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: diferenca > 0 ? Colors.green : (diferenca < 0 ? Colors.redAccent : Colors.grey), title: '$tituloDieta: ${diferenca.abs()} kcal', subtitle: descDieta),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                        elevation: 4,
                        shadowColor: AppTheme.primaryOrange.withOpacity(0.5)
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Incrível!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12), 
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ), 
            child: Icon(icon, color: color, size: 30)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.grey.shade900)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _confirmarRedefinicao(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Redefinir Plano?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Você será levado ao questionário inicial para atualizar seu peso e recalcular tudo.', style: TextStyle(fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingScreen(isRedefining: true)));
              },
              child: const Text('Refazer Plano', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOpcaoModo({
    required BuildContext context, 
    required String titulo, 
    required String descricao, 
    required IconData icone, 
    required Color cor, 
    required String valor, 
    required String modoAtual
  }) {
    bool isSelected = (modoAtual == valor);
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        setState(() {
          widget.perfil['modoCalorias'] = valor;
        });
        await _db.atualizarPerfil({'modoCalorias': valor});
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? cor : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? cor : Colors.grey.shade300, width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: cor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12), 
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : cor.withOpacity(0.1), 
                shape: BoxShape.circle
              ), 
              child: Icon(icone, color: isSelected ? Colors.white : cor, size: 28)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? Colors.white : AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(descricao, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : AppTheme.textGray)),
                ],
              ),
            ),
            if (isSelected) const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.check_circle, color: Colors.white, size: 28)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textGray, fontWeight: FontWeight.w500)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMacroProgress(String titulo, int consumido, int meta, Color cor, IconData icone) {
    double percent = meta > 0 ? consumido / meta : 0.0;
    if (percent > 1.0) percent = 1.0;
    if (percent < 0.0) percent = 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Icon(icone, size: 14, color: cor),
                  const SizedBox(width: 4),
                  Flexible(child: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textDark))),
                ],
              ),
            ),
            const SizedBox(width: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text('$consumido / ${meta}g', style: const TextStyle(fontSize: 11, color: AppTheme.textGray, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: percent),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(value: value, backgroundColor: cor.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(cor), minHeight: 8);
            },
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userId.isEmpty ? null : FirebaseFirestore.instance.collection('usuarios').doc(_userId).snapshots(),
      builder: (context, userSnapshot) {
        Map<String, dynamic> perfilAtualizado = widget.perfil;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          perfilAtualizado = userSnapshot.data!.data() as Map<String, dynamic>;
        }

        String modoCaloriasRaw = (perfilAtualizado['modoCalorias'] ?? 'Inteligente').toString().trim();
        bool isModoInteligente = modoCaloriasRaw == 'Inteligente' || modoCaloriasRaw == 'Modo Inteligente' || modoCaloriasRaw == 'Fixo';
        String modoCalorias = isModoInteligente ? 'Inteligente' : 'Todas as calorias';

        bool exibirFibras = perfilAtualizado['exibirFibras'] ?? true;

        int metaCalorias = (perfilAtualizado['metaCalorias'] as num?)?.toInt() ?? 2000;
        
        int protMeta = (perfilAtualizado['metaProteina'] as num?)?.toInt() ?? 100;
        int carboMeta = (perfilAtualizado['metaCarbo'] as num?)?.toInt() ?? 200;
        int gordMeta = (perfilAtualizado['metaGordura'] as num?)?.toInt() ?? 60;
        
        int fibraMeta = _calcularMetaFibra(perfilAtualizado);

        final targetDate = widget.date ?? DateTime.now();
        final targetDateStr = targetDate.toIso8601String().split('T')[0];

        String nomePlanoExibicao = isModoInteligente ? 'Modo Inteligente' : 'Todas as calorias';

        return StreamBuilder<DocumentSnapshot>(
          stream: _userId.isEmpty ? null : FirebaseFirestore.instance
              .collection('usuarios')
              .doc(_userId)
              .collection('historico_diario')
              .doc(targetDateStr)
              .snapshots(),
          builder: (context, snapshot) {
            
            Map<String, dynamic>? histData = widget.historico; 
            if (snapshot.hasData && snapshot.data!.exists) {
              histData = snapshot.data!.data() as Map<String, dynamic>;
            }

            int caloriasConsumidas = (histData?['calorias_consumidas'] as num?)?.toInt() ?? 0;
            dynamic gastasRaw = widget.historico?['calorias_gastas'] ?? 
                        widget.historico?['caloriasGastas'] ?? 
                        histData?['calorias_gastas'] ?? 0;
                        
            int caloriasGastas = (gastasRaw is num) ? gastasRaw.toInt() : (int.tryParse(gastasRaw.toString()) ?? 0);

            int protConsumida = (histData?['proteina_consumida'] as num?)?.toInt() ?? 0;
            int carboConsumido = (histData?['carbo_consumida'] as num?)?.toInt() ?? 0;
            int gordConsumida = (histData?['gordura_consumida'] as num?)?.toInt() ?? 0;
            int fibraConsumida = (histData?['fibra_consumida'] as num?)?.toInt() ?? 0;

            int metaAtual;
            int caloriasDisponiveis;

            if (isModoInteligente) {
              double peso = (perfilAtualizado['peso'] as num?)?.toDouble() ?? 0.0;
              double altura = (perfilAtualizado['altura'] as num?)?.toDouble() ?? 0.0;
              int idade = (perfilAtualizado['idade'] as num?)?.toInt() ?? 25;
              String sexo = (perfilAtualizado['sexo'] ?? perfilAtualizado['genero'] ?? 'M').toString().toUpperCase();
              double fatorAtividade = (perfilAtualizado['fatorAtividade'] as num?)?.toDouble() ?? 1.2;

              double tmbCalc = (10 * peso) + (6.25 * altura) - (5 * idade);
              tmbCalc += (sexo == 'F' || sexo == 'FEMININO') ? -161 : 5;
              int tmb = tmbCalc > 0 ? tmbCalc.round() : ((perfilAtualizado['tmb'] as num?)?.toInt() ?? 0);

              int gastoBase = (fatorAtividade > 1.2 && tmb > 0) ? ((fatorAtividade - 1.2) * tmb).round() : 0;
              int excedenteTreino = caloriasGastas > gastoBase ? 0 : 0;

              metaAtual = metaCalorias + excedenteTreino;
              caloriasDisponiveis = metaAtual - caloriasConsumidas;
            } else {
              metaAtual = metaCalorias + caloriasGastas;
              caloriasDisponiveis = metaAtual - caloriasConsumidas;
            }

            double progressoCirculo = metaAtual > 0 ? (caloriasConsumidas / metaAtual) : 0.0;
            if (progressoCirculo > 1.0) progressoCirculo = 1.0;
            if (progressoCirculo < 0.0) progressoCirculo = 0.0;

            bool excedeu = caloriasDisponiveis < 0;
            Color corCirculo = excedeu ? Colors.redAccent : AppTheme.primaryOrange;
            String labelRestante = excedeu ? 'excedidas' : 'restantes';

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppTheme.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.local_fire_department, color: AppTheme.primaryOrange, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text('Calorias', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const AddMealScreen()));
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryOrange,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(icon: const Icon(Icons.more_vert, color: Colors.grey, size: 28), onPressed: () => _mostrarMenuModoCalorias(context, modoCalorias)),
                        ],
                      )
                    ],
                  ),

                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: AppTheme.primaryOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
                              children: [
                                const TextSpan(text: 'Você está usando o plano: '),
                                TextSpan(
                                  text: nomePlanoExibicao,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryOrange),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progressoCirculo),
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return CustomPaint(
                            painter: _CalorieRingPainter(progress: value, color: corCirculo, backgroundColor: Colors.grey.shade100),
                            child: SizedBox(
                              width: 140,
                              height: 140,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(caloriasDisponiveis.abs().toString(), style: TextStyle(fontSize: 28, fontFamily: 'LilitaOne', color: corCirculo)),
                                  Text(labelRestante, style: const TextStyle(fontSize: 13, color: AppTheme.textGray, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStatRow(Icons.flag, 'Meta Diária', metaCalorias.toString(), Colors.blue),
                            const SizedBox(height: 14),
                            _buildStatRow(Icons.restaurant, 'Consumidas', caloriasConsumidas.toString(), AppTheme.primaryOrange),
                            const SizedBox(height: 14),
                            _buildStatRow(Icons.directions_run, 'Exercícios', caloriasGastas.toString(), Colors.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),

                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildMacroProgress('Carbos', carboConsumido, carboMeta, Colors.orange, Icons.grain)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildMacroProgress('Proteína', protConsumida, protMeta, Colors.redAccent, Icons.fitness_center)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildMacroProgress('Gordura', gordConsumida, gordMeta, Colors.amber, Icons.opacity)),
                          if (exibirFibras) ...[
                            const SizedBox(width: 16),
                            Expanded(child: _buildMacroProgress('Fibras', fibraConsumida, fibraMeta, Colors.green, Icons.grass)),
                          ],
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _mostrarRefeicoesDoDia(context),
                      icon: const Icon(Icons.history, color: AppTheme.primaryOrange),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        side: const BorderSide(color: AppTheme.primaryOrange, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      label: const Text('Acompanhar refeições', style: TextStyle(color: AppTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CalorieRingPainter({required this.progress, required this.color, required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 14.0;
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = (size.width - strokeWidth) / 2;

    Paint bgPaint = Paint()..color = backgroundColor..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    Paint progressPaint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    double sweepAngle = 2 * pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

