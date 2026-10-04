// card de receitas e sugestoes com cadastro de preferencias, possivel compartilhar a receita.

import 'dart:async';
import 'dart:convert';
// ignore: unused_import
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import '../../../theme/app_theme.dart';

class MealPlanCard extends StatefulWidget {
  final Map<String, dynamic> perfil;

  const MealPlanCard({super.key, required this.perfil});

  @override
  State<MealPlanCard> createState() => _MealPlanCardState();
}

class _MealPlanCardState extends State<MealPlanCard> with AutomaticKeepAliveClientMixin {
  static const String _apiKey = '';

  final List<String> _modelosIA = [
    'gemini-flash-lite-latest',
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite-preview',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash-lite',
    'gemini-3.6-flash'
  ];

  Timer? _timer;
  bool _isFetching = false; 
  bool _needsFetch = true; 
  
  List<dynamic> _receitas = [];
  String _refeicaoAtual = 'Carregando...';

  int _minKcalAtual = 0;
  int _maxKcalAtual = 0;

  List<String> _alimentosGostos = [];
  List<String> _alimentosAversoes = [];
  final TextEditingController _outrosController = TextEditingController();

  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _carregarPreferenciasFirebase();
    _refeicaoAtual = _obterNomeRefeicao(DateTime.now());
    _gerarReceitas();
    _iniciarLoop(); 
  }

  @override
  void dispose() {
    _timer?.cancel();
    _outrosController.dispose();
    super.dispose();
  }

  String get _userId {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null && authUid.trim().isNotEmpty) return authUid;
    final perfilUid = widget.perfil['uid'];
    if (perfilUid != null && perfilUid.toString().trim().isNotEmpty) return perfilUid.toString();
    return '';
  }

  Future<void> _carregarPreferenciasFirebase() async {
    if (_userId.isEmpty) return;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('preferencias').doc('preferencias').get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _alimentosGostos = List<String>.from(data['gostos'] ?? []);
          _alimentosAversoes = List<String>.from(data['aversoes'] ?? []);
          _outrosController.text = data['outros'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar preferências: $e");
    }
  }

  Future<void> _salvarPreferenciasFirebase(List<String> gostos, List<String> aversoes, String outros) async {
    if (_userId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(_userId).collection('preferencias').doc('preferencias').set({
        'gostos': gostos,
        'aversoes': aversoes,
        'outros': outros,
        'atualizado_em': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      setState(() {
        _alimentosGostos = gostos;
        _alimentosAversoes = aversoes;
        _outrosController.text = outros;
      });
      
      _gerarReceitas();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferências salvas com sucesso! Receitas em atualização...'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar preferências: $e");
    }
  }

  String _obterNomeRefeicao(DateTime horaAtual) {
    int hora = horaAtual.hour;
    if (hora >= 6 && hora < 10) return 'Café da manhã';
    if (hora >= 10 && hora < 12) return 'Lanche da manhã';
    if (hora >= 12 && hora < 15) return 'Almoço';
    if (hora >= 15 && hora < 19) return 'Lanche da tarde';
    if (hora >= 19 && hora < 23) return 'Jantar';
    return 'Ceia'; 
  }

  void _iniciarLoop() {
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) return;

      String refeicaoCorreta = _obterNomeRefeicao(DateTime.now());
      if (_refeicaoAtual != refeicaoCorreta) {
        setState(() {
          _refeicaoAtual = refeicaoCorreta;
          _needsFetch = true; 
        });
      }

      if (_needsFetch && !_isFetching) {
        _gerarReceitas();
      }
    });
  }

  Future<String> _executarModelosConcorrentes(String prompt) async {
    final completer = Completer<String>();
    int falhas = 0;
    final chaveLimpa = _apiKey.trim();

    for (String nomeModelo in _modelosIA) {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$nomeModelo:generateContent?key=$chaveLimpa');
      final body = jsonEncode({
        "contents": [ {"parts": [{"text": prompt}]} ],
        "generationConfig": { "temperature": 0.7 }
      });

      http.post(url, headers: {'Content-Type': 'application/json'}, body: body).then((response) {
        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          String? textoDaIA = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];
          if (!completer.isCompleted && textoDaIA != null && textoDaIA.contains('{')) {
            completer.complete(textoDaIA);
          } else if (!completer.isCompleted) {
            falhas++;
            if (falhas == _modelosIA.length) completer.completeError('Nenhum modelo retornou resposta válida.');
          }
        } else {
          falhas++;
          if (falhas == _modelosIA.length && !completer.isCompleted) {
            completer.completeError('Todos os modelos falharam com status ${response.statusCode}');
          }
        }
      }).catchError((e) {
        falhas++;
        if (falhas == _modelosIA.length && !completer.isCompleted) {
          completer.completeError('Todos os modelos falharam: $e');
        }
      });
    }
    return completer.future;
  }

  Future<void> _gerarReceitas() async {
    final chaveLimpa = _apiKey.trim();
    if (chaveLimpa.isEmpty) return;

    if (mounted) {
      setState(() { _isFetching = true; });
    }

    final tipoDieta = widget.perfil['tipoDieta'] ?? 'Equilibrada';
    final restricoesPerfil = widget.perfil['restricoes'] ?? 'Nenhuma';
    final alergias = widget.perfil['alergias'] ?? 'Nenhuma';
    final metaCalorias = widget.perfil['meta_calorias'] ?? 2000;
    
    double percentualRefeicao = 0.25; 
    if(_refeicaoAtual.contains('Lanche') || _refeicaoAtual == 'Ceia'){
        percentualRefeicao = 0.15;
    } else if (_refeicaoAtual == 'Almoço' || _refeicaoAtual == 'Jantar'){
        percentualRefeicao = 0.35;
    }
    
    int caloriasAlvo = (metaCalorias * percentualRefeicao).round();
    int minKcal = (caloriasAlvo * 0.9).round();
    int maxKcal = (caloriasAlvo * 1.1).round();

    if (mounted) {
      setState(() {
        _minKcalAtual = minKcal;
        _maxKcalAtual = maxKcal;
      });
    }

    String strGostos = _alimentosGostos.isNotEmpty ? _alimentosGostos.join(', ') : 'Nenhuma preferência específica';
    String strAversoes = _alimentosAversoes.isNotEmpty ? _alimentosAversoes.join(', ') : 'Nenhuma';
    String strOutros = _outrosController.text.trim().isNotEmpty ? _outrosController.text : 'Nenhum';

    final prompt = '''Você é um nutricionista experiente. 
    Sugira 3 receitas para $_refeicaoAtual. 
    Dieta/Estilo: $tipoDieta. 
    Alergias médicas: $alergias.
    Restrições de perfil: $restricoesPerfil.
    
    PREFERÊNCIAS DO USUÁRIO (MUITO IMPORTANTE):
    - Alimentos/Estilos que o usuário GOSTA: $strGostos
    - Alimentos que o usuário ODEIA/NÃO COME (Exclua estritamente): $strAversoes
    - Outras observações do usuário: $strOutros
    
    A refeição deve ter de $minKcal até $maxKcal calorias totais.
    
    Retorne APENAS UM JSON VÁLIDO contendo uma lista de 3 receitas. Não inclua texto fora do JSON.
    Formato obrigatório:
    {
      "receitas": [
        {
          "nome": "Nome da receita",
          "nome_ingles": "Recipe name in English (crucial for image search)",
          "descricao": "Descricao breve",
          "calorias": "300 kcal",
          "tempo_preparo": "20 min",
          "macros": "Carb: 30g, Prot: 20g, Gord: 10g",
          "ingredientes": ["item 1 (qtd)", "item 2 (qtd)"],
          "preparo": ["passo 1", "passo 2"]
        }
      ]
    }''';

    try {
      String textoDaIA = await _executarModelosConcorrentes(prompt);

      textoDaIA = textoDaIA.replaceAll('```json', '').replaceAll('```', '').trim();
      final contentJson = jsonDecode(textoDaIA);
      
      if (mounted) {
        setState(() {
          _receitas = contentJson['receitas']; 
          _needsFetch = false; 
        });
      }
    } catch (e) {
      debugPrint('Falha/Servidor cheio ao obter receita: $e');
    } finally {
      if (mounted) {
        setState(() { _isFetching = false; });
      }
    }
  }

  String _gerarLinkImagem(String nomePrato) {
    String termoBusca = Uri.encodeComponent('photorealistic professional food photography of $nomePrato, appetizing meal, restaurant plating, soft lighting, 4k');
    return 'https://image.pollinations.ai/prompt/$termoBusca?width=600&height=400&nologo=true';
  }

  void _compartilharReceita(Map<String, dynamic> receita) {
    final texto = '''
🍽 *${receita['nome']}*

${receita['descricao']}
📊 ${receita['calorias']} | ⏱ ${receita['tempo_preparo'] ?? '15 min'} | ${receita['macros']}

🛒 *Ingredientes:*
${(receita['ingredientes'] as List? ?? []).map((i) => '• $i').join('\n')}

👨‍🍳 *Modo de Preparo:*
${(receita['preparo'] as List? ?? []).asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

✨ *Gerado para o meu Plano Alimentar!*
''';

    Share.share(texto, subject: 'Receita: ${receita['nome']}');
  }

  Widget _buildInstructionBadge(String step, String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color.shade600, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$step: $label',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade800),
          ),
        ],
      ),
    );
  }

  void _abrirPreferencias() {
    List<String> gostosTemp = List.from(_alimentosGostos);
    List<String> aversoesTemp = List.from(_alimentosAversoes);
    TextEditingController outrosTemp = TextEditingController(text: _outrosController.text);

    final List<Map<String, dynamic>> categorias = [
      {'titulo': 'Carnes e proteínas', 'icone': Icons.set_meal_rounded, 'itens': ['Carnes bovinas', 'Carnes suínas', 'Frango e aves', 'Peixes', 'Frutos do mar', 'Ovos', 'Embutidos/processadas']},
      {'titulo': 'Vegetais e hortaliças', 'icone': Icons.eco_rounded, 'itens': ['Verduras e folhas', 'Legumes em geral', 'Raízes e tubérculos', 'Cogumelos', 'Milho/ricos em amido']},
      {'titulo': 'Frutas', 'icone': Icons.apple_rounded, 'itens': ['Frutas doces', 'Frutas cítricas', 'Frutas vermelhas', 'Frutas tropicais', 'Frutas secas/desidratadas', 'Abacate/cremosas']},
      {'titulo': 'Grãos e cereais', 'icone': Icons.grass_rounded, 'itens': ['Arroz', 'Feijões', 'Lentilha/ervilha/grão-de-bico', 'Aveia', 'Trigo e derivados', 'Milho e derivados', 'Quinoa', 'Granola/cereais']},
      {'titulo': 'Leites e derivados', 'icone': Icons.local_drink_rounded, 'itens': ['Leite', 'Queijos', 'Iogurtes', 'Requeijão/cream cheese', 'Manteiga/creme de leite', 'Leites vegetais']},
      {'titulo': 'Oleaginosas e sementes', 'icone': Icons.grain_rounded, 'itens': ['Amendoim', 'Castanhas e nozes', 'Sementes', 'Pastas de oleaginosas']},
      {'titulo': 'Pães, massas e farinhas', 'icone': Icons.bakery_dining_rounded, 'itens': ['Pães', 'Massas', 'Tapioca/crepioca', 'Cuscuz', 'Panquecas/wraps', 'Farinhas em geral']},
      {'titulo': 'Acompanhamentos', 'icone': Icons.lunch_dining_rounded, 'itens': ['Batatas', 'Mandioca e derivados', 'Abóbora', 'Polenta e angu', 'Farofas', 'Purês/cremosos']},
      {'titulo': 'Temperos e molhos', 'icone': Icons.soup_kitchen_rounded, 'itens': ['Alho e cebola', 'Ervas naturais', 'Pimentas/picantes', 'Molhos industrializados', 'Molhos caseiros', 'Ketchup/mostarda/maionese']},
      {'titulo': 'Doces', 'icone': Icons.cake_rounded, 'itens': ['Chocolates', 'Doces de leite/cremes', 'Açúcar e adoçantes', 'Mel e melados', 'Geleias', 'Frutas cristalizadas']},
      {'titulo': 'Proteínas vegetais', 'icone': Icons.spa_rounded, 'itens': ['Soja e derivados', 'Tofu e tempeh', 'Proteína texturizada', 'Hambúrgueres vegetais']},
      {'titulo': 'Gorduras e óleos', 'icone': Icons.water_drop_rounded, 'itens': ['Azeite', 'Óleos vegetais', 'Óleo de coco', 'Gorduras animais', 'Cremes gordurosos']},
      {'titulo': 'Preferências de sabor', 'icone': Icons.favorite_rounded, 'itens': ['Doce', 'Salgado', 'Azedo', 'Amargo', 'Picante', 'Agridoce', 'Defumado', 'Temperos suaves', 'Temperos intensos']},
      {'titulo': 'Preferências de preparo', 'icone': Icons.outdoor_grill_rounded, 'itens': ['Assados', 'Grelhados', 'Cozidos', 'Refogados', 'Fritos', 'Air fryer', 'Preparações cruas', 'Ensopados', 'Cremosos', 'Crocantes']},
      {'titulo': 'Estilos de culinária', 'icone': Icons.public_rounded, 'itens': ['Brasileira', 'Italiana', 'Japonesa', 'Chinesa', 'Mexicana', 'Árabe', 'Indiana', 'Coreana', 'Mediterrânea', 'Caseira', 'Fitness', 'Vegetariana', 'Vegana']},
      {'titulo': 'Praticidade', 'icone': Icons.timer_rounded, 'itens': ['Receitas rápidas', 'Poucos ingredientes', 'Preparo simples', 'Uma panela só', 'Receitas para congelar', 'Marmitas para a semana', 'Receitas econômicas', 'Ocasiões especiais']},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 4),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Suas Preferências', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppTheme.textGray),
                              onPressed: () => Navigator.pop(context),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade50, Colors.amber.shade50],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.touch_app_rounded, size: 18, color: AppTheme.primaryOrange),
                                  SizedBox(width: 6),
                                  Text('Como personalizar suas preferências:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInstructionBadge('1x', 'Gosto', Colors.green),
                                  _buildInstructionBadge('2x', 'Evitar', Colors.red),
                                  _buildInstructionBadge('3x', 'Limpar', Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: categorias.length + 1,
                          itemBuilder: (context, index) {
                            if (index == categorias.length) {
                              return Padding(
                                padding: const EdgeInsets.all(20),
                                child: TextField(
                                  controller: outrosTemp,
                                  decoration: InputDecoration(
                                    labelText: 'Nenhum destes? Escreva aqui...',
                                    hintText: 'Ex: Prefiro refeições sem lactose, bem temperadas...',
                                    labelStyle: const TextStyle(color: AppTheme.textGray),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: AppTheme.primaryOrange, width: 2)),
                                    prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryOrange),
                                    filled: true,
                                    fillColor: Colors.grey.shade50,
                                  ),
                                  maxLines: 2,
                                ),
                              );
                            }
                            final cat = categorias[index];
                            return ExpansionTile(
                              leading: Icon(cat['icone'], color: AppTheme.primaryOrange),
                              title: Text(cat['titulo'], style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textDark)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (cat['itens'] as List<String>).map((item) {
                                      bool isGosto = gostosTemp.contains(item);
                                      bool isAversao = aversoesTemp.contains(item);
                                      
                                      Color chipColor = Colors.grey.shade100;
                                      Color textColor = AppTheme.textDark;
                                      Color borderColor = Colors.grey.shade300;
                                      IconData? icon;
                                      Color iconColor = Colors.transparent;

                                      if (isGosto) {
                                        chipColor = Colors.green.shade50;
                                        borderColor = Colors.green;
                                        textColor = Colors.green.shade700;
                                        icon = Icons.check_circle;
                                        iconColor = Colors.green;
                                      } else if (isAversao) {
                                        chipColor = Colors.red.shade50;
                                        borderColor = Colors.red;
                                        textColor = Colors.red.shade700;
                                        icon = Icons.block;
                                        iconColor = Colors.red;
                                      }

                                      return InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          setModalState(() {
                                            if (!isGosto && !isAversao) {
                                              gostosTemp.add(item); 
                                            } else if (isGosto) {
                                              gostosTemp.remove(item);
                                              aversoesTemp.add(item); 
                                            } else if (isAversao) {
                                              aversoesTemp.remove(item); 
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: chipColor,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: borderColor),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (icon != null) ...[Icon(icon, size: 16, color: iconColor), const SizedBox(width: 4)],
                                              Text(item, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryOrange,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _salvarPreferenciasFirebase(gostosTemp, aversoesTemp, outrosTemp.text);
                            },
                            child: const Text('Salvar Preferências', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      )
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _abrirReceita(Map<String, dynamic> receita) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.90,
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  child: PersistentNetworkImage(
                    imageUrl: _gerarLinkImagem(receita['nome_ingles'] ?? receita['nome'] ?? 'Food'),
                    width: double.infinity,
                    height: 250,
                  ),
                ),
                Positioned(
                  top: 16, right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CircleAvatar(backgroundColor: Colors.black.withOpacity(0.5), child: const Icon(Icons.close, color: Colors.white)),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ListView(
                  children: [
                    Text(receita['nome'] ?? 'Receita', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 8),
                    Text(receita['descricao'] ?? '', style: const TextStyle(fontSize: 15, color: AppTheme.textGray, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primaryOrange.withOpacity(0.3))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [const Icon(Icons.local_fire_department, color: AppTheme.primaryOrange, size: 20), Text(receita['calorias'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          Column(children: [const Icon(Icons.access_time_rounded, color: AppTheme.primaryOrange, size: 20), Text(receita['tempo_preparo'] ?? '15 min', style: const TextStyle(fontWeight: FontWeight.bold))]),
                          Column(children: [const Icon(Icons.pie_chart, color: AppTheme.primaryOrange, size: 20), Text(receita['macros'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))])
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(children: const [Icon(Icons.shopping_basket_outlined, color: AppTheme.primaryOrange, size: 24), SizedBox(width: 8), Text('Ingredientes (1 Porção)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark))]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: (receita['ingredientes'] as List? ?? []).map((ingrediente) => Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [const Icon(Icons.check_circle, color: AppTheme.primaryOrange, size: 18), const SizedBox(width: 8), Expanded(child: Text(ingrediente.toString(), style: const TextStyle(fontSize: 15)))],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(children: const [Icon(Icons.blender_outlined, color: AppTheme.primaryOrange, size: 24), SizedBox(width: 8), Text('Modo de Preparo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark))]),
                    const SizedBox(height: 12),
                    ...(receita['preparo'] as List? ?? []).asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: AppTheme.primaryOrange, child: Text('${entry.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.value.toString(), style: const TextStyle(fontSize: 15, height: 1.4))),
                        ],
                      ),
                    )).toList(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text('Partilhar Receita', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _compartilharReceita(receita),
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
    super.build(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sugestões: $_refeicaoAtual', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                    const SizedBox(height: 4),
                    if (_minKcalAtual > 0)
                      Text('Meta para esta refeição: $_minKcalAtual a $_maxKcalAtual kcal', style: const TextStyle(fontSize: 13, color: AppTheme.primaryOrange, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    const Text('IA analisou as suas restrições e objetivos.', style: TextStyle(fontSize: 13, color: AppTheme.textGray)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textDark),
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  if (value == 'recarregar') {
                    _gerarReceitas();
                  } else if (value == 'preferencias') {
                    _abrirPreferencias();
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'recarregar',
                    child: Row(children: [Icon(Icons.refresh, color: AppTheme.primaryOrange), SizedBox(width: 10), Text('Recarregar Receitas')]),
                  ),
                  const PopupMenuItem(
                    value: 'preferencias',
                    child: Row(children: [Icon(Icons.tune, color: AppTheme.primaryOrange), SizedBox(width: 10), Text('Minhas Preferências')]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_receitas.isEmpty && _isFetching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Column(
                  children: [
                    BouncingFoodIcon(),
                    SizedBox(height: 20),
                    Text('Buscando as melhores receitas\npara o seu perfil...', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textGray, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4)),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                if (_isFetching) 
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(color: AppTheme.primaryOrange, backgroundColor: Colors.transparent),
                  ),
                ..._receitas.map((receita) => GestureDetector(
                  onTap: () => _abrirReceita(receita),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, spreadRadius: 1, offset: const Offset(0, 3))],
                      border: Border.all(color: Colors.orange.shade50),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                          child: PersistentNetworkImage(
                            imageUrl: _gerarLinkImagem(receita['nome_ingles'] ?? receita['nome'] ?? 'Food'),
                            width: 100,
                            height: 100,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(receita['nome'] ?? 'Receita', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('${receita['calorias'] ?? ''}', style: const TextStyle(fontSize: 12, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.access_time_rounded, size: 13, color: AppTheme.textGray),
                                    const SizedBox(width: 2),
                                    Text(receita['tempo_preparo'] ?? '15 min', style: const TextStyle(fontSize: 12, color: AppTheme.textGray, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(receita['descricao'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textGray), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.all(12.0), child: Icon(Icons.arrow_forward_ios, color: AppTheme.primaryOrange, size: 16)),
                      ],
                    ),
                  ),
                )).toList()
              ],
            ),
        ],
      ),
    );
  }
}

class BouncingFoodIcon extends StatefulWidget {
  const BouncingFoodIcon({super.key});

  @override
  State<BouncingFoodIcon> createState() => _BouncingFoodIconState();
}

class _BouncingFoodIconState extends State<BouncingFoodIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: -0.1, end: 0.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
        child: const Icon(Icons.restaurant_rounded, size: 48, color: AppTheme.primaryOrange),
      ),
    );
  }
}

class PersistentNetworkImage extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const PersistentNetworkImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<PersistentNetworkImage> createState() => _PersistentNetworkImageState();
}

class _PersistentNetworkImageState extends State<PersistentNetworkImage> {
  int _retryCount = 0;
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    String currentUrl = '${widget.imageUrl}&retry=$_retryCount';

    return Image.network(
      currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.orange.shade50,
          child: const Center(
            child: SizedBox(
              width: 24, height: 24, 
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange)
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_isRetrying) {
          _isRetrying = true;
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _retryCount++;
                _isRetrying = false; 
              });
            }
          });
        }
        
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.orange.shade100,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_search, color: AppTheme.primaryOrange, size: 24),
              SizedBox(height: 4),
              Text('Buscando...', style: TextStyle(fontSize: 10, color: AppTheme.primaryOrange, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}