// home, possui todos os cards, todas funcoes, ofensiva gravada por dia de uso, historico, mascote virtual e etc

import 'dart:async';
// ignore: unused_import
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart'; 
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart'; 
import '../../theme/app_theme.dart';
import '../../services/database_service.dart';
import 'widgets/calories_card.dart';
import 'widgets/water_card.dart';
import 'widgets/weight_card.dart';
import 'widgets/activity_card_preview.dart';
import 'widgets/meal_plan_card.dart';
import 'widgets/fasting_card.dart';
import 'widgets/menstruation_card.dart';
import '../meals/add_meal_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final String mascotName;
  const HomeScreen({super.key, this.mascotName = 'Bixinho'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<String> _ordemCards = [
    'menstruacao',
    'calorias',
    'atividades',
    'plano',
    'agua',
    'peso',
    'jejum'
  ];

  late Future<int> _ofensivaFuture;
  StreamSubscription<DocumentSnapshot>? _historicoSub;

  @override
  void initState() {
    super.initState();
    _carregarOrdemCards();
    _ofensivaFuture = _calcularOfensivaReal();

    _historicoSub = _db.streamHistoricoHoje().listen((_) {
      if (mounted) {
        setState(() {
          _ofensivaFuture = _calcularOfensivaReal();
        });
      }
    });
  }

  @override
  void dispose() {
    _historicoSub?.cancel();
    super.dispose();
  }

  Future<int> _calcularOfensivaReal() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('historico_diario')
          .where('teve_atividade', isEqualTo: true)
          .get();

      Set<DateTime> datas = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        DateTime? dt;
        if (data['data_registro'] != null) {
          dt = (data['data_registro'] as Timestamp).toDate();
        } else {
          try {
            dt = DateTime.parse(doc.id);
          } catch (_) {}
        }
        if (dt != null) datas.add(DateTime(dt.year, dt.month, dt.day));
      }

      DateTime agora = DateTime.now();
      DateTime hoje = DateTime(agora.year, agora.month, agora.day);
      DateTime ontem = hoje.subtract(const Duration(days: 1));

      DateTime dataCheck;
      if (datas.contains(hoje)) {
        dataCheck = hoje;
      } else if (datas.contains(ontem)) {
        dataCheck = ontem;
      } else {
        return 0;
      }

      int total = 0;
      while (datas.contains(dataCheck)) {
        total++;
        dataCheck = dataCheck.subtract(const Duration(days: 1));
      }

      return total;
    } catch (e) {
      print("Erro ao calcular ofensiva real: $e");
      return 0;
    }
  }

  Future<void> _carregarOrdemCards() async {
    var snapshot = await _db.streamPerfilUsuario().first;
    if (snapshot.exists && snapshot.data() != null) {
      var data = Map<String, dynamic>.from(snapshot.data() as Map);
      if (data.containsKey('ordemCards') && data['ordemCards'] is List) {
        setState(() {
          List<String> ordemCarregada = List<String>.from(data['ordemCards']);
          if (!ordemCarregada.contains('menstruacao')) {
            ordemCarregada.insert(0, 'menstruacao');
          }
          _ordemCards = ordemCarregada;
        });
      }
    }
  }

  Future<void> _salvarOrdemCards(List<String> novaOrdem) async {
    setState(() => _ordemCards = novaOrdem);
    await _db.atualizarPerfil({'ordemCards': novaOrdem});
  }

  int calcularVidasMascote(Map<String, dynamic>? historico) {
    if (historico == null) return 1;
    int vidas = 1;
    if ((historico['agua_ml'] ?? 0) > 0) vidas++;
    if ((historico['calorias_consumidas'] ?? 0) > 0) vidas++;
    if ((historico['calorias_gastas'] ?? 0) > 0) vidas++;
    return vidas;
  }

  String _getMascotImage(int vidas) {
    if (vidas == 4) return 'assets/feliz.mp4';
    if (vidas == 3) return 'assets/mascote.mp4';
    if (vidas == 2) return 'assets/bravo.mp4';
    return 'assets/dormindo.mp4';
  }

  void _editarNomeMascote(Map<String, dynamic> perfil) {
    final TextEditingController _nameController =
        TextEditingController(text: perfil['mascotName'] ?? widget.mascotName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Nome do Mascote',
            style: TextStyle(fontFamily: 'LilitaOne')),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: 'Digite o novo nome'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8D25)),
            onPressed: () {
              _db.atualizarPerfil({'mascotName': _nameController.text});
              Navigator.pop(context);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _abrirMenuAdicionar(
      Map<String, dynamic> perfil, Map<String, dynamic>? historico) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('O que deseja adicionar?',
                style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
            const SizedBox(height: 24),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFF8D25),
                  child: Icon(Icons.restaurant, color: Colors.white)),
              title: const Text('Refeição (IA)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddMealScreen()));
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.local_drink, color: Colors.white)),
              title: const Text('Água'),
              onTap: () {
                Navigator.pop(context);
                WaterCard.addCustomMl(context, _db);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.fitness_center, color: Colors.white)),
              title: const Text('Atividade Física'),
              onTap: () {
                Navigator.pop(context);
                ActivityCardPreview.abrirBusca(
                    context, _db, (perfil['peso'] as num? ?? 0).toDouble());
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.monitor_weight, color: Colors.white)),
              title: const Text('Atualizar Peso'),
              onTap: () {
                Navigator.pop(context);
                WeightCard.updateWeight(
                    context, (perfil['peso'] as num? ?? 0).toDouble(), _db);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardByKey(String key, Map<String, dynamic> perfil,
      Map<String, dynamic>? historico) {
    switch (key) {
      case 'menstruacao':
        return MenstruationCard(perfil: perfil);
      case 'calorias':
        return CaloriesCard(perfil: perfil, historico: historico);
      case 'atividades':
        return ActivityCardPreview(perfil: perfil, historico: historico);
      case 'plano':
        return MealPlanCard(perfil: perfil);
      case 'agua':
        return WaterCard(perfil: perfil, historico: historico);
      case 'peso':
        return WeightCard(perfil: perfil, historico: historico);
      case 'jejum':
        return FastingCard(perfil: perfil);
      default:
        return const SizedBox.shrink();
    }
  }

  void _mostrarInfoVidas(BuildContext context) {
    showDialog(
      context: context,
      useSafeArea: false, // Adicione esta linha para ignorar a barra de status
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            SizedBox.expand(
              child: Image.asset(
                'assets/vidas.jpeg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea( // Mantemos o SafeArea aqui embaixo para que o botão não fique sobre os botões de navegação do Android/iOS
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendi!',
                          style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'LilitaOne',
                              color: Colors.white,
                              letterSpacing: 1.5)),
                    ),
                  ),
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
    return StreamBuilder<DocumentSnapshot>(
        stream: _db.streamPerfilUsuario(),
        builder: (context, snapshotPerfil) {
          if (!snapshotPerfil.hasData || !snapshotPerfil.data!.exists) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          var perfilData = snapshotPerfil.data!.data();
          var perfil = perfilData != null
              ? Map<String, dynamic>.from(perfilData as Map)
              : <String, dynamic>{};
          int ofensiva = perfil['dias_ofensiva'] ?? 0;

          return StreamBuilder<DocumentSnapshot>(
            stream: _db.streamHistoricoHoje(),
            builder: (context, snapshotHistorico) {
              Map<String, dynamic>? historico;
              if (snapshotHistorico.hasData && snapshotHistorico.data!.exists) {
                var histData = snapshotHistorico.data!.data();
                if (histData != null) {
                  historico = Map<String, dynamic>.from(histData as Map);
                }
              }

              int vidas = calcularVidasMascote(historico);
              if (historico != null &&
                  (historico['teve_atividade'] == true) &&
                  ofensiva == 0) {
                ofensiva = 1;
              }

              return Scaffold(
                backgroundColor: AppTheme.backgroundWhite,
                floatingActionButton: FloatingActionButton(
                  backgroundColor: const Color(0xFFFF8D25),
                  onPressed: () => _abrirMenuAdicionar(perfil, historico),
                  child: const Icon(Icons.add, color: Colors.white, size: 30),
                ),
                body: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: _buildHeader(vidas, perfil, ofensiva)),
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final itemKey = _ordemCards[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child:
                                  _buildCardByKey(itemKey, perfil, historico),
                            );
                          },
                          childCount: _ordemCards.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 10.0),
                        child: TextButton.icon(
                          icon:
                              const Icon(Icons.swap_vert, color: Colors.grey),
                          label: const Text('Reorganizar Cards',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final novaOrdem = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ReorderCardsScreen(
                                      ordemAtual: _ordemCards, perfil: perfil)),
                            );
                            if (novaOrdem != null) {
                              _salvarOrdemCards(novaOrdem);
                            }
                          },
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              );
            },
          );
        });
  }

  Widget _buildHeader(int vidas, Map<String, dynamic> perfil, int ofensiva) {
    String nomeExibido = perfil['mascotName'] ?? widget.mascotName;
    String videoPath = _getMascotImage(vidas);

    double mascotScale = (videoPath == 'assets/mascote.mp4') ? 0.95 : 1.4;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 40),
      decoration: const BoxDecoration(
        color: Color(0xFFFF8D25), 
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _mostrarInfoVidas(context),
                child: Row(
                  children: List.generate(
                      4,
                      (index) => Icon(
                            index < vidas
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.white,
                            size: 28,
                          )),
                ),
              ),
              Row(
                children: [
                  FutureBuilder<int>(
                      future: _ofensivaFuture,
                      builder: (context, snapshot) {
                        int valorExato =
                            snapshot.hasData ? snapshot.data! : ofensiva;

                        return GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) => _OfensivaBottomSheet(
                                  ofensiva: valorExato),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department,
                                    color: Colors.yellow, size: 22),
                                const SizedBox(width: 4),
                                Text('$valorExato',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            ),
                          ),
                        );
                      }),
                  IconButton(
                    icon: const Icon(Icons.calendar_month,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => HistoryCalendarScreen(
                                  ordemCards: _ordemCards)));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings,
                        color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()));
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 170, 
                width: 170,  
                decoration: const BoxDecoration(
                    color: Colors.transparent, shape: BoxShape.circle),
                child: ClipOval(
                  child: MascotVideoPlayer(
                    videoPath: videoPath,
                    scale: mascotScale, 
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24), 
          GestureDetector(
            onDoubleTap: () => _editarNomeMascote(perfil),
            onTap: () => _editarNomeMascote(perfil),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(nomeExibido,
                    style: const TextStyle(
                        fontFamily: 'LilitaOne',
                        fontSize: 26,
                        color: Colors.white)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryCalendarScreen extends StatefulWidget {
  final List<String> ordemCards;
  const HistoryCalendarScreen({super.key, required this.ordemCards});

  @override
  State<HistoryCalendarScreen> createState() => _HistoryCalendarScreenState();
}

class _HistoryCalendarScreenState extends State<HistoryCalendarScreen> {
  final DatabaseService _db = DatabaseService();
  late DateTime _selectedDate;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  String _formatHeaderDate(DateTime date) {
    const weekDays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    const months = [
      'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'
    ];

    String wd = weekDays[date.weekday - 1];
    String m = months[date.month - 1];
    return "$wd., ${date.day} $m.";
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF8D25),
              onPrimary: Colors.white,
              onSurface: AppTheme.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _weekOffset = 0;
      });
    }
  }

  Widget _buildFastingHistoryCard(Map<String, dynamic>? historico) {
    List<dynamic> jejuns = [];
    if (historico != null && historico.containsKey('jejuns')) {
      if (historico['jejuns'] is List) {
        jejuns = historico['jejuns'];
      }
    }

    bool hasAnyJejumData = jejuns.isNotEmpty ||
        (historico != null && historico.containsKey('horas_jejum'));
    String horasJejum =
        historico != null && historico['horas_jejum'] != null
            ? historico['horas_jejum'].toString()
            : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer, color: Colors.indigo, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Histórico de Jejum',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!hasAnyJejumData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'Nenhum jejum registrado neste dia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            )
          else if (jejuns.isNotEmpty)
            ...jejuns.map((j) {
              String text = j is Map
                  ? (j['titulo'] ?? j['descricao'] ?? j.toString())
                  : j.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(text,
                            style: const TextStyle(
                                fontSize: 16, color: AppTheme.textDark))),
                  ],
                ),
              );
            }).toList()
          else if (horasJejum.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Text('Jejum concluído: $horasJejum horas',
                    style: const TextStyle(
                        fontSize: 16, color: AppTheme.textDark)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInteractiveCard(
      String key, Map<String, dynamic> perfil, Map<String, dynamic>? historico) {
    if (key == 'plano' || key == 'menstruacao') return const SizedBox.shrink();

    DateTime now = DateTime.now();
    bool isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    Widget card;
    switch (key) {
      case 'calorias':
        card = CaloriesCard(
            perfil: perfil, historico: historico, date: _selectedDate);
        break;
      case 'atividades':
        card = ActivityCardPreview(
            perfil: perfil, historico: historico, date: _selectedDate);
        break;
      case 'agua':
        card = WaterCard(
            perfil: perfil, historico: historico, date: _selectedDate);
        break;
      case 'peso':
        card = WeightCard(perfil: perfil, historico: historico, date: _selectedDate);
        break;
      case 'jejum':
        if (isToday) {
          card = FastingCard(perfil: perfil);
        } else {
          card = _buildFastingHistoryCard(historico);
        }
        break;
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundWhite,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: _db.streamPerfilUsuario(),
          builder: (context, snapshotPerfil) {
            if (!snapshotPerfil.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            var perfilData = snapshotPerfil.data?.data();
            var perfil = perfilData != null
                ? Map<String, dynamic>.from(perfilData as Map)
                : <String, dynamic>{};

            return StreamBuilder<DocumentSnapshot>(
              stream: _db.streamHistoricoPorData(_selectedDate),
              builder: (context, snapshotHistorico) {
                Map<String, dynamic>? historico;
                if (snapshotHistorico.hasData &&
                    snapshotHistorico.data!.exists) {
                  var histData = snapshotHistorico.data!.data();
                  if (histData != null) {
                    historico = Map<String, dynamic>.from(histData as Map);
                  }
                }

                List<String> cardsParaExibir = widget.ordemCards
                    .where((c) => c != 'plano' && c != 'menstruacao')
                    .toList();

                return Column(
                  children: [
                    _buildReferenceCalendar(),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        itemCount: cardsParaExibir.length,
                        itemBuilder: (context, index) {
                          return _buildInteractiveCard(
                              cardsParaExibir[index], perfil, historico);
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }),
    );
  }

  Widget _buildReferenceCalendar() {
    DateTime baseDate = _selectedDate.add(Duration(days: _weekOffset * 7));
    int weekday = baseDate.weekday;
    DateTime monday = baseDate.subtract(Duration(days: weekday - 1));
    List<DateTime> weekDays =
        List.generate(7, (index) => monday.add(Duration(days: index)));

    const dayLetters = ['s', 't', 'q', 'q', 's', 's', 'd'];
    DateTime currentDate = DateTime.now();
    DateTime todayCompare =
        DateTime(currentDate.year, currentDate.month, currentDate.day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Text(
                      _formatHeaderDate(_selectedDate),
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.black87),
                    onPressed: () => setState(() => _weekOffset--),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.chevron_right, color: Colors.black87),
                    onPressed: () => setState(() => _weekOffset++),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              DateTime date = weekDays[index];
              bool isSelected = date.year == _selectedDate.year &&
                  date.month == _selectedDate.month &&
                  date.day == _selectedDate.day;
              bool isToday = date.year == currentDate.year &&
                  date.month == currentDate.month &&
                  date.day == currentDate.day;

              DateTime loopDate = DateTime(date.year, date.month, date.day);
              bool isFuture = loopDate.isAfter(todayCompare);

              return GestureDetector(
                onTap: () {
                  if (isFuture) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Atenção',
                            style: TextStyle(
                                fontFamily: 'LilitaOne',
                                color: AppTheme.textDark)),
                        content: const Text(
                            'Não é possível selecionar dias futuros no calendário.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK',
                                style: TextStyle(
                                    color: Color(0xFFFF8D25),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _selectedDate = DateTime(date.year, date.month, date.day);
                    _weekOffset = 0;
                  });
                },
                child: Container(
                  width: 45,
                  height: 65,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.grey.shade200)
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLetters[index],
                        style: TextStyle(
                          color: isFuture
                              ? Colors.grey.shade300
                              : Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isFuture
                              ? Colors.grey.shade300
                              : (isSelected
                                  ? Colors.black87
                                  : Colors.grey.shade700),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isToday)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isFuture
                                ? Colors.grey.shade300
                                : Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        )
                      else
                        const SizedBox(height: 5),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String text;
  const _TypewriterText({Key? key, required this.text}) : super(key: key);

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  void _startTyping() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted && _currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'LilitaOne',
        fontSize: 18,
        color: Color(0xFFFF8D25),
      ),
    );
  }
}

class _OfensivaBottomSheet extends StatefulWidget {
  final int ofensiva;
  const _OfensivaBottomSheet({required this.ofensiva});

  @override
  State<_OfensivaBottomSheet> createState() => _OfensivaBottomSheetState();
}

class _OfensivaBottomSheetState extends State<_OfensivaBottomSheet> {
  List<DateTime> diasComAtividade = [];
  Set<DateTime> _diasAtivosSet = {};
  Set<DateTime> _diasOfensivaSet = {};
  late DateTime _mesExibido;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _mesExibido = DateTime(now.year, now.month);
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .collection('historico_diario')
            .get();

        Set<DateTime> datas = {};
        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['teve_atividade'] == true) {
            DateTime? dt;
            if (data['data_registro'] != null) {
              dt = (data['data_registro'] as Timestamp).toDate();
            } else {
              try {
                dt = DateTime.parse(doc.id);
              } catch (e) {
                print("erro ao fazer parse do id: ${doc.id}");
              }
            }
            if (dt != null) {
              datas.add(DateTime(dt.year, dt.month, dt.day));
            }
          }
        }

        Set<DateTime> ofensivaContinuos = _obterDiasOfensivaContinuos(datas);

        if (mounted) {
          setState(() {
            _diasAtivosSet = datas;
            _diasOfensivaSet = ofensivaContinuos;
            diasComAtividade = datas.toList();
          });
        }
      } catch (e) {
        print("Erro ao carregar historico da ofensiva: $e");
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Set<DateTime> _obterDiasOfensivaContinuos(Set<DateTime> datasAtivas) {
    DateTime agora = DateTime.now();
    DateTime hoje = DateTime(agora.year, agora.month, agora.day);
    DateTime ontem = hoje.subtract(const Duration(days: 1));

    DateTime dataCheck;
    if (datasAtivas.contains(hoje)) {
      dataCheck = hoje;
    } else if (datasAtivas.contains(ontem)) {
      dataCheck = ontem;
    } else {
      return {};
    }

    Set<DateTime> result = {};
    while (datasAtivas.contains(dataCheck)) {
      result.add(dataCheck);
      dataCheck = dataCheck.subtract(const Duration(days: 1));
    }
    return result;
  }

  int _calcularTotalOfensiva() {
    return _diasOfensivaSet.length;
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    int daysInMonth =
        DateUtils.getDaysInMonth(_mesExibido.year, _mesExibido.month);
    DateTime firstDayOfMonth =
        DateTime(_mesExibido.year, _mesExibido.month, 1);
    int firstWeekday = firstDayOfMonth.weekday;
    int emptySpaces = firstWeekday == 7 ? 0 : firstWeekday;

    const meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    String mesAtual = meses[_mesExibido.month - 1];
    int valorOfensiva = _loading ? widget.ofensiva : _calcularTotalOfensiva();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.orange, size: 40),
              const SizedBox(width: 10),
              Text(
                '$valorOfensiva',
                style: const TextStyle(
                    fontFamily: 'LilitaOne',
                    fontSize: 40,
                    color: Colors.orange),
              ),
            ],
          ),
          const Text(
            'Dias de Ofensiva!',
            style: TextStyle(
                fontFamily: 'LilitaOne',
                fontSize: 22,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          _TypewriterText(
            text: valorOfensiva > 0
                ? 'Parabéns! Continue no seu objetivo'
                : 'Você consegue! Registre diariamente e mantenha o ritmo',
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left,
                                color: AppTheme.textDark),
                            onPressed: () {
                              setState(() {
                                _mesExibido = DateTime(_mesExibido.year,
                                    _mesExibido.month - 1);
                              });
                            },
                          ),
                          Text(
                            '$mesAtual de ${_mesExibido.year}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.textDark),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right,
                                color: AppTheme.textDark),
                            onPressed: () {
                              setState(() {
                                _mesExibido = DateTime(_mesExibido.year,
                                    _mesExibido.month + 1);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                            .map((dia) => SizedBox(
                                width: 30,
                                child: Text(dia,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.bold))))
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemCount: daysInMonth + emptySpaces,
                        itemBuilder: (context, index) {
                          if (index < emptySpaces)
                            return const SizedBox.shrink();

                          int day = index - emptySpaces + 1;
                          DateTime dataDoMes = DateTime(
                              _mesExibido.year, _mesExibido.month, day);

                          bool isAtivo = _diasAtivosSet.contains(dataDoMes);
                          bool isOfensiva = _diasOfensivaSet.contains(dataDoMes);
                          bool isHoje = dataDoMes.year == now.year &&
                              dataDoMes.month == now.month &&
                              dataDoMes.day == now.day;

                          Color corFundo = Colors.transparent;
                          if (isOfensiva) {
                            corFundo = Colors.orange;
                          } else if (isAtivo) {
                            corFundo = Colors.orange.shade100;
                          }

                          return Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: corFundo,
                              border: isHoje && !isAtivo
                                  ? Border.all(color: Colors.orange, width: 2)
                                  : null,
                            ),
                            child: isOfensiva
                                ? const Icon(Icons.local_fire_department,
                                    color: Colors.white, size: 20)
                                : isAtivo
                                    ? Icon(Icons.local_fire_department,
                                        color: Colors.orange.shade800,
                                        size: 20)
                                    : Text(
                                        '$day',
                                        style: TextStyle(
                                          fontWeight: isHoje
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isHoje
                                              ? Colors.orange
                                              : AppTheme.textDark,
                                        ),
                                      ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              const Text('Ofensiva',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 4),
                              const Text('Uso anterior',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8D25),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('CONTINUAR',
                  style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'LilitaOne',
                      color: Colors.white,
                      letterSpacing: 1.5)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class ReorderCardsScreen extends StatefulWidget {
  final List<String> ordemAtual;
  final Map<String, dynamic>? perfil;

  const ReorderCardsScreen({super.key, required this.ordemAtual, this.perfil});

  @override
  State<ReorderCardsScreen> createState() => _ReorderCardsScreenState();
}

class _ReorderCardsScreenState extends State<ReorderCardsScreen> {
  late List<String> _tempOrdem;

  final Map<String, Map<String, dynamic>> _cardInfos = {
    'menstruacao': {
      'titulo': 'Ciclo Menstrual',
      'icone': Icons.water_drop,
      'cor': Colors.pinkAccent
    },
    'calorias': {
      'titulo': 'Calorias e Refeições',
      'icone': Icons.local_dining,
      'cor': Colors.orange
    },
    'atividades': {
      'titulo': 'Atividades Físicas',
      'icone': Icons.directions_run,
      'cor': Colors.green
    },
    'plano': {
      'titulo': 'Plano Alimentar',
      'icone': Icons.menu_book,
      'cor': Colors.redAccent
    },
    'agua': {
      'titulo': 'Água',
      'icone': Icons.water_drop,
      'cor': Colors.blue
    },
    'peso': {
      'titulo': 'Peso',
      'icone': Icons.monitor_weight,
      'cor': Colors.purple
    },
    'jejum': {
      'titulo': 'Jejum Intermitente',
      'icone': Icons.timer,
      'cor': Colors.indigo
    },
  };

  bool _isFeminino() {
    if (widget.perfil == null) return true;
    final sexo = (widget.perfil!['sexo'] ?? widget.perfil!['genero'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    return sexo == 'f' || sexo == 'feminino' || sexo == 'female';
  }

  @override
  void initState() {
    super.initState();
    _tempOrdem = List.from(widget.ordemAtual);

    if (!_isFeminino()) {
      _tempOrdem.remove('menstruacao');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Reorganizar Cards',
            style: TextStyle(
                fontFamily: 'LilitaOne', color: AppTheme.textDark)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _tempOrdem),
            child: const Text('Salvar',
                style: TextStyle(
                    color: Color(0xFFFF8D25),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          )
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tempOrdem.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = _tempOrdem.removeAt(oldIndex);
            _tempOrdem.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final key = _tempOrdem[index];
          final info = _cardInfos[key] ??
              {
                'titulo': key,
                'icone': Icons.extension,
                'cor': Colors.grey
              };

          return Container(
            key: ValueKey(key),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 5,
                    offset: const Offset(0, 3))
              ],
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: (info['cor'] as Color).withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(info['icone'], color: info['cor']),
              ),
              title: Text(info['titulo'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              trailing: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

class MascotVideoPlayer extends StatefulWidget {
  final String videoPath;
  final double scale; 

  const MascotVideoPlayer({
    Key? key,
    required this.videoPath,
    this.scale = 1.4,
  }) : super(key: key);

  @override
  State<MascotVideoPlayer> createState() => _MascotVideoPlayerState();
}

class _MascotVideoPlayerState extends State<MascotVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initController(widget.videoPath);
  }

  void _initController(String path) {
    _controller = VideoPlayerController.asset(path)
      ..setVolume(0.0) 
      ..setLooping(true) 
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play(); 
        }
      }).catchError((_) {
        print("Erro ao carregar o vídeo do mascote: $path");
      });
  }

  @override
  void didUpdateWidget(MascotVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller.dispose();
      _initialized = false;
      _initController(widget.videoPath);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: Icon(Icons.pets, size: 60, color: Color(0xFFFF8D25)),
      );
    }

    return SizedBox.expand(
      child: Transform.scale(
        scale: widget.scale, 
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}