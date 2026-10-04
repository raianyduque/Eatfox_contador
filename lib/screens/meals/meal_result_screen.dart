// refeicoes adicionadas, editar, excluir, definir porcoes e salvar

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
// ignore: unused_import
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';

class MealResultScreen extends StatefulWidget {
  final Map<String, dynamic> dadosIA;
  final List<Map<String, dynamic>> refeicaoAtual;
  
  const MealResultScreen({
    super.key, 
    required this.dadosIA, 
    required this.refeicaoAtual
  });

  @override
  State<MealResultScreen> createState() => _MealResultScreenState();
}

class _MealResultScreenState extends State<MealResultScreen> {
  late List<Map<String, dynamic>> _itens;
  
  int get _totalKcal => _itens.fold(0, (s, i) => s + ((i['calorias'] as num?)?.toInt() ?? 0));
  int get _totalProt => _itens.fold(0, (s, i) => s + ((i['proteinas'] as num?)?.toInt() ?? 0));
  int get _totalCarb => _itens.fold(0, (s, i) => s + ((i['carboidratos'] as num?)?.toInt() ?? 0));
  int get _totalGord => _itens.fold(0, (s, i) => s + ((i['gorduras'] as num?)?.toInt() ?? 0));
  int get _totalFibra => _itens.fold(0, (s, i) => s + ((i['fibras'] as num?)?.toInt() ?? 0));

  final String _apiKey = '';
  final List<String> _modelosIA = [
    'gemini-flash-lite-latest',
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite-preview',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash'
  ];

  @override
  void initState() {
    super.initState();
    _itens = widget.refeicaoAtual;
    
    for (var item in _itens) {
      item['calorias_base'] ??= item['calorias'];
      item['carboidratos_base'] ??= item['carboidratos'];
      item['gorduras_base'] ??= item['gorduras'];
      item['proteinas_base'] ??= item['proteinas'];
      item['fibras_base'] ??= item['fibras'] ?? 0;
      item['isGrama'] ??= false;
      item['quantidade'] ??= 1.0;
      item['porcao'] ??= '1 porção';
    }
  }

