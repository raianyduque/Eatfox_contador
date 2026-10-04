// camera, analise de IA e procura por IA ou banco de dados
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: unused_import
import '../../theme/app_theme.dart';
import 'meal_result_screen.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  final ImagePicker _picker = ImagePicker();
  
  bool _isCameraInitialized = false;
  bool _isFlashOn = false;
  bool _isBarcodeMode = false;
  
  final List<Map<String, dynamic>> _refeicaoAtual = [];
  int get _totalKcalAtual => _refeicaoAtual.fold(0, (sum, item) => sum + ((item['calorias'] as num?)?.toInt() ?? 0));

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
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(_cameras![0], ResolutionPreset.high, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Erro na câmera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    if (_cameraController != null) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      });
    }
  }

  void _mostrarLoadingIA(XFile? imagem) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => _ScannerLoadingWidget(imagem: imagem),
    );
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

  Future<void> _analisarImagemComIA({required XFile imagem, required bool isRotulo}) async {
    _mostrarLoadingIA(imagem);

    DateTime startTime = DateTime.now();
    Duration maxTotalDuration = const Duration(minutes: 3);
    Duration attemptTimeout = const Duration(minutes: 1);
    // ignore: unused_local_variable
    bool sucesso = false;

    final bytes = await imagem.readAsBytes();

    final prompt = isRotulo 
      ? '''Você é um especialista lendo RÓTULOS NUTRICIONAIS. Verifique se a foto é um rótulo.
Retorne um JSON estrito no formato:
{
  "valido": true,
  "nome": "Nome do Produto",
  "itens": [
    {
      "nome": "Nome do Alimento",
      "porcao": "Ex: 1 unidade, 2 colheres de sopa, 100g",
      "calorias": 100,
      "proteinas": 5,
      "carboidratos": 10,
      "gorduras": 2,
      "fibras": 3
    }
  ]
}
Se inválido, retorne: {"valido": false, "erro": "Foto inválida de rótulo."}'''
      : '''Você é um nutricionista especialista. Verifique se a foto é de comida ou refeição. Separe os alimentos visíveis.
Especifique SEMPRE no campo porcao a medida caseira reconhecida (ex: "2 colheres de sopa", "1 escumadeira").
Retorne um JSON estrito:
{
  "valido": true,
  "nome": "Nome do Prato",
  "itens": [
    {
      "nome": "Ingrediente",
      "porcao": "2 colheres de sopa",
      "calorias": 130,
      "proteinas": 4,
      "carboidratos": 25,
      "gorduras": 1,
      "fibras": 2
    }
  ]
}''';

    final content = [Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])];

    await _processarIA(content: content, startTime: startTime, maxTotalDuration: maxTotalDuration, attemptTimeout: attemptTimeout, imagemPath: imagem.path);
  }

  Future<void> _analisarTextoComIA(String texto) async {
    _mostrarLoadingIA(null);

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
    await _processarIA(content: content, startTime: startTime, maxTotalDuration: maxTotalDuration, attemptTimeout: attemptTimeout, imagemPath: null);
  }

  Future<void> _processarIA({required List<Content> content, required DateTime startTime, required Duration maxTotalDuration, required Duration attemptTimeout, String? imagemPath}) async {
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
              if (imagemPath != null) novoItem['imagem_path'] = imagemPath;
              novoItem['porcao'] ??= '1 porção';
              novoItem['fibras'] ??= 0;
              _refeicaoAtual.add(novoItem);
            }
          });
        }
        sucesso = true;

      } on TimeoutException {
        debugPrint("Timeout atingido na análise.");
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2)); 
      }
    }

    if (!sucesso && mounted) {
      Navigator.pop(context);
      _mostrarErroIA('Nossa IA demorou para responder. Verifique sua conexão e tente novamente.');
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
              const Text(
                'Ops! 📸',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black),
              ),
              const SizedBox(height: 12),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
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
                  hintText: 'Digite o que comeu (ex: 1 prato de macarrão)...',
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não encontrado no banco. Nossa IA vai analisar para você! ✨', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ));
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
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFFFF3E0),
                backgroundImage: data['imagem_url'] != null 
                    ? NetworkImage(data['imagem_url']) 
                    : const NetworkImage('https://cdn-icons-png.flaticon.com/512/706/706164.png'),
              ),
              title: Text(data['nome'] ?? 'Alimento'),
              subtitle: Text('${data['porcao_padrao'] ?? data['porcao'] ?? '1 porção'} • ${data['calorias']} kcal'),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle),
                color: Colors.black,
                onPressed: () {
                  setState(() {
                    data['porcao'] ??= data['porcao_padrao'] ?? '1 porção';
                    data['fibras'] ??= 0;
                    _refeicaoAtual.add(data);
                  });
                  Navigator.pop(context);
                },
              ),
            );
          },
        );
      }
    );
  }

  void _irParaMinhaRefeicao() {
    if (_refeicaoAtual.isEmpty) return;
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => MealResultScreen(
          refeicaoAtual: _refeicaoAtual,
          dadosIA: {
            "nome": "Minha Refeição",
            "calorias": _totalKcalAtual,
            "itens": _refeicaoAtual,
          }
        )
      )
    ).then((_) => setState(() {}));
  }

  ImageProvider _obterImagemProvider(Map<String, dynamic> item) {
    if (item['imagem_path'] != null) {
      return FileImage(File(item['imagem_path']));
    } else if (item['imagem_url'] != null) {
      return NetworkImage(item['imagem_url']);
    }
    return const NetworkImage('https://cdn-icons-png.flaticon.com/512/706/706164.png');
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_cameraController!),
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.6),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Center(
                          child: Container(
                            height: 320,
                            width: 320,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          Positioned(
            top: topPadding + 10, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isBarcodeMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(color: !_isBarcodeMode ? Colors.white30 : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                          child: Text('Refeição', style: TextStyle(color: !_isBarcodeMode ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isBarcodeMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(color: _isBarcodeMode ? Colors.white30 : Colors.transparent, borderRadius: BorderRadius.circular(20)),
                          child: Text('Rótulo', style: TextStyle(color: _isBarcodeMode ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
                CircleAvatar(backgroundColor: Colors.black54, child: IconButton(icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white), onPressed: _toggleFlash)),
              ],
            ),
          ),

          Positioned(
            bottom: _refeicaoAtual.isNotEmpty ? 110 : 40, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(backgroundColor: Colors.black54, radius: 25, child: IconButton(icon: const Icon(Icons.image, color: Colors.white), onPressed: () async {
                  final foto = await _picker.pickImage(source: ImageSource.gallery);
                  if (foto != null) await _analisarImagemComIA(imagem: foto, isRotulo: _isBarcodeMode);
                })),
                GestureDetector(
                  onTap: () async {
                    if (_cameraController != null) {
                      final foto = await _cameraController!.takePicture();
                      await _analisarImagemComIA(imagem: foto, isRotulo: _isBarcodeMode);
                    }
                  },
                  child: Container(
                    height: 80, width: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.transparent),
                    child: Center(child: Container(height: 65, width: 65, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                  ),
                ),
                CircleAvatar(backgroundColor: Colors.black54, radius: 25, child: IconButton(icon: const Icon(Icons.keyboard, color: Colors.white), onPressed: _mostrarBuscaManual)),
              ],
            ),
          ),

          if (_refeicaoAtual.isNotEmpty)
            Positioned(
              bottom: 20, left: 20, right: 20,
              child: SafeArea(
                top: false,
                child: Container(
                  height: 65,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]),
                  child: Row(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: _refeicaoAtual.length,
                          itemBuilder: (context, index) {
                            var item = _refeicaoAtual[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 12),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFFFFF3E0),
                                backgroundImage: _obterImagemProvider(item),
                              ),
                            );
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: _irParaMinhaRefeicao,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(35)),
                          child: Text('Registrar $_totalKcalAtual kcal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _ScannerLoadingWidget extends StatefulWidget {
  final XFile? imagem;
  const _ScannerLoadingWidget({this.imagem});

  @override
  State<_ScannerLoadingWidget> createState() => _ScannerLoadingWidgetState();
}

class _ScannerLoadingWidgetState extends State<_ScannerLoadingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.imagem != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  children: [
                    Image.file(File(widget.imagem!.path), width: 250, height: 250, fit: BoxFit.cover),
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Positioned(
                          top: _controller.value * 250,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.8),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                )
                              ]
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            const CircularProgressIndicator(color: Colors.orange),
          const SizedBox(height: 24),
          const Text(
            'A IA está analisando...',
            style: TextStyle(
              fontFamily: 'LilitaOne',
              color: Colors.white,
              fontSize: 24,
              decoration: TextDecoration.none
            )
          ),
          const SizedBox(height: 8),
          const Text(
            'Lendo ingredientes e porções',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              decoration: TextDecoration.none
            )
          ),
        ],
      ),
    );
  }
}