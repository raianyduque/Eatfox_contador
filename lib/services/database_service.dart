// conexao com o banco de dados, firebase do google.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> salvarPerfilUsuario(Map<String, dynamic> dadosPerfil) async {
    User? user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      await _firestore.collection('usuarios').doc(user.uid).set(dadosPerfil, SetOptions(merge: true));
    }
  }

  Future<DocumentSnapshot> buscarPerfilUsuario() async {
    User? user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) throw Exception('Usuário não autenticado');
    return await _firestore.collection('usuarios').doc(user.uid).get();
  }

  Stream<DocumentSnapshot> streamPerfilUsuario() {
    User? user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) return const Stream.empty();
    return _firestore.collection('usuarios').doc(user.uid).snapshots();
  }

  Future<void> atualizarPeso(double novoPeso, {DateTime? data}) async {
    User? user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      await _firestore.collection('usuarios').doc(user.uid).update({'peso': novoPeso});

     
      DateTime dataReferencia = data ?? DateTime.now();
      String diaPeso = dataReferencia.toIso8601String().split('T')[0];

      await _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(diaPeso).set({
        'peso': novoPeso,
        'teve_atividade': true,
        'data_registro': Timestamp.fromDate(dataReferencia)
      }, SetOptions(merge: true));
    }
  }

  Future<void> adicionarRefeicao(Map<String, dynamic> dadosRefeicao, {DateTime? data}) async {
    User? user = _auth.currentUser;
    DateTime dataReferencia = data ?? DateTime.now();
    String diaRefeicao = dataReferencia.toIso8601String().split('T')[0];
    
    if (user != null && user.uid.isNotEmpty) {
      await _firestore.collection('usuarios').doc(user.uid).collection('refeicoes').add({
        ...dadosRefeicao,
        'data': Timestamp.fromDate(dataReferencia),
        'dia_ref': diaRefeicao,
      });
      
      final docDiario = _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(diaRefeicao);
      
      await docDiario.set({
        'calorias_consumidas': FieldValue.increment((dadosRefeicao['calorias'] as num?)?.toInt() ?? 0),
        'proteina_consumida': FieldValue.increment((dadosRefeicao['proteinas'] as num?)?.toInt() ?? 0),
        'carbo_consumida': FieldValue.increment((dadosRefeicao['carboidratos'] as num?)?.toInt() ?? 0),
        'gordura_consumida': FieldValue.increment((dadosRefeicao['gorduras'] as num?)?.toInt() ?? 0),
        'fibra_consumida': FieldValue.increment((dadosRefeicao['fibras'] as num?)?.toInt() ?? 0),
        'teve_atividade': true,
        'data_registro': Timestamp.fromDate(dataReferencia)
      }, SetOptions(merge: true));
    }
  }

  Future<void> registrarAtividade(String nome, int minutos, int caloriasGastas, {DateTime? data}) async {
    User? user = _auth.currentUser;
    DateTime dataReferencia = data ?? DateTime.now();
    String diaAtividade = dataReferencia.toIso8601String().split('T')[0];
    
    if (user != null && user.uid.isNotEmpty) {
      await _firestore.collection('usuarios').doc(user.uid).collection('atividades').add({
        'nome': nome,
        'minutos': minutos,
        'calorias': caloriasGastas,
        'data': Timestamp.fromDate(dataReferencia),
      });
      final docDiario = _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(diaAtividade);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docDiario);
        int gastoAtual = snapshot.exists && snapshot.data()!.containsKey('calorias_gastas') ? snapshot.get('calorias_gastas') : 0;
        transaction.set(docDiario, {
            'calorias_gastas': gastoAtual + caloriasGastas,
            'teve_atividade': true,
            'data_registro': Timestamp.fromDate(dataReferencia)
        }, SetOptions(merge: true));
      });
    }
  }

  Future<void> adicionarAgua(int mlAdicional, {DateTime? data}) async {
    User? user = _auth.currentUser;
    DateTime dataReferencia = data ?? DateTime.now();
    String diaAgua = dataReferencia.toIso8601String().split('T')[0];
    
    if (user != null && user.uid.isNotEmpty) {
      final docRef = _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(diaAgua);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        int aguaAtual = snapshot.exists && snapshot.data()!.containsKey('agua_ml') ? snapshot.get('agua_ml') : 0;
        transaction.set(docRef, {
            'agua_ml': aguaAtual + mlAdicional,
            'teve_atividade': true,
            'data_registro': Timestamp.fromDate(dataReferencia)
        }, SetOptions(merge: true));
      });
    }
  }

  Stream<DocumentSnapshot> streamHistoricoHoje() {
    User? user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) return const Stream.empty();
    String hoje = DateTime.now().toIso8601String().split('T')[0];
    return _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(hoje).snapshots();
  }

  Stream<DocumentSnapshot> streamHistoricoPorData(DateTime data) {
    User? user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) return const Stream.empty();
    String dataFormatada = data.toIso8601String().split('T')[0];
    return _firestore.collection('usuarios').doc(user.uid).collection('historico_diario').doc(dataFormatada).snapshots();
  }

  Future<void> atualizarPerfil(Map<String, dynamic> dados) async {
    final user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      await _firestore.collection('usuarios').doc(user.uid).update(dados);
    }
  }

  Future<void> zerarAtividades({DateTime? data}) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid.isEmpty) return;
      String uid = user.uid;
      
      DateTime dataReferencia = data ?? DateTime.now();
      String diaZerar = dataReferencia.toIso8601String().split('T')[0]; 

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .collection('historico_diario') 
          .doc(diaZerar)
          .update({
        'calorias_gastas': 0, 
      });

      print("Atividades zeradas com sucesso!");
    } catch (e) {
      print("Erro ao zerar atividades: $e");
    }
  }


  Future<void> salvarDadosMenstruacao(Map<String, dynamic> dados) async {
    User? user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .collection('saude_feminina')
          .doc('ciclo')
          .set(dados, SetOptions(merge: true));
    }
  }

  Stream<DocumentSnapshot> streamDadosMenstruacao() {
    User? user = _auth.currentUser;
    if (user == null || user.uid.isEmpty) return const Stream.empty();
    return _firestore
        .collection('usuarios')
        .doc(user.uid)
        .collection('saude_feminina')
        .doc('ciclo')
        .snapshots();
  }
}