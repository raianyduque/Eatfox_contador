// card de ciclo menstrual, dias ferteis, ovulaçao, menstruaçao, registra o ciclo com opçao de calendario.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../services/database_service.dart';

class MenstrualColors {
  static const Color primary = Color(0xFFFF8C69); 
  static const Color lightBg = Color(0xFFFFF5F2); 
  static const Color border = Color(0xFFFFD5CB);  
  static const Color darkText = Color(0xFFB34730); 
  static const Color highlight = Color(0xFFFFAE99); 
}

class MenstruationCard extends StatefulWidget {
  final Map<String, dynamic> perfil;

  const MenstruationCard({super.key, required this.perfil});

  @override
  State<MenstruationCard> createState() => _MenstruationCardState();
}

class _MenstruationCardState extends State<MenstruationCard> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _esconderPergunta = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _isFeminino() {
    final sexo = (widget.perfil['sexo'] ?? widget.perfil['genero'] ?? '').toString().toLowerCase().trim();
    return sexo == 'f' || sexo == 'feminino' || sexo == 'female';
  }

  void _abrirModalConfiguracaoInicial(BuildContext context, Map<String, dynamic>? dadosAtuais) {
    DateTime? selectedDum = dadosAtuais?['dum'] != null 
        ? (dadosAtuais!['dum'] as Timestamp).toDate() 
        : DateTime.now();
    int duracaoCiclo = dadosAtuais?['duracao_ciclo'] ?? 28;
    int duracaoMenstruacao = dadosAtuais?['duracao_menstruacao'] ?? 5;

    final cicloController = TextEditingController(text: duracaoCiclo.toString());
    final menstruacaoController = TextEditingController(text: duracaoMenstruacao.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      CircleAvatar(
                        backgroundColor: MenstrualColors.lightBg,
                        child: Icon(Icons.water_drop, color: MenstrualColors.primary),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Iniciar Registro Menstrual',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 20,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '1º dia da última menstruação:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDum ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: MenstrualColors.primary,
                                onPrimary: Colors.white,
                                onSurface: AppTheme.textDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDum = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: MenstrualColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MenstrualColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDum != null
                                ? DateFormat('dd/MM/yyyy').format(selectedDum!)
                                : 'Selecionar data',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Icon(Icons.calendar_today, color: MenstrualColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duração do Ciclo:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: cicloController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'dias',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: MenstrualColors.primary, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Duração Sangramento:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: menstruacaoController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                suffixText: 'dias',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: MenstrualColors.primary, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MenstrualColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (selectedDum == null) return;
                        int c = int.tryParse(cicloController.text) ?? 28;
                        int m = int.tryParse(menstruacaoController.text) ?? 5;

                        await _db.salvarDadosMenstruacao({
                          'dum': Timestamp.fromDate(selectedDum!),
                          'duracao_ciclo': c,
                          'duracao_menstruacao': m,
                          'configurado': true,
                          'historico_dum': FieldValue.arrayUnion([Timestamp.fromDate(selectedDum!)]),
                        });

                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'SALVAR E CONTINUAR',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirModalEdicao(BuildContext context, Map<String, dynamic> dadosAtuais, DateTime dumAtualCalculado) {
    DateTime? selectedDumBase = (dadosAtuais['dum'] as Timestamp).toDate();
    DateTime? selectedDumAtual = dumAtualCalculado;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      CircleAvatar(
                        backgroundColor: MenstrualColors.lightBg,
                        child: Icon(Icons.edit_calendar, color: MenstrualColors.primary),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Editar Datas',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 20,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  const Text(
                    'Corrigir início deste ciclo atual:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDumAtual ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: MenstrualColors.primary,
                                onPrimary: Colors.white,
                                onSurface: AppTheme.textDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDumAtual = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: MenstrualColors.lightBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MenstrualColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDumAtual != null
                                ? DateFormat('dd/MM/yyyy').format(selectedDumAtual!)
                                : 'Selecionar data',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Icon(Icons.calendar_today, color: MenstrualColors.primary, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MenstrualColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (selectedDumAtual == null) return;
                        
                        await _db.salvarDadosMenstruacao({
                          'dum': Timestamp.fromDate(selectedDumAtual!),
                          'historico_dum': FieldValue.arrayUnion([Timestamp.fromDate(selectedDumAtual!)]),
                        });

                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Início do ciclo atualizado com sucesso!'),
                              backgroundColor: MenstrualColors.primary,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'SALVAR CICLO ATUAL',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),

                  const Text(
                    'Ou alterar 1º dia do registro base:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDumBase ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: MenstrualColors.primary,
                                onPrimary: Colors.white,
                                onSurface: AppTheme.textDark,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() {
                          selectedDumBase = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MenstrualColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDumBase != null
                                ? DateFormat('dd/MM/yyyy').format(selectedDumBase!)
                                : 'Selecionar data',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: MenstrualColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (selectedDumBase == null) return;
                        
                        await _db.salvarDadosMenstruacao({
                          'dum': Timestamp.fromDate(selectedDumBase!),
                          'historico_dum': FieldValue.arrayUnion([Timestamp.fromDate(selectedDumBase!)]),
                        });

                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Registro base atualizado com sucesso!'),
                              backgroundColor: MenstrualColors.primary,
                            ),
                          );
                        }
                      },
                      child: const Text(
                        'SALVAR REGISTRO BASE',
                        style: TextStyle(
                          fontFamily: 'LilitaOne',
                          fontSize: 14,
                          color: MenstrualColors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: const Text(
                        'Redefinir ciclo completamente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await _db.salvarDadosMenstruacao({'configurado': false});
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _calcularCiclo(DateTime dum, int duracaoCiclo, int duracaoMenstruacao, DateTime dataAlvo) {
    DateTime dataAjustadaAlvo = DateTime(dataAlvo.year, dataAlvo.month, dataAlvo.day);
    DateTime dumBase = DateTime(dum.year, dum.month, dum.day);

    int diasDiferenca = dataAjustadaAlvo.difference(dumBase).inDays;
    int ciclosDecorridos = (diasDiferenca / duracaoCiclo).floor();
    
    if (diasDiferenca < 0) ciclosDecorridos = 0;

    DateTime dumAtual = dumBase.add(Duration(days: ciclosDecorridos * duracaoCiclo));
    DateTime proximaMenstruacao = dumAtual.add(Duration(days: duracaoCiclo));
    DateTime diaOvulacao = proximaMenstruacao.subtract(const Duration(days: 14));

    int diaDoCiclo = dataAjustadaAlvo.difference(dumAtual).inDays + 1;

    String probabilidade = 'Baixa';
    int diffOvulacao = dataAjustadaAlvo.difference(diaOvulacao).inDays;

    if (diffOvulacao == 0 || diffOvulacao == -1) {
      probabilidade = 'Alta';
    } else if ((diffOvulacao >= -5 && diffOvulacao <= -2) || diffOvulacao == 1) {
      probabilidade = 'Média';
    } else {
      probabilidade = 'Baixa';
    }

    bool isMenstruando = dataAjustadaAlvo.difference(dumAtual).inDays >= 0 &&
        dataAjustadaAlvo.difference(dumAtual).inDays < duracaoMenstruacao;

    bool isFertil = probabilidade == 'Alta' || probabilidade == 'Média';

    return {
      'dumAtual': dumAtual,
      'proximaMenstruacao': proximaMenstruacao,
      'diaOvulacao': diaOvulacao,
      'diaDoCiclo': diaDoCiclo,
      'probabilidade': probabilidade,
      'isMenstruando': isMenstruando,
      'isFertil': isFertil,
      'ciclosDecorridos': ciclosDecorridos,
    };
  }

  // ignore: unused_element
  void _registrarMenstruacaoHoje(DateTime dumAtual) async {
    DateTime hoje = DateTime.now();
    DateTime hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

    await _db.salvarDadosMenstruacao({
      'dum': Timestamp.fromDate(hojeZerado),
      'historico_dum': FieldValue.arrayUnion([Timestamp.fromDate(hojeZerado)]),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Menstruação registrada para hoje!'),
          backgroundColor: MenstrualColors.primary,
        ),
      );
    }
  }

  void _abrirCalendarioCompleto(
    BuildContext context,
    DateTime dum,
    int duracaoCiclo,
    int duracaoMenstruacao,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _MenstrualCalendarModal(
          dum: dum,
          duracaoCiclo: duracaoCiclo,
          duracaoMenstruacao: duracaoMenstruacao,
          calcularCiclo: _calcularCiclo,
          db: _db,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFeminino()) {
      return const SizedBox.shrink();
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: StreamBuilder<DocumentSnapshot>(
        stream: _db.streamDadosMenstruacao(),
        builder: (context, snapshot) {
          Map<String, dynamic>? dados;
          if (snapshot.hasData && snapshot.data!.exists) {
            dados = snapshot.data!.data() as Map<String, dynamic>?;
          }

          bool configurado = dados?['configurado'] ?? false;

          if (!configurado) {
            return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: MenstrualColors.border.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: MenstrualColors.border),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: FloweryBackground()), 
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: MenstrualColors.lightBg,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.water_drop, color: MenstrualColors.primary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ciclo Menstrual',
                                    style: TextStyle(
                                      fontFamily: 'LilitaOne',
                                      fontSize: 20,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  Text(
                                    'Acompanhe seu ciclo e fertilidade',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MenstrualColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            label: const Text(
                              'Iniciar registro menstrual',
                              style: TextStyle(
                                fontFamily: 'LilitaOne',
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => _abrirModalConfiguracaoInicial(context, dados),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          DateTime dum = (dados!['dum'] as Timestamp).toDate();
          int duracaoCiclo = dados['duracao_ciclo'] ?? 28;
          int duracaoMenstruacao = dados['duracao_menstruacao'] ?? 5;

          DateTime hoje = DateTime.now();
          DateTime hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

          Map<String, dynamic> calcHoje = _calcularCiclo(dum, duracaoCiclo, duracaoMenstruacao, hojeZerado);
          DateTime proximaMenstruacao = calcHoje['proximaMenstruacao'];
          int diasParaProxima = proximaMenstruacao.difference(hojeZerado).inDays;
         
          bool estaAtrasada = diasParaProxima < 0 && !calcHoje['isMenstruando'];
          int diasAtraso = estaAtrasada ? diasParaProxima.abs() : 0;
          bool cicloDesregulado = diasAtraso > 7;
          
          bool isMenstruandoHoje = calcHoje['isMenstruando'];
          int ciclosDecorridos = calcHoje['ciclosDecorridos'] ?? 0;
          
          bool ignorouHoje = false;
          if (dados['data_ultima_pergunta_ignorada'] != null) {
            DateTime dataIgnorada = (dados['data_ultima_pergunta_ignorada'] as Timestamp).toDate();
            if (dataIgnorada.year == hojeZerado.year &&
                dataIgnorada.month == hojeZerado.month &&
                dataIgnorada.day == hojeZerado.day) {
              ignorouHoje = true;
            }
          }

          bool noPeriodoEsperado = ((isMenstruandoHoje && ciclosDecorridos > 0) || (diasParaProxima <= 3 && diasParaProxima >= 0) || estaAtrasada) && !_esconderPergunta && !ignorouHoje;

          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: MenstrualColors.border.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: MenstrualColors.border),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: FloweryBackground()), 
                Padding(
                  padding: const EdgeInsets.all(20),
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
                                decoration: BoxDecoration(
                                  color: MenstrualColors.lightBg,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.water_drop, color: MenstrualColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Ciclo Menstrual',
                                style: TextStyle(
                                  fontFamily: 'LilitaOne',
                                  fontSize: 20,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: MenstrualColors.lightBg,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.calendar_month, color: MenstrualColors.primary, size: 22),
                            ),
                            onPressed: () => _abrirCalendarioCompleto(
                              context,
                              dum,
                              duracaoCiclo,
                              duracaoMenstruacao,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (estaAtrasada) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cicloDesregulado
                                      ? 'Atenção: Menstruação atrasada em $diasAtraso dias. O ciclo pode estar desregulado.'
                                      : 'Menstruação atrasada em $diasAtraso ${diasAtraso == 1 ? 'dia' : 'dias'}.',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [MenstrualColors.lightBg.withOpacity(0.8), Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: MenstrualColors.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMenstruandoHoje
                                      ? 'Em período menstrual'
                                      : (estaAtrasada
                                          ? 'Atrasada'
                                          : (diasParaProxima == 0
                                              ? 'Prevista para hoje'
                                              : 'Próxima menstruação em $diasParaProxima dias')),
                                  style: const TextStyle(
                                    fontFamily: 'LilitaOne',
                                    fontSize: 16,
                                    color: MenstrualColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text(
                                      'Probabilidade de engravidar: ',
                                      style: TextStyle(fontSize: 13, color: Colors.black87),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: calcHoje['probabilidade'] == 'Alta'
                                            ? Colors.purple.shade100
                                            : (calcHoje['probabilidade'] == 'Média'
                                                ? Colors.blue.shade100
                                                : Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        calcHoje['probabilidade'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: calcHoje['probabilidade'] == 'Alta'
                                              ? Colors.purple.shade800
                                              : (calcHoje['probabilidade'] == 'Média'
                                                  ? Colors.blue.shade800
                                                  : Colors.grey.shade700),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (noPeriodoEsperado)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MenstrualColors.lightBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: MenstrualColors.highlight),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Sua menstruação já começou?',
                                style: TextStyle(
                                  fontFamily: 'LilitaOne',
                                  fontSize: 16,
                                  color: MenstrualColors.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: MenstrualColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      onPressed: () => _abrirModalEdicao(context, dados!, calcHoje['dumAtual']),
                                      child: const Text('Sim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: MenstrualColors.primary),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () async {
                                        setState(() {
                                          _esconderPergunta = true;
                                        });
                                        await _db.salvarDadosMenstruacao({
                                          'data_ultima_pergunta_ignorada': Timestamp.fromDate(hojeZerado)
                                        });
                                      },
                                      child: const Text('Ainda não', style: TextStyle(color: MenstrualColors.primary, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: MenstrualColors.primary, width: 1.5),
                              backgroundColor: isMenstruandoHoje ? MenstrualColors.lightBg : Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: Icon(
                              isMenstruandoHoje ? Icons.edit_calendar : Icons.water_drop_outlined,
                              color: MenstrualColors.primary,
                              size: 20,
                            ),
                            label: Text(
                              isMenstruandoHoje ? 'Editar datas do ciclo' : 'Registrar menstruação',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MenstrualColors.primary,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () => _abrirModalEdicao(context, dados!, calcHoje['dumAtual']),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FloweryBackground extends StatefulWidget {
  const FloweryBackground({Key? key}) : super(key: key);

  @override
  _FloweryBackgroundState createState() => _FloweryBackgroundState();
}

class _FloweryBackgroundState extends State<FloweryBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            _buildFlower(top: -20, left: -10, size: 100, offset: 0, direction: 1),
            _buildFlower(top: 80, right: -30, size: 70, offset: 0.5, direction: -1),
            _buildFlower(bottom: 20, left: 40, size: 60, offset: 0.2, direction: 1),
            _buildFlower(bottom: -10, right: 20, size: 80, offset: 0.8, direction: -1),
            _buildFlower(top: 150, left: -20, size: 50, offset: 0.3, direction: 1),
          ],
        );
      },
    );
  }

  Widget _buildFlower({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double offset,
    required int direction,
  }) {
    double angle = _controller.value * 2 * math.pi * direction + offset;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Icon(
          Icons.local_florist,
          size: size,
          color: MenstrualColors.border.withOpacity(0.35),
        ),
      ),
    );
  }
}

class _MenstrualCalendarModal extends StatefulWidget {
  final DateTime dum;
  final int duracaoCiclo;
  final int duracaoMenstruacao;
  final Function calcularCiclo;
  final DatabaseService db;

  const _MenstrualCalendarModal({
    required this.dum,
    required this.duracaoCiclo,
    required this.duracaoMenstruacao,
    required this.calcularCiclo,
    required this.db,
  });

  @override
  State<_MenstrualCalendarModal> createState() => _MenstrualCalendarModalState();
}

class _MenstrualCalendarModalState extends State<_MenstrualCalendarModal> {
  late DateTime _mesExibido;
  DateTime? _diaSelecionado;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _mesExibido = DateTime(now.year, now.month);
    _diaSelecionado = DateTime(now.year, now.month, now.day);
  }

  static const List<String> meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateUtils.getDaysInMonth(_mesExibido.year, _mesExibido.month);
    DateTime firstDay = DateTime(_mesExibido.year, _mesExibido.month, 1);
    int firstWeekday = firstDay.weekday;
    int emptySpaces = firstWeekday == 7 ? 0 : firstWeekday;

    DateTime hoje = DateTime.now();
    DateTime hojeZerado = DateTime(hoje.year, hoje.month, hoje.day);

    Map<String, dynamic>? infoDiaSelecionado;
    if (_diaSelecionado != null) {
      infoDiaSelecionado = widget.calcularCiclo(
        widget.dum,
        widget.duracaoCiclo,
        widget.duracaoMenstruacao,
        _diaSelecionado!,
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: FloweryBackground()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 28, color: MenstrualColors.primary),
                      onPressed: () {
                        setState(() {
                          _mesExibido = DateTime(_mesExibido.year, _mesExibido.month - 1);
                        });
                      },
                    ),
                    Text(
                      '${meses[_mesExibido.month - 1]} de ${_mesExibido.year}',
                      style: const TextStyle(
                        fontFamily: 'LilitaOne',
                        fontSize: 22,
                        color: AppTheme.textDark,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 28, color: MenstrualColors.primary),
                      onPressed: () {
                        setState(() {
                          _mesExibido = DateTime(_mesExibido.year, _mesExibido.month + 1);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S']
                      .map((d) => SizedBox(
                            width: 32,
                            child: Text(
                              d,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: daysInMonth + emptySpaces,
                          itemBuilder: (context, index) {
                            if (index < emptySpaces) return const SizedBox.shrink();

                            int day = index - emptySpaces + 1;
                            DateTime dateCalculated = DateTime(_mesExibido.year, _mesExibido.month, day);

                            Map<String, dynamic> calc = widget.calcularCiclo(
                              widget.dum,
                              widget.duracaoCiclo,
                              widget.duracaoMenstruacao,
                              dateCalculated,
                            );

                            bool isToday = dateCalculated.year == hojeZerado.year &&
                                dateCalculated.month == hojeZerado.month &&
                                dateCalculated.day == hojeZerado.day;

                            bool isSelected = _diaSelecionado != null &&
                                dateCalculated.year == _diaSelecionado!.year &&
                                dateCalculated.month == _diaSelecionado!.month &&
                                dateCalculated.day == _diaSelecionado!.day;

                            bool isMenstruando = calc['isMenstruando'];
                            String prob = calc['probabilidade'];

                            Color bg = Colors.transparent;
                            Color textColor = AppTheme.textDark;

                            if (isMenstruando) {
                              bg = MenstrualColors.highlight;
                              textColor = Colors.white;
                            } else if (prob == 'Alta') {
                              bg = Colors.purple.shade100;
                              textColor = Colors.purple.shade900;
                            } else if (prob == 'Média') {
                              bg = Colors.blue.shade100;
                              textColor = Colors.blue.shade900;
                            }

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _diaSelecionado = dateCalculated;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: bg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? MenstrualColors.primary
                                        : (isToday ? Colors.orange : Colors.transparent),
                                    width: isSelected ? 2.5 : (isToday ? 2 : 0),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$day',
                                    style: TextStyle(
                                      fontWeight: (isToday || isSelected || isMenstruando)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: textColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLegendaItem(MenstrualColors.highlight, 'Menstruação'),
                            _buildLegendaItem(Colors.purple.shade100, 'Alta Fert.'),
                            _buildLegendaItem(Colors.blue.shade100, 'Média Fert.'),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_diaSelecionado != null && infoDiaSelecionado != null) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: MenstrualColors.lightBg.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: MenstrualColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(_diaSelecionado!),
                                      style: const TextStyle(
                                        fontFamily: 'LilitaOne',
                                        fontSize: 18,
                                        color: AppTheme.textDark,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Dia ${infoDiaSelecionado['diaDoCiclo']} do Ciclo',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: MenstrualColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('Probabilidade de engravidar: ',
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${infoDiaSelecionado['probabilidade']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: infoDiaSelecionado['probabilidade'] == 'Alta'
                                            ? Colors.purple
                                            : (infoDiaSelecionado['probabilidade'] == 'Média'
                                                ? Colors.blue
                                                : Colors.grey.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  infoDiaSelecionado['isMenstruando']
                                      ? 'Fase: Menstruação'
                                      : (infoDiaSelecionado['isFertil']
                                          ? 'Fase: Janela Fértil / Ovulação'
                                          : 'Fase: Folicular / Lútea'),
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendaItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}