  void _salvarRefeicao() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado.')),
        );
      }
      return;
    }

    final String userId = user.uid;
    final db = DatabaseService();
    final String dataHoraIso = DateTime.now().toIso8601String();
    final String todayStr = dataHoraIso.split('T')[0];
    
    final Map<String, dynamic> dadosRefeicao = {
      'nome': widget.dadosIA['nome'] ?? 'Minha Refeição',
      'calorias': _totalKcal,
      'proteinas': _totalProt,
      'carboidratos': _totalCarb,
      'gorduras': _totalGord,
      'fibras': _totalFibra,
      'imagem_path': _itens.isNotEmpty ? _itens.first['imagem_path'] : null,
      'imagem_url': _itens.isNotEmpty ? _itens.first['imagem_url'] : null,
      'itens': _itens.map((item) => {
        'nome': item['nome'] ?? 'Alimento',
        'porcao': item['porcao'] ?? '1 porção',
        'calorias': item['calorias'] ?? 0,
        'proteinas': item['proteinas'] ?? 0,
        'carboidratos': item['carboidratos'] ?? 0,
        'gorduras': item['gorduras'] ?? 0,
        'fibras': item['fibras'] ?? 0,
        'imagem_path': item['imagem_path'],
        'imagem_url': item['imagem_url'],
        'isGrama': item['isGrama'] ?? false,
        'quantidade': item['quantidade'] ?? 1.0,
        'calorias_base': item['calorias_base'] ?? item['calorias'] ?? 0,
        'proteinas_base': item['proteinas_base'] ?? item['proteinas'] ?? 0,
        'carboidratos_base': item['carboidratos_base'] ?? item['carboidratos'] ?? 0,
        'gorduras_base': item['gorduras_base'] ?? item['gorduras'] ?? 0,
        'fibras_base': item['fibras_base'] ?? item['fibras'] ?? 0,
      }).toList(),
      'dataHora': dataHoraIso,
      'dia_ref': todayStr,
      'created_at': FieldValue.serverTimestamp(),
    };

    try {
      await db.adicionarRefeicao(dadosRefeicao);

      final historicoRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('historico');

      String? historicoId;
      final query = await historicoRef
          .where('data', isEqualTo: todayStr)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        historicoId = query.docs.first.id;
      } else {
        final novoDoc = await historicoRef.add({
          'data': todayStr,
          'calorias_consumidas': 0,
          'proteina_consumida': 0,
          'carbo_consumida': 0,
          'gordura_consumida': 0,
          'fibra_consumida': 0,
        });
        historicoId = novoDoc.id;
      }

      await historicoRef.doc(historicoId).update({
        'calorias_consumidas': FieldValue.increment(_totalKcal),
        'proteina_consumida': FieldValue.increment(_totalProt),
        'carbo_consumida': FieldValue.increment(_totalCarb),
        'gordura_consumida': FieldValue.increment(_totalGord),
        'fibra_consumida': FieldValue.increment(_totalFibra),
      });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _GifSuccessDialog(),
      );

      await Future.delayed(const Duration(milliseconds: 2500));
      
      if (mounted) {
        widget.refeicaoAtual.clear(); 
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('Erro ao salvar refeição: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar refeição: $e')));
      }
    }
  }

  Future<String> _executarModelosConcorrentes(List<Content> content) async {
    final completer = Completer<String>();
    int falhas = 0;

    for (String nomeModelo in _modelosIA) {
      final model = GenerativeModel(model: nomeModelo, apiKey: _apiKey);
      model.generateContent(content).then((response) {
        if (!completer.isCompleted && response.text != null && response.text!.contains('{')) {
          completer.complete(response.text);
        } else if (!completer.isCompleted) {
          falhas++;
          if (falhas == _modelosIA.length) completer.completeError('Nenhum modelo retornou resposta válida.');
        }
      }).catchError((e) {
        falhas++;
        if (falhas == _modelosIA.length && !completer.isCompleted) completer.completeError('Todos os modelos falharam.');
      });
    }
    return completer.future;
  }

  Future<void> _analisarTextoComIA(String texto) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 24),
            Text('A IA está analisando...', style: TextStyle(fontFamily: 'LilitaOne', color: Colors.white, fontSize: 24, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );

    DateTime startTime = DateTime.now();
    Duration maxTotalDuration = const Duration(minutes: 3);
    Duration attemptTimeout = const Duration(minutes: 1);

    final prompt = '''Você é um nutricionista especialista. O usuário informou a seguinte refeição: "$texto".
Separe os alimentos descritos e estime seus macros.
Especifique SEMPRE no campo porcao a medida caseira sugerida ou a que o usuário informou (ex: "2 colheres de sopa", "100g").
Retorne um JSON estrito no exato formato abaixo:
{
  "valido": true,
  "nome": "Refeição do Usuário",
  "itens": [
    {
      "nome": "Ingrediente 1",
      "porcao": "1 porção",
      "calorias": 150,
      "proteinas": 10,
      "carboidratos": 15,
      "gorduras": 5,
      "fibras": 2
    }
  ]
}''';

    final content = [Content.text(prompt)];
    await _processarIA(content: content, startTime: startTime, maxTotalDuration: maxTotalDuration, attemptTimeout: attemptTimeout);
  }

  Future<void> _processarIA({required List<Content> content, required DateTime startTime, required Duration maxTotalDuration, required Duration attemptTimeout}) async {
    bool sucesso = false;

    while (DateTime.now().difference(startTime) < maxTotalDuration && !sucesso) {
      try {
        String jsonString = await _executarModelosConcorrentes(content).timeout(attemptTimeout);

        jsonString = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
        int firstBrace = jsonString.indexOf('{');
        int lastBrace = jsonString.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1) jsonString = jsonString.substring(firstBrace, lastBrace + 1);

        Map<String, dynamic> resultado = jsonDecode(jsonString);
        if (mounted) Navigator.pop(context);

        if (resultado['valido'] == false) {
          _mostrarErroIA(resultado['erro'] ?? 'Entrada inválida. Tente novamente.');
          return;
        }

        List<dynamic> itensReconhecidos = resultado['itens'] ?? [];
        if (mounted) {
          setState(() {
            for (var item in itensReconhecidos) {
              var novoItem = Map<String, dynamic>.from(item);
              novoItem['porcao'] ??= '1 porção';
              novoItem['fibras'] ??= 0;
              novoItem['calorias_base'] = novoItem['calorias'];
              novoItem['carboidratos_base'] = novoItem['carboidratos'];
              novoItem['gorduras_base'] = novoItem['gorduras'];
              novoItem['proteinas_base'] = novoItem['proteinas'];
              novoItem['fibras_base'] = novoItem['fibras'];
              novoItem['isGrama'] = false;
              novoItem['quantidade'] = 1.0;
              _itens.add(novoItem);
            }
          });
        }
        sucesso = true;

      } catch (e) {
        await Future.delayed(const Duration(seconds: 2)); 
      }
    }

    if (!sucesso && mounted) {
      Navigator.pop(context);
      _mostrarErroIA('Nossa IA demorou para responder. Tente novamente.');
    }
  }

  void _mostrarErroIA(String mensagem) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.orange, size: 60),
              const SizedBox(height: 16),
              const Text('Ops! 📸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black)),
              const SizedBox(height: 12),
              Text(mensagem, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tentar Novamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarBuscaManual() {
    final TextEditingController textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Digite o que comeu (ex: 1 ovo cozido)...',
                  prefixIcon: const Icon(Icons.fastfood),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onSubmitted: (query) {
                  if (query.isNotEmpty) {
                    Navigator.pop(context);
                    _buscarNoFirebase(query.trim().toLowerCase());
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      icon: const Icon(Icons.search, color: Colors.black, size: 18),
                      label: const Text('Banco de Dados', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          Navigator.pop(context);
                          _buscarNoFirebase(textController.text.trim().toLowerCase());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      label: const Text('Analisar IA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          Navigator.pop(context);
                          _analisarTextoComIA(textController.text.trim());
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.history, color: Colors.grey.shade300, size: 50),
                      const SizedBox(height: 10),
                      Text('Busque seus alimentos aqui ou peça para a IA calcular.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _buscarNoFirebase(String query) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.orange)));
    try {
      final snap = await FirebaseFirestore.instance.collection('alimentos').where('nome_busca', arrayContains: query).limit(10).get();
      if (mounted) Navigator.pop(context);
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não encontrado no banco. Nossa IA vai analisar para você! ✨'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
        _analisarTextoComIA(query); 
        return;
      }
      _mostrarResultadosBuscaFirebase(snap.docs);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro na busca: $e')));
    }
  }

  void _mostrarResultadosBuscaFirebase(List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) {
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFFFFF3E0), backgroundImage: data['imagem_url'] != null ? NetworkImage(data['imagem_url']) : const NetworkImage('https://cdn-icons-png.flaticon.com/512/706/706164.png')),
              title: Text(data['nome'] ?? 'Alimento'),
              subtitle: Text('${data['porcao_padrao'] ?? data['porcao'] ?? '1 porção'} • ${data['calorias']} kcal'),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle), color: Colors.black,
                onPressed: () {
                  setState(() {
                    data['porcao'] ??= data['porcao_padrao'] ?? '1 porção';
                    data['fibras'] ??= 0;
                    data['calorias_base'] = data['calorias'];
                    data['carboidratos_base'] = data['carboidratos'];
                    data['gorduras_base'] = data['gorduras'];
                    data['proteinas_base'] = data['proteinas'];
                    data['fibras_base'] = data['fibras'] ?? 0;
                    data['isGrama'] = false;
                    data['quantidade'] = 1.0;
                    _itens.add(data);
                  });
                  Navigator.pop(context);
                },
              ),
            );
          }
        );
      }
    );
  }

  ImageProvider _obterImagemProvider(Map<String, dynamic> item) {
    if (item['imagem_path'] != null) {
      return FileImage(File(item['imagem_path']));
    } else if (item['imagem_url'] != null) {
      return NetworkImage(item['imagem_url']);
    }
    return const NetworkImage('https://cdn-icons-png.flaticon.com/512/706/706164.png');
  }

  void _editarItem(int index) {
    Map<String, dynamic> item = _itens[index];
    
    bool isGramaModal = item['isGrama'] ?? false;
    double quantidadeModal = (item['quantidade'] ?? 1).toDouble();
    
    num kcalBase = item['calorias_base'] ?? item['calorias'] ?? 0;
    num carbBase = item['carboidratos_base'] ?? item['carboidratos'] ?? 0;
    num fatBase = item['gorduras_base'] ?? item['gorduras'] ?? 0;
    num protBase = item['proteinas_base'] ?? item['proteinas'] ?? 0;
    num fibBase = item['fibras_base'] ?? item['fibras'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            
            double multiplicador = isGramaModal ? (quantidadeModal / 100.0) : quantidadeModal;
            if (multiplicador <= 0) multiplicador = 0.1;

            return Padding(
              padding: EdgeInsets.only(left: 24.0, right: 24.0, top: 20.0, bottom: MediaQuery.of(context).viewInsets.bottom + 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFFF3F4F6),
                        backgroundImage: _obterImagemProvider(item),
                      ),
                      Container(decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 20))
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item['nome'] ?? 'Item', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  if (item['porcao'] != null) ...[
                    const SizedBox(height: 4),
                    Text('Medida sugerida: ${item['porcao']}', style: TextStyle(fontSize: 13, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 12),
                  
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.redAccent, size: 16),
                          Text(' ${(kcalBase * multiplicador).toStringAsFixed(0)} kcal', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('C ${(carbBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      Text('G ${(fatBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      Text('P ${(protBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('Fi ${(fibBase * multiplicador).toStringAsFixed(1)}g', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  Container(
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateModal(() { isGramaModal = false; quantidadeModal = 1.0; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: !isGramaModal ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30), boxShadow: !isGramaModal ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : []),
                              child: Center(child: Text('Unidade', style: TextStyle(fontWeight: FontWeight.bold, color: !isGramaModal ? Colors.black : Colors.grey))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setStateModal(() { isGramaModal = true; quantidadeModal = 100.0; }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(color: isGramaModal ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30), boxShadow: isGramaModal ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : []),
                              child: Center(child: Text('Gramas', style: TextStyle(fontWeight: FontWeight.bold, color: isGramaModal ? Colors.black : Colors.grey))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.remove), onPressed: () {
                            setStateModal(() {
                              if (isGramaModal && quantidadeModal > 10) quantidadeModal -= 10;
                              else if (!isGramaModal && quantidadeModal > 1) quantidadeModal -= 1;
                            });
                          })),
                        Text(isGramaModal ? '${quantidadeModal.toStringAsFixed(0)} g' : '${quantidadeModal.toStringAsFixed(0)} unidade(s)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.add), onPressed: () {
                            setStateModal(() {
                              if (isGramaModal) quantidadeModal += 10;
                              else quantidadeModal += 1;
                            });
                          })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() => _itens.removeAt(index));
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                          onPressed: () {
                            setState(() {
                              item['isGrama'] = isGramaModal;
                              item['quantidade'] = quantidadeModal;
                              item['calorias'] = (kcalBase * multiplicador).round();
                              item['carboidratos'] = (carbBase * multiplicador).toDouble();
                              item['gorduras'] = (fatBase * multiplicador).toDouble();
                              item['proteinas'] = (protBase * multiplicador).toDouble();
                              item['fibras'] = (fibBase * multiplicador).toDouble();
                              item['porcao'] = isGramaModal 
                                ? '${quantidadeModal.toStringAsFixed(0)}g' 
                                : '${quantidadeModal.toStringAsFixed(0)}x (${item['porcao'] ?? '1 unidade'})';
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('✓ Salvar', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    String horaFormatada = TimeOfDay.now().format(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Flexible(
              child: Text(
                'Minha refeição', 
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 24),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text('× ${_itens.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14))),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt), onPressed: () => Navigator.pop(context)),
          IconButton(icon: const Icon(Icons.home), onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst)),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hoje às $horaFormatada', style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => setState(() => _itens.clear())),
                  ]
                ),
                const SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itens.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.transparent, height: 16),
                  itemBuilder: (context, index) {
                    final item = _itens[index];
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xFFF3F4F6),
                          backgroundImage: _obterImagemProvider(item),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(item['nome'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified, color: Colors.green, size: 14),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 14),
                                  Expanded(child: Text(' ${item['porcao'] ?? '1 porção'} · ${item['calorias']} kcal', style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: IconButton(icon: const Icon(Icons.edit, color: Colors.black, size: 18), onPressed: () => _editarItem(index)),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                    ),
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text('Adicionar mais itens', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    onPressed: _mostrarBuscaManual,
                  ),
                )
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20, top: 12),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.0), Colors.white], stops: const [0.0, 0.4])),
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: _salvarRefeicao,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]),
                    child: Text('Registrar $_totalKcal kcal', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _GifSuccessDialog extends StatefulWidget {
  const _GifSuccessDialog();
  @override
  State<_GifSuccessDialog> createState() => _GifSuccessDialogState();
}

class _GifSuccessDialogState extends State<_GifSuccessDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/sucesso.gif', 
              width: 140, 
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Parabéns, mais uma refeição concluída!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'LilitaOne',
              fontSize: 24,
              color: Colors.white,
              decoration: TextDecoration.none
            ),
          ),
        ],
      ),
    );
  }
}