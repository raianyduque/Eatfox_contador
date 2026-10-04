//card de atividades fisicas, contabiliza e exclui.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_theme.dart';
import '../../../services/database_service.dart';

const List<Map<String, dynamic>> atividadesBase = [
  {'nome': 'Caminhada Leve', 'met': 3.0, 'icone': Icons.directions_walk},
  {'nome': 'Caminhada Rápida', 'met': 4.3, 'icone': Icons.directions_walk},
  {'nome': 'Corrida Leve', 'met': 8.0, 'icone': Icons.directions_run},
  {'nome': 'Corrida Intensa', 'met': 11.0, 'icone': Icons.directions_run},
  {'nome': 'Musculação', 'met': 4.5, 'icone': Icons.fitness_center},
  {'nome': 'CrossFit', 'met': 8.5, 'icone': Icons.fitness_center},
  {'nome': 'Ciclismo', 'met': 7.5, 'icone': Icons.directions_bike},
  {'nome': 'Natação', 'met': 7.0, 'icone': Icons.pool},
  {'nome': 'Pilates', 'met': 3.0, 'icone': Icons.self_improvement},
  {'nome': 'Yoga', 'met': 2.5, 'icone': Icons.self_improvement},
  {'nome': 'HIIT', 'met': 9.0, 'icone': Icons.local_fire_department},
  {'nome': 'Dança', 'met': 5.0, 'icone': Icons.music_note},
  {'nome': 'Futebol', 'met': 7.0, 'icone': Icons.sports_soccer},
  {'nome': 'Basquete', 'met': 6.5, 'icone': Icons.sports_basketball},
  {'nome': 'Vôlei', 'met': 4.0, 'icone': Icons.sports_volleyball},
  {'nome': 'Tênis', 'met': 7.3, 'icone': Icons.sports_tennis},
  {'nome': 'Boxe', 'met': 8.0, 'icone': Icons.sports_mma},
  {'nome': 'Muay Thai', 'met': 8.5, 'icone': Icons.sports_mma},
  {'nome': 'Jiu-Jitsu', 'met': 7.5, 'icone': Icons.sports_martial_arts},
  {'nome': 'Judô', 'met': 7.0, 'icone': Icons.sports_martial_arts},
  {'nome': 'Funcional', 'met': 6.0, 'icone': Icons.accessibility_new},
  {'nome': 'Pular Corda', 'met': 10.0, 'icone': Icons.sync},
  {'nome': 'Andar de Patins', 'met': 7.0, 'icone': Icons.roller_skating},
  {'nome': 'Skate', 'met': 5.0, 'icone': Icons.skateboarding},
  {'nome': 'Surf', 'met': 3.0, 'icone': Icons.surfing},
  {'nome': 'Escalada', 'met': 8.0, 'icone': Icons.terrain},
  {'nome': 'Remo', 'met': 6.0, 'icone': Icons.rowing},
  {'nome': 'Ginástica Olímpica', 'met': 4.0, 'icone': Icons.sports_gymnastics},
  {'nome': 'Ginástica Rítmica', 'met': 4.5, 'icone': Icons.sports_gymnastics},
  {'nome': 'Alongamento', 'met': 2.3, 'icone': Icons.accessibility},
  {'nome': 'Zumba', 'met': 5.5, 'icone': Icons.music_video},
  {'nome': 'Step', 'met': 7.5, 'icone': Icons.stairs},
  {'nome': 'Hidroginástica', 'met': 5.5, 'icone': Icons.pool},
  {'nome': 'Polo Aquático', 'met': 10.0, 'icone': Icons.sports},
  {'nome': 'Handebol', 'met': 8.0, 'icone': Icons.sports_handball},
  {'nome': 'Futsal', 'met': 8.0, 'icone': Icons.sports_soccer},
  {'nome': 'Rugby', 'met': 8.3, 'icone': Icons.sports_rugby},
  {'nome': 'Futebol Americano', 'met': 8.0, 'icone': Icons.sports_football},
  {'nome': 'Beisebol', 'met': 5.0, 'icone': Icons.sports_baseball},
  {'nome': 'Softbol', 'met': 5.0, 'icone': Icons.sports_baseball},
  {'nome': 'Atletismo', 'met': 7.0, 'icone': Icons.run_circle},
  {'nome': 'Triatlo', 'met': 9.0, 'icone': Icons.directions_run},
  {'nome': 'Badminton', 'met': 5.5, 'icone': Icons.sports_tennis},
  {'nome': 'Tênis de Mesa', 'met': 4.0, 'icone': Icons.sports_tennis},
  {'nome': 'Squash', 'met': 7.3, 'icone': Icons.sports_tennis},
  {'nome': 'Golfe', 'met': 4.8, 'icone': Icons.sports_golf},
  {'nome': 'Artes Marciais (MMA)', 'met': 9.0, 'icone': Icons.sports_mma},
  {'nome': 'Karatê', 'met': 7.0, 'icone': Icons.sports_martial_arts},
  {'nome': 'Taekwondo', 'met': 7.5, 'icone': Icons.sports_martial_arts},
  {'nome': 'Capoeira', 'met': 7.5, 'icone': Icons.sports_martial_arts},
  {'nome': 'Esgrima', 'met': 6.0, 'icone': Icons.sports},
];

