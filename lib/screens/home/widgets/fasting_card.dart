// card para contabilizar jejum com historico do dia

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';

class FastingCard extends StatefulWidget {
  final Map<String, dynamic> perfil;
  const FastingCard({super.key, required this.perfil});

  @override
  State<FastingCard> createState() => _FastingCardState();
}

class _FastingCardState extends State<FastingCard> with SingleTickerProviderStateMixin {
  int _duracaoHoras = 16;
  bool _emJejum = false;
  DateTime? _inicioJejum;
  Timer? _timer;
  Duration _tempoDecorrido = Duration.zero;

  late AnimationController _astroController;

  final Map<int, String> _mensagensJejum = {
    2: '2 horas: Seu corpo está digerindo e absorvendo os nutrientes.',
    4: '4 horas: A insulina começa a diminuir gradualmente.',
    6: '6 horas: Seu corpo começa a recorrer mais às reservas.',
    8: '8 horas: A utilização de gordura como fonte de energia começa a aumentar.',
    10: '10 horas: Seu corpo continua alternando entre glicogênio e gordura.',
    12: '12 horas: A utilização das reservas de gordura aumenta.',
    14: '14 horas: Seu metabolismo fornece energia a partir das reservas.',
    16: '16 horas: A contribuição da gordura para energia está maior.',
    18: '18 horas: Seu corpo continua utilizando suas reservas energéticas.',
    20: '20 horas: A mobilização de gordura fornece energia ao organismo.',
    22: '22 horas: Seu corpo segue utilizando suas reservas para manter funções.',
    24: '24 horas completas! Seu corpo passou um período prolongado utilizando reservas.',
  };

  @override
  void initState() {
    super.initState();
    _astroController = AnimationController(vsync: this, duration: const Duration(seconds: 15))..repeat();
    _carregarEstadoJejum();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _astroController.dispose();
    super.dispose();
  }