class ActivityCardPreview extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final Map<String, dynamic>? historico;
  final DateTime? date;
  
  const ActivityCardPreview({super.key, required this.perfil, required this.historico, this.date});

  @override
  State<ActivityCardPreview> createState() => _ActivityCardPreviewState();

  static void abrirBusca(BuildContext context, DatabaseService db, double peso, {DateTime? date}) {
    String pesquisa = '';
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtradas = atividadesBase.where((a) => a['nome'].toString().toLowerCase().contains(pesquisa.toLowerCase())).toList();
          return Container(
            padding: const EdgeInsets.all(24),
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                const Text('Escolha a Atividade', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar...', prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onChanged: (val) => setModalState(() => pesquisa = val),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtradas.length,
                    itemBuilder: (context, index) {
                      final item = filtradas[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 2))],
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: Icon(item['icone'], color: Colors.green)),
                          title: Text(item['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey), 
                          onTap: () {
                            Navigator.pop(context);
                            _abrirDetalhesAtividade(context, item, db, peso, date: date);
                          }
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  static void _abrirDetalhesAtividade(BuildContext context, Map<String, dynamic> atividade, DatabaseService db, double peso, {DateTime? date}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _ActivityDetailSheet(atividade: atividade, db: db, peso: peso, date: date),
    );
  }
}

class _ActivityCardPreviewState extends State<ActivityCardPreview> {
  final DatabaseService _db = DatabaseService();

  void _abrirHistoricoAtividades() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    DateTime baseDate = widget.date ?? DateTime.now();
    DateTime inicioDia = DateTime(baseDate.year, baseDate.month, baseDate.day);
    DateTime fimDia = inicioDia.add(const Duration(days: 1));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('Histórico Deste Dia', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 22)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(user.uid)
                    .collection('atividades')
                    .where('data', isGreaterThanOrEqualTo: inicioDia)
                    .where('data', isLessThan: fimDia) 
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('Nenhuma atividade registrada neste dia.', style: TextStyle(color: Colors.grey)));
                  }
                  
                  var docs = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var item = doc.data() as Map<String, dynamic>;
                      String docId = doc.id;
                      
                      int cals = (item['calorias'] ?? item['calories'] ?? 0) as int;
                      int minutos = (item['minutos'] ?? 0) as int;
                      String nome = item['nome'] ?? 'Atividade';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.fitness_center, color: Colors.green),
                          ),
                          title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('$minutos min - $cals kcal', style: const TextStyle(color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              _removerAtividadeItem(docId, cals);
                            },
                          ),
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
    );
  }

  Future<void> _removerAtividadeItem(String docId, int caloriasItem) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(user.uid)
        .collection('atividades')
        .doc(docId)
        .delete();
        
    String dataStr = (widget.date ?? DateTime.now()).toIso8601String().split('T')[0];
    
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('historico_diario')
          .doc(dataStr)
          .update({
        'calorias_gastas': FieldValue.increment(-caloriasItem),
      });
    } catch (e) {
      try {
         await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('historicos')
          .doc(dataStr)
          .update({
            'calorias_gastas': FieldValue.increment(-caloriasItem),
          });
      } catch (e2) {}
    }
  }

  Future<void> _zerarAtividadesDesteDia() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    DateTime baseDate = widget.date ?? DateTime.now();
    DateTime inicioDia = DateTime(baseDate.year, baseDate.month, baseDate.day);
    DateTime fimDia = inicioDia.add(const Duration(days: 1));

    try {
      
      var snapshots = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('atividades')
          .where('data', isGreaterThanOrEqualTo: inicioDia)
          .where('data', isLessThan: fimDia)
          .get();

 
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }

      _db.zerarAtividades(data: widget.date);
    } catch (e) {
      debugPrint('Erro ao zerar o histórico de atividades: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    dynamic gastasRaw = widget.historico?['calorias_gastas'] ?? widget.historico?['caloriasGastas'] ?? 0;
    int kcalGastas = (gastasRaw is num) ? gastasRaw.toInt() : (int.tryParse(gastasRaw.toString()) ?? 0);
    dynamic metaRaw = widget.perfil['metaAtividade'] ?? 
                      widget.historico??['metaAtividade'] ?? 
                      300;                  
    int metaKcalGastas = (metaRaw is num) ? metaRaw.toInt() : (int.tryParse(metaRaw.toString()) ?? 300);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.pureWhite, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.directions_run, color: Colors.green, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Atividades Físicas', style: TextStyle(fontFamily: 'LilitaOne', fontSize: 18, color: AppTheme.textDark), overflow: TextOverflow.ellipsis),
                          Text('$kcalGastas / $metaKcalGastas kcal gastas', style: const TextStyle(fontSize: 12, color: AppTheme.textGray), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    color: Colors.white, 
                    surfaceTintColor: Colors.white, 
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    onSelected: (value) {
                      if (value == 'zerar') {
                        _zerarAtividadesDesteDia(); // Chamada do novo método aqui
                      } else if (value == 'historico') {
                        _abrirHistoricoAtividades();
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem(
                        value: 'historico',
                        child: Row(
                          children: [
                            Icon(Icons.history, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text('Histórico de Atividades'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'zerar',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Zerar Atividades', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => ActivityCardPreview.abrirBusca(context, _db, (widget.perfil['peso'] as num).toDouble(), date: widget.date),
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
        ],
      ),
    );
  }
}

class _ActivityDetailSheet extends StatefulWidget {
  final Map<String, dynamic> atividade;
  final DatabaseService db;
  final double peso;
  final DateTime? date;

  const _ActivityDetailSheet({required this.atividade, required this.db, required this.peso, this.date});

  @override
  State<_ActivityDetailSheet> createState() => _ActivityDetailSheetState();
}

class _ActivityDetailSheetState extends State<_ActivityDetailSheet> {
  int _minutos = 30;

  @override
  Widget build(BuildContext context) {
    final double kcalMin = ((widget.atividade['met'] as num).toDouble() * widget.peso * 3.5) / 200;
    double kcalTotal = _minutos * kcalMin;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40, backgroundColor: Colors.green.withOpacity(0.1), 
              child: Icon(widget.atividade['icone'], size: 40, color: Colors.green)
            ),
            const SizedBox(height: 16),
            Text(widget.atividade['nome'], style: const TextStyle(fontFamily: 'LilitaOne', fontSize: 24)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [15, 30, 60].map((min) => ChoiceChip(
                label: Text('$min min'),
                selected: _minutos == min,
                onSelected: (val) => setState(() => _minutos = min),
                selectedColor: Colors.green.withOpacity(0.2),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Ou digite o tempo (min)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              onChanged: (val) => setState(() => _minutos = int.tryParse(val) ?? 0),
            ),
            const SizedBox(height: 24),
            Text('${kcalTotal.toStringAsFixed(0)} kcal perdidas', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green)),
            Text('${kcalMin.toStringAsFixed(1)} kcal por minuto', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  widget.db.registrarAtividade(widget.atividade['nome'], _minutos, kcalTotal.round(), data: widget.date);
                  Navigator.pop(context);
                },
                child: const Text('Registrar', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}