  Future<void> _carregarEstadoJejum() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['jejumAtivo'] == true && data['inicioJejum'] != null) {
        if (mounted) {
          setState(() {
            _emJejum = true;
            _duracaoHoras = data['duracaoJejumMeta'] ?? 16;
            _inicioJejum = (data['inicioJejum'] as Timestamp).toDate();
          });
        }
        _iniciarTimerLocal();
      }
    }
  }

  void _iniciarTimerLocal() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_inicioJejum != null) {
        final agora = DateTime.now();
        final diff = agora.difference(_inicioJejum!);
        if (mounted) {
          setState(() {
            _tempoDecorrido = diff;
          });
        }

        if (diff.inHours >= _duracaoHoras) {
          _finalizarJejumAutomatico();
        }
      }
    });
  }

  Future<void> _iniciarJejum(int horas) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final agora = DateTime.now();
    if (mounted) {
      setState(() {
        _duracaoHoras = horas;
        _emJejum = true;
        _inicioJejum = agora;
        _tempoDecorrido = Duration.zero;
      });
    }

    await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
      'jejumAtivo': true,
      'inicioJejum': Timestamp.fromDate(agora),
      'duracaoJejumMeta': horas,
    }, SetOptions(merge: true));

    _iniciarTimerLocal();
  }

  Future<void> _pararEFinalizarJejum() async {
    _timer?.cancel();
    User? user = FirebaseAuth.instance.currentUser;
    final horasConcluidas = _tempoDecorrido.inHours;

    if (user != null && _inicioJejum != null) {
      DateTime inicio = _inicioJejum!;
      String dataStr = inicio.toIso8601String().split('T')[0];

      
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).collection('historico_jejum').add({
        'inicio': Timestamp.fromDate(inicio),
        'fim': Timestamp.fromDate(DateTime.now()),
        'metaHoras': _duracaoHoras,
        'horasCumpridas': horasConcluidas,
        'data': Timestamp.fromDate(inicio),
      });

      
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'jejumAtivo': false,
        'inicioJejum': null,
      }, SetOptions(merge: true));

     
      final docDiario = FirebaseFirestore.instance.collection('usuarios').doc(user.uid).collection('historico_diario').doc(dataStr);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docDiario);
        List<dynamic> jejunsAtuais = [];
        if (snapshot.exists && snapshot.data() != null && snapshot.data()!.containsKey('jejuns')) {
          jejunsAtuais = snapshot.get('jejuns');
        }
        jejunsAtuais.add('Jejum concluído: $horasConcluidas horas');

        transaction.set(docDiario, {
          'jejuns': jejunsAtuais,
          'horas_jejum': horasConcluidas,
          'teve_atividade': true,
          'data_registro': Timestamp.fromDate(inicio)
        }, SetOptions(merge: true));
      });
    }

    if (mounted) {
      setState(() {
        _emJejum = false;
      });
      _mostrarModalConclusao(horasConcluidas);
    }
  }

  void _finalizarJejumAutomatico() {
    _pararEFinalizarJejum();
  }

  void _mostrarModalConclusao(int horas) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events, color: AppTheme.primaryOrange, size: 48),
            ),
            const SizedBox(height: 12),
            const Text('Jejum Finalizado!', style: TextStyle(fontFamily: 'LilitaOne', color: AppTheme.primaryOrange, fontSize: 24)),
          ],
        ),
        content: Text('Parabéns! Você concluiu $horas horas de jejum. Mantenha o foco!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _abrirHistoricoJejum();
            },
            child: const Text('Histórico', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            ),
            onPressed: () {
              Navigator.pop(context);
              _selecionarOpcaoJejum();
            },
            child: const Text('Iniciar Novo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _abrirHistoricoJejum() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DateTime agora = DateTime.now();
    DateTime inicioDoDiaAtual = DateTime(agora.year, agora.month, agora.day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text('Jejuns de Hoje', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 24, color: AppTheme.textDark)),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('usuarios')
                      .doc(user.uid)
                      .collection('historico_jejum')
                      .where('fim', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioDoDiaAtual)) // Filtra apenas os de hoje
                      .orderBy('fim', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Nenhum jejum finalizado hoje.', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        int horas = data['horasCumpridas'] ?? 0;
                        int meta = data['metaHoras'] ?? 0;
                        DateTime fim = (data['fim'] as Timestamp).toDate();
                        
                        bool metaAlcancada = horas >= meta;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: metaAlcancada ? Colors.green.shade200 : AppTheme.primaryOrange.withOpacity(0.4), 
                              width: 1.5
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: metaAlcancada ? Colors.green.shade50 : Colors.orange.shade50, 
                                  shape: BoxShape.circle
                                ),
                                child: Icon(
                                  metaAlcancada ? Icons.check_circle_rounded : Icons.timelapse_rounded, 
                                  color: metaAlcancada ? Colors.green : AppTheme.primaryOrange,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$horas horas concluídas', 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Meta original: ${meta}h', 
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Hoje', 
                                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 11)
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}', 
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.bold)
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selecionarOpcaoJejum() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24.0, right: 24.0, top: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Escolha a Duração', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
              children: [
                ...[12, 14, 16, 18, 24].map((h) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _iniciarJejum(h);
                  },
                  child: Text('$h Horas', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                )),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _selecionarOpcaoPersonalizada();
                  },
                  child: const Text('Personalizado', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _selecionarOpcaoPersonalizada() {
    final TextEditingController customHoursController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text('Jejum Personalizado', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'LilitaOne', color: AppTheme.primaryOrange, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quantas horas de jejum você deseja fazer? (Máx 24h)', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: customHoursController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              decoration: InputDecoration(
                hintText: 'Ex: 10',
                counterText: "",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              int? horas = int.tryParse(customHoursController.text);
              if (horas != null && horas > 0 && horas <= 24) {
                Navigator.pop(context);
                _iniciarJejum(horas);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor, insira um valor válido entre 1 e 24.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Iniciar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _obterMensagemFase() {
    int horasAtual = _tempoDecorrido.inHours;
    String msg = 'Mantenha-se hidratado durante o jejum.';
    _mensagensJejum.forEach((h, texto) {
      if (horasAtual >= h) msg = texto;
    });
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    double progresso = _emJejum ? (_tempoDecorrido.inSeconds / (_duracaoHoras * 3600)).clamp(0.0, 1.0) : 0.0;
    int horas = _tempoDecorrido.inHours;
    int minutos = _tempoDecorrido.inMinutes.remainder(60);
    int segundos = _tempoDecorrido.inSeconds.remainder(60);

    bool isDay = DateTime.now().hour >= 6 && DateTime.now().hour < 18;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jejum Intermitente', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 20, color: AppTheme.textDark)),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.grey),
                onPressed: _abrirHistoricoJejum,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: isDay
                          ? [Colors.lightBlue.shade200, Colors.blue.shade400]
                          : [Colors.indigo.shade900, const Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (!isDay)
                        AnimatedBuilder(
                          animation: _astroController,
                          builder: (context, child) {
                            return Stack(
                              children: [
                                Positioned(top: 25, left: 30, child: Opacity(opacity: (0.3 + 0.7 * math.sin(_astroController.value * math.pi * 20)).abs(), child: const Icon(Icons.star, color: Colors.white, size: 8))),
                                Positioned(top: 45, right: 25, child: Opacity(opacity: (0.3 + 0.7 * math.cos(_astroController.value * math.pi * 15)).abs(), child: const Icon(Icons.star, color: Colors.white, size: 10))),
                                Positioned(bottom: 35, left: 45, child: Opacity(opacity: (0.3 + 0.7 * math.sin(_astroController.value * math.pi * 10)).abs(), child: const Icon(Icons.star, color: Colors.white, size: 6))),
                              ],
                            );
                          },
                        ),
                      RotationTransition(
                        turns: _astroController,
                        child: SizedBox(
                          width: 120, height: 120,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10.0),
                              child: Icon(
                                isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                                color: isDay ? Colors.amberAccent : Colors.yellow.shade100,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140, height: 140,
                  child: CircularProgressIndicator(
                    value: progresso,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade100,
                    color: Colors.indigoAccent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _emJejum ? '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}' : '00:00:00',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          Text(_emJejum ? 'Meta: ${_duracaoHoras}h' : 'Parado', style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_emJejum) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(15)),
              child: Text(
                _obterMensagemFase(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.indigo, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _emJejum ? Colors.redAccent : AppTheme.primaryOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _emJejum ? _pararEFinalizarJejum : _selecionarOpcaoJejum,
              child: Text(
                _emJejum ? 'Parar Jejum' : 'Começar Jejum',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}