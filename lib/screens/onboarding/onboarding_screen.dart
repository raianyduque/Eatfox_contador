// tela de onboarding, realiza o cadastro do usuario, extraindo informaçoes de idade, sexo, nome e etc.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import 'summary_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isRedefining;

  const OnboardingScreen({super.key, this.isRedefining = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final UserProfile _profile = UserProfile();

  int _currentPage = 0;

  bool _isLoadingInitial = true;
  bool _needsPassword = false;
  String _googlePassword = '';
  String _googleConfirmPassword = '';

  TimeOfDay? _horaInicioAlimentacao;
  TimeOfDay? _horaFimAlimentacao;
  final TextEditingController _outraRestricaoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (_profile.ritmoMeta.isEmpty) {
      _profile.ritmoMeta = 'Ideal';
    }
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          if (data.containsKey('nome')) _profile.nome = data['nome'] ?? '';
          if (data.containsKey('sexo')) _profile.sexo = data['sexo'] ?? '';

          bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
          if (isGoogle) {
            if (!data.containsKey('senha_salva') ||
                data['senha_salva'].toString().trim().isEmpty) {
              _needsPassword = true;
            }
          }
        }
      } else {
        bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
        if (isGoogle) {
          _needsPassword = true;
        }
      }
    }
    setState(() {
      _isLoadingInitial = false;
    });
  }

  List<Widget> get _pages {
    List<Widget> pages = [];
    if (_needsPassword) {
      pages.add(_buildPasswordPage());
    }
    
   
    if (!widget.isRedefining) {
      pages.add(_buildBasicsPage());
    }
    
    pages.addAll([
      _buildBodyPage(),
      _buildGoalPage(),
      _buildActivityPage(),
      _buildDietPage(),
      _buildRoutinePage(),
      _buildCaloriesModePage(),
    ]);
    return pages;
  }

  int get _totalPages => _pages.length;

  bool _validarEtapaAtual() {
    int adjustedIndex = _currentPage;

    if (_needsPassword) {
      if (adjustedIndex == 0) {
        if (_googlePassword.length < 8 ||
            !_googlePassword.contains(RegExp(r'[a-zA-Z]')) ||
            !_googlePassword.contains(RegExp(r'[0-9]'))) {
          _mostrarErro('A senha deve ter no mínimo 8 caracteres, contendo letras e números.');
          return false;
        }
        if (_googlePassword != _googleConfirmPassword) {
          _mostrarErro('As senhas não coincidem.');
          return false;
        }
        return true;
      }
      adjustedIndex--;
    }

    
    if (widget.isRedefining) {
      adjustedIndex++;
    }

    switch (adjustedIndex) {
      case 0:
        return _profile.nome.isNotEmpty && _profile.sexo.isNotEmpty;
      case 1:
        if (_profile.idade < 18 || _profile.idade > 120) {
          _mostrarErro('Idade inválida. A idade mínima é 18 e a máxima é 120 anos.');
          return false;
        }
        if (_profile.altura <= 0) {
          _mostrarErro('Insira uma altura válida.');
          return false;
        }
        if (_profile.peso <= 0) {
          _mostrarErro('Insira um peso válido.');
          return false;
        }
        return true;
      case 2:
        if (_profile.objetivo.isEmpty) return false;

        if (_profile.objetivo == 'Perder peso') {
          if (_profile.metaPeso >= _profile.peso) {
            _mostrarErro('Para perder peso, a meta de peso deve ser menor do que o peso atual (${_profile.peso} kg).');
            return false;
          }
          double altM = _profile.altura / 100;
          double imcMeta = _profile.metaPeso / (altM * altM);
          if (imcMeta < 18.5) {
            _mostrarErro('Meta irreal e insegura! Resultaria em IMC ${imcMeta.toStringAsFixed(1)} (Abaixo do peso/Desnutrição).');
            return false;
          }
        } else if (_profile.objetivo == 'Ganhar peso' || _profile.objetivo == 'Ganhar massa') {
          if (_profile.metaPeso <= _profile.peso) {
            _mostrarErro('Para ganhar peso/massa, a meta de peso deve ser maior do que o peso atual (${_profile.peso} kg).');
            return false;
          }
          double altM = _profile.altura / 100;
          double imcMeta = _profile.metaPeso / (altM * altM);
          if (imcMeta > 35.0) {
            _mostrarErro('Meta irreal e fora do aceitável! Resultaria em IMC muito elevado (${imcMeta.toStringAsFixed(1)}).');
            return false;
          }
        }

        if (_profile.objetivo != 'Manter o peso') {
          if (_profile.metaPeso <= 0 || _profile.prazoMeta == null) {
            _mostrarErro('Por favor, informe uma meta de peso válida.');
            return false;
          }
        }
        return true;
      case 3:
        return _profile.tipoTrabalho.isNotEmpty && _profile.nivelEsporte.isNotEmpty;
      case 4:
        return _profile.tipoDieta.isNotEmpty && _profile.restricoes.isNotEmpty;
      case 5:
        return _profile.janelaAlimentacao.isNotEmpty && _profile.lembretes.isNotEmpty;
      case 6:
        return _profile.modoCalorias.isNotEmpty;
      default:
        return true;
    }
  }

  void _mostrarErro(String msg, [Color? color]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? Colors.redAccent,
      ),
    );
  }

  double _obterMultiplicadorGET() {
    switch (_profile.nivelEsporte) {
      case 'Não ativo':
        return 1.2;
      case 'Pouco ativo':
        return 1.375;
      case 'Moderadamente ativo':
        return 1.55;
      case 'Muito ativo':
        return 1.725;
      case 'Extremamente ativo':
        return 1.9;
      default:
        return 1.2;
    }
  }

  Future<void> _finalizarESalvarNoFirebase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryOrange),
      ),
    );

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_needsPassword && _googlePassword.isNotEmpty) {
          try {
            await user.updatePassword(_googlePassword);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'requires-recent-login') {
              if (mounted) {
                Navigator.pop(context);
                _mostrarErro(
                  'Sessão expirada. Por segurança, saia do app e faça login novamente.', 
                  Colors.redAccent
                );
              }
              return; 
            } else {
              if (mounted) {
                Navigator.pop(context);
                _mostrarErro('Erro ao definir senha: ${e.message}');
              }
              return;
            }
          }
        }

        if (widget.isRedefining) {
          DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
          if (doc.exists) {
            Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
            if (data != null && data.containsKey('sexo')) {
              _profile.sexo = data['sexo'];
            } else {
              _profile.sexo = 'Masculino';
            }
          }
        }

        double tmb = (10 * _profile.peso) + (6.25 * _profile.altura) - (5 * _profile.idade);
        tmb = _profile.sexo == 'Masculino' ? tmb + 5 : tmb - 161;

        double get = tmb * _obterMultiplicadorGET();
        double metaCaloriasCalculada = get;

        double taxaSemanal = 0.50;
        if (_profile.ritmoMeta == 'Lento') taxaSemanal = 0.25;
        if (_profile.ritmoMeta == 'Rápido') taxaSemanal = 0.75;

        double ajusteDiario = (taxaSemanal * 7700) / 7;

        if (_profile.objetivo == 'Perder peso') {
          metaCaloriasCalculada -= ajusteDiario;
          if (metaCaloriasCalculada < tmb) {
            metaCaloriasCalculada = tmb;
          }
        } else if (_profile.objetivo == 'Ganhar massa' || _profile.objetivo == 'Ganhar peso') {
          metaCaloriasCalculada += ajusteDiario;
        }

        int metaCalorias = metaCaloriasCalculada.round();

        double protPorKg = 1.0;
        if (_profile.objetivo == 'Ganhar massa' || _profile.objetivo == 'Ganhar peso') {
          protPorKg = 2.0;
        } else if (_profile.objetivo == 'Perder peso') {
          protPorKg = 2.2;
        }

        int proteinaGramas = (_profile.peso * protPorKg).round();
        int gorduraGramas = (_profile.peso * 1.0).round();

        int calProteina = proteinaGramas * 4;
        int calGordura = gorduraGramas * 9;
        int calRestante = metaCalorias - (calProteina + calGordura);
        int carboGramas = (calRestante > 0) ? (calRestante / 4).round() : 0;

        double altM = _profile.altura / 100;
        double imcAtual = _profile.peso / (altM * altM);

        int metaAguaCalculada = (_profile.peso * 35).round();

        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'email': user.email,
          if (_needsPassword && _googlePassword.isNotEmpty) 'senha_salva': _googlePassword,
          if (!widget.isRedefining) 'nome': _profile.nome,
          if (!widget.isRedefining) 'sexo': _profile.sexo,
          'idade': _profile.idade,
          'altura': _profile.altura,
          'peso': _profile.peso,
          'objetivo': _profile.objetivo,
          'metaPeso': _profile.metaPeso,
          'ritmoMeta': _profile.ritmoMeta.isEmpty ? 'Ideal' : _profile.ritmoMeta,
          'prazoMeta': _profile.prazoMeta?.toIso8601String(),
          'tipoTrabalho': _profile.tipoTrabalho,
          'nivelEsporte': _profile.nivelEsporte,
          'tipoDieta': _profile.tipoDieta,
          'restricoes': _profile.restricoes,
          'janelaAlimentacao': _profile.janelaAlimentacao,
          'lembretes': _profile.lembretes,
          'modoCalorias': _profile.modoCalorias,
          'metaCalorias': metaCalorias,
          'metaProteina': proteinaGramas,
          'metaCarbo': carboGramas,
          'metaGordura': gorduraGramas,
          'metaAgua': metaAguaCalculada,
          'tmb': tmb.round(),
          'get': get.round(),
          'imc': imcAtual,
          if (!widget.isRedefining) 'nomeMascote': 'Bixinho',
          'onboardingCompleto': true,
          if (!widget.isRedefining) 'dataCadastro': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pop(context);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SummaryScreen(
                profile: _profile,
                isRedefining: widget.isRedefining,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _mostrarErro('Erro ao salvar dados: $e');
      }
    }
  }

  void _nextPage() {
    if (!_validarEtapaAtual()) return;

    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finalizarESalvarNoFirebase();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInitial) {
      return const Scaffold(
        backgroundColor: AppTheme.backgroundWhite,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
      );
    }

    double progress = (_currentPage + 1) / _totalPages;

    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : null,
        title: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              backgroundColor: AppTheme.textGray.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryOrange),
              minHeight: 10,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: _pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: AppTheme.pureWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  onPressed: _nextPage,
                  icon: Icon(_currentPage == _totalPages - 1 ? Icons.check_circle : Icons.arrow_forward),
                  label: Text(
                    _currentPage == _totalPages - 1 ? 'Ver resultado' : 'Continuar',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Crie uma senha',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 8),
          const Text(
            'Como você entrou com o Google, crie uma senha segura para poder acessar usando seu e-mail no futuro.',
            style: TextStyle(fontSize: 16, color: AppTheme.textGray),
          ),
          const SizedBox(height: 32),
          TextFormField(
            obscureText: true,
            onChanged: (val) => _googlePassword = val,
            decoration: InputDecoration(
              hintText: 'Nova Senha',
              prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryOrange),
              filled: true,
              fillColor: AppTheme.pureWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: Text(
              'Mínimo de 8 caracteres, com letras e números.',
              style: TextStyle(fontSize: 13, color: AppTheme.textGray),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            obscureText: true,
            onChanged: (val) => _googleConfirmPassword = val,
            decoration: InputDecoration(
              hintText: 'Confirmar Senha',
              prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryOrange),
              filled: true,
              fillColor: AppTheme.pureWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicsPage() {
    if (_profile.sexo.isEmpty) _profile.sexo = 'Masculino';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Como podemos te chamar?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: _profile.nome,
            onChanged: (val) => _profile.nome = val,
            decoration: InputDecoration(
              hintText: 'Seu nome ou apelido',
              prefixIcon: const Icon(Icons.person, color: AppTheme.primaryOrange),
              filled: true,
              fillColor: AppTheme.pureWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Qual seu sexo biológico?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 16),
          _buildSelectionGrid(
              ['Masculino', 'Feminino'], (val) => setState(() => _profile.sexo = val), _profile.sexo),
        ],
      ),
    );
  }

  Widget _buildBodyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Suas medidas',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 24),
          _buildIconTextField(
            'Idade (ex: 18)',
            Icons.cake,
            _profile.idade > 0 ? _profile.idade.toString() : '',
            (val) {
              int parsed = int.tryParse(val) ?? 0;
              setState(() => _profile.idade = parsed);
            },
          ),
          const SizedBox(height: 16),
          _buildIconTextField(
            'Altura (ex: 1,75 ou 175 cm)',
            Icons.height,
            _profile.altura > 0 ? _profile.altura.toString() : '',
            (val) {
              String sanitized = val.replaceAll(',', '.');
              double parsed = double.tryParse(sanitized) ?? 0.0;
              if (parsed > 0.0 && parsed < 3.0) parsed = parsed * 100;
              setState(() => _profile.altura = parsed);
            },
          ),
          const SizedBox(height: 16),
          _buildIconTextField(
            'Peso atual (kg)',
            Icons.monitor_weight,
            _profile.peso > 0 ? _profile.peso.toString() : '',
            (val) {
              String sanitized = val.replaceAll(',', '.');
              setState(() {
                _profile.peso = double.tryParse(sanitized) ?? 0.0;
                _recalcularMetaEPrazo();
              });
            },
          ),
        ],
      ),
    );
  }

  void _recalcularMetaEPrazo() {
    if (_profile.ritmoMeta.isEmpty) {
      _profile.ritmoMeta = 'Ideal';
    }

    if (_profile.peso <= 0 || _profile.metaPeso <= 0) {
      _profile.prazoMeta = null;
      return;
    }

    double diff = (_profile.peso - _profile.metaPeso).abs();
    if (diff == 0) {
      _profile.prazoMeta = DateTime.now();
      return;
    }

    double taxaSemanal = 0.50;
    if (_profile.ritmoMeta == 'Lento') taxaSemanal = 0.25;
    if (_profile.ritmoMeta == 'Rápido') taxaSemanal = 0.75;

    int semanasNecessarias = (diff / taxaSemanal).ceil();
    int diasNecessarios = semanasNecessarias * 7;
    _profile.prazoMeta = DateTime.now().add(Duration(days: diasNecessarios));
  }

  Widget _buildGoalPage() {
    bool isMetaValida = false;
    if (_profile.objetivo == 'Perder peso' && _profile.metaPeso > 0 && _profile.metaPeso < _profile.peso) {
      isMetaValida = true;
    } else if ((_profile.objetivo == 'Ganhar peso' || _profile.objetivo == 'Ganhar massa') &&
        _profile.metaPeso > _profile.peso) {
      isMetaValida = true;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Qual é o seu objetivo?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
          const SizedBox(height: 16),
          _buildIconSelectionList([
            {'titulo': 'Perder peso', 'icone': Icons.trending_down, 'cor': Colors.blue},
            {'titulo': 'Manter o peso', 'icone': Icons.balance, 'cor': Colors.green},
            {'titulo': 'Ganhar peso', 'icone': Icons.trending_up, 'cor': Colors.orange},
            {'titulo': 'Ganhar massa', 'icone': Icons.fitness_center, 'cor': Colors.purple},
          ], (val) {
            setState(() {
              if (_profile.objetivo != val) {
                _profile.objetivo = val;
                if (val == 'Manter o peso') {
                  _profile.metaPeso = _profile.peso;
                } else {
                  _profile.metaPeso = 0;
                }
                _recalcularMetaEPrazo();
              }
            });
          }, _profile.objetivo),

          if (_profile.objetivo == 'Perder peso' ||
              _profile.objetivo == 'Ganhar peso' ||
              _profile.objetivo == 'Ganhar massa') ...[
            const SizedBox(height: 24),
            const Text('Qual sua meta de peso? (kg)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildIconTextField(
              'Ex: 65.0',
              Icons.track_changes,
              _profile.metaPeso > 0 ? _profile.metaPeso.toString() : '',
              (val) {
                String sanitized = val.replaceAll(',', '.');
                setState(() {
                  _profile.metaPeso = double.tryParse(sanitized) ?? 0.0;
                  _recalcularMetaEPrazo();
                });
              },
            ),
            const SizedBox(height: 16),
            _buildWeightAnalysisFeedback(),

            if (isMetaValida) ...[
              const SizedBox(height: 24),
              const Text('Ritmo do Plano',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                'Selecione a velocidade desejada. O app calculará a data final de forma saudável e segura.',
                style: TextStyle(fontSize: 13, color: AppTheme.textGray),
              ),
              const SizedBox(height: 16),
              _buildRhythmSelector(),
              
              if (_profile.prazoMeta != null) ...[
                const SizedBox(height: 16),
                _buildAutoCalculatedDateFeedback(),
              ]
            ]
          ]
        ],
      ),
    );
  }

  Widget _buildWeightAnalysisFeedback() {
    if (_profile.peso <= 0 || _profile.metaPeso <= 0 || _profile.altura <= 0) {
      return const SizedBox.shrink();
    }

    double altM = _profile.altura / 100;
    double imcMeta = _profile.metaPeso / (altM * altM);

    bool isPerder = _profile.objetivo == 'Perder peso';
    bool isGanhar = _profile.objetivo == 'Ganhar peso' || _profile.objetivo == 'Ganhar massa';

    String statusText = '';
    String descText = '';
    Color statusColor = Colors.green;
    IconData icon = Icons.check_circle;

    if (isPerder) {
      if (_profile.metaPeso >= _profile.peso) {
        statusText = 'Fora do aceitável (Inválido)';
        descText = 'Se o seu objetivo é PERDER peso, a meta não pode ser maior ou igual ao peso atual (${_profile.peso} kg).';
        statusColor = Colors.redAccent;
        icon = Icons.cancel;
      } else if (imcMeta < 18.5) {
        statusText = 'Fora do aceitável (Muito abaixo)';
        descText = 'Esta meta de peso resultará em IMC ${imcMeta.toStringAsFixed(1)} (Desnutrição/Abaixo do peso). Defina um valor mais seguro.';
        statusColor = Colors.redAccent;
        icon = Icons.error_outline;
      } else if (_profile.peso - _profile.metaPeso > 20) {
        statusText = 'Agressivo';
        descText = 'Sua meta exige reduzir mais de 20kg. É totalmente alcançável, porém exigirá bastante foco em médio/longo prazo.';
        statusColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
      } else if (imcMeta >= 18.5 && imcMeta <= 24.9) {
        statusText = 'Realista e Saudável';
        descText = 'Excelente meta! Coloca você dentro da faixa ideal e saudável para a sua altura (IMC ${imcMeta.toStringAsFixed(1)}).';
        statusColor = Colors.green;
        icon = Icons.check_circle;
      } else {
        statusText = 'Fácil / Leve';
        descText = 'Meta suave e inicial. Ótima para começar a ver resultados rápidos.';
        statusColor = Colors.blue;
        icon = Icons.thumb_up;
      }
    } else if (isGanhar) {
      if (_profile.metaPeso <= _profile.peso) {
        statusText = 'Fora do aceitável (Inválido)';
        descText = 'Se o seu objetivo é GANHAR peso ou massa, a meta não pode ser menor ou igual ao peso atual (${_profile.peso} kg).';
        statusColor = Colors.redAccent;
        icon = Icons.cancel;
      } else if (imcMeta > 35.0) {
        statusText = 'Fora do aceitável (Muito elevado)';
        descText = 'Esta meta resultará em IMC muito alto (${imcMeta.toStringAsFixed(1)}). Escolha um valor mais adequado com ajuda profissional.';
        statusColor = Colors.redAccent;
        icon = Icons.error_outline;
      } else if (_profile.metaPeso - _profile.peso > 15) {
        statusText = 'Agressivo';
        descText = 'Ganhar mais de 15kg exige bastante treino de força e superávit calórico controlado.';
        statusColor = Colors.orange;
        icon = Icons.warning_amber_rounded;
      } else {
        statusText = 'Realista e Saudável';
        descText = 'Ótima meta de ganho proporcional (IMC projetado de ${imcMeta.toStringAsFixed(1)}).';
        statusColor = Colors.green;
        icon = Icons.check_circle;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: statusColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: statusColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Classificação: $statusText',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: statusColor),
                ),
                const SizedBox(height: 4),
                Text(
                  descText,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textDark, height: 1.3),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRhythmSelector() {
    List<Map<String, dynamic>> ritmos = [
      {
        'id': 'Lento',
        'titulo': 'Lento',
        'subtitulo': '0,25 kg/sem',
        'desc': 'Mudança leve, sustentável e muito suave para o corpo.',
        'icone': Icons.directions_walk,
      },
      {
        'id': 'Ideal',
        'titulo': 'Ideal e Rápido',
        'subtitulo': '0,50 kg/sem',
        'desc': 'Equilíbrio perfeito entre velocidade e saúde recomendada.',
        'icone': Icons.directions_run,
      },
      {
        'id': 'Rápido',
        'titulo': 'Rápido',
        'subtitulo': '0,75 kg/sem',
        'desc': 'Resultados mais ágeis. Exige disciplina e foco total.',
        'icone': Icons.bolt,
      },
    ];

    if (_profile.ritmoMeta.isEmpty) {
      _profile.ritmoMeta = 'Ideal';
    }

    return Column(
      children: ritmos.map((item) {
        bool isSelected = _profile.ritmoMeta == item['id'];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _profile.ritmoMeta = item['id'];
                _recalcularMetaEPrazo();
              });
            },
            borderRadius: BorderRadius.circular(15),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryOrange : AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  if (!isSelected) 
                    BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))
                ],
                border: Border.all(
                  color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade300,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withOpacity(0.2) 
                          : AppTheme.primaryOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      item['icone'],
                      color: isSelected ? Colors.white : AppTheme.primaryOrange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['titulo'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isSelected ? Colors.white : AppTheme.textDark,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['subtitulo'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['desc'],
                          style: TextStyle(
                            fontSize: 12, 
                            color: isSelected ? Colors.white70 : AppTheme.textGray
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ]
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAutoCalculatedDateFeedback() {
    double diff = (_profile.peso - _profile.metaPeso).abs();
    if (diff == 0 || _profile.prazoMeta == null) return const SizedBox.shrink();

    int diasTotais = _profile.prazoMeta!.difference(DateTime.now()).inDays;
    int semanas = (diasTotais / 7).ceil();
    String dataFormatada =
        '${_profile.prazoMeta!.day.toString().padLeft(2, '0')}/${_profile.prazoMeta!.month.toString().padLeft(2, '0')}/${_profile.prazoMeta!.year}';

    double taxaSemanal = 0.50;
    if (_profile.ritmoMeta == 'Lento') taxaSemanal = 0.25;
    if (_profile.ritmoMeta == 'Rápido') taxaSemanal = 0.75;

    int impactoCaloricoDiario = ((taxaSemanal * 7700) / 7).round();
    bool isPerder = _profile.objetivo == 'Perder peso';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, color: Colors.indigo),
              SizedBox(width: 8),
              Text(
                'Cálculo do Plano Alimentar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Alteração total: ${diff.toStringAsFixed(1)} kg\n'
            '• Duração estimada: $semanas semanas (~$diasTotais dias)\n'
            '• Alcançará até: $dataFormatada\n'
            '• Impacto na dieta: ${isPerder ? '-' : '+'}$impactoCaloricoDiario kcal / dia',
            style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityPage() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text('Você trabalha de que forma?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildDetailedSelectionList([
          {'titulo': 'Sentado', 'desc': 'Trabalho em escritório, dirige o dia todo.', 'icone': Icons.chair, 'cor': Colors.brown},
          {'titulo': 'Alternando', 'desc': 'Trabalho de professor, vendedor, levanta frequentemente.', 'icone': Icons.swap_vert, 'cor': Colors.blue},
          {'titulo': 'Maior parte em pé', 'desc': 'Garçom, enfermeiro, muito tempo de pé.', 'icone': Icons.directions_walk, 'cor': Colors.orange},
          {'titulo': 'Braçal', 'desc': 'Trabalho pesado, construção civil, carregamento.', 'icone': Icons.construction, 'cor': Colors.red},
        ], (val) => setState(() => _profile.tipoTrabalho = val), _profile.tipoTrabalho),
        const SizedBox(height: 24),
        const Text('Qual seu nível de esporte?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildDetailedSelectionList([
          {'titulo': 'Não ativo', 'desc': 'Nenhum exercício intencional na semana.', 'icone': Icons.weekend, 'cor': Colors.grey},
          {'titulo': 'Pouco ativo', 'desc': 'Caminhadas leves, 1 a 3 dias na semana.', 'icone': Icons.nature_people, 'cor': Colors.lightGreen},
          {'titulo': 'Moderadamente ativo', 'desc': 'Exercício moderado 3 a 5 dias na semana.', 'icone': Icons.directions_run, 'cor': Colors.orange},
          {'titulo': 'Muito ativo', 'desc': 'Exercício pesado 6 a 7 dias na semana.', 'icone': Icons.fitness_center, 'cor': Colors.redAccent},
          {'titulo': 'Extremamente ativo', 'desc': 'Trabalho físico pesado ou treino diário intenso.', 'icone': Icons.sports_gymnastics, 'cor': Colors.deepPurple},
        ], (val) => setState(() => _profile.nivelEsporte = val), _profile.nivelEsporte),
      ],
    );
  }

  Widget _buildDietPage() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text('Tipo de dieta que segue',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildIconSelectionList([
          {'titulo': 'Equilibrada', 'icone': Icons.restaurant_menu, 'cor': Colors.orange},
          {'titulo': 'Vegetariana', 'icone': Icons.eco, 'cor': Colors.green},
          {'titulo': 'Vegana', 'icone': Icons.filter_vintage, 'cor': Colors.teal},
          {'titulo': 'Paleo', 'icone': Icons.set_meal, 'cor': Colors.brown},
          {'titulo': 'Cetogênica', 'icone': Icons.egg, 'cor': Colors.yellow.shade700},
          {'titulo': 'Rica em proteínas', 'icone': Icons.fitness_center, 'cor': Colors.red},
        ], (val) => setState(() => _profile.tipoDieta = val), _profile.tipoDieta),
        const SizedBox(height: 24),
        const Text('Tem restrições ou alergias?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Marque quantas quiser:', style: TextStyle(fontSize: 14, color: AppTheme.textGray)),
        const SizedBox(height: 8),
        _buildMultiSelectionRestrictions(),
      ],
    );
  }

  Widget _buildMultiSelectionRestrictions() {
    List<Map<String, dynamic>> opcoes = [
      {'titulo': 'Nenhuma', 'icone': Icons.check_circle, 'cor': Colors.green},
      {'titulo': 'Glúten', 'icone': Icons.bakery_dining, 'cor': Colors.orange},
      {'titulo': 'Lactose', 'icone': Icons.icecream, 'cor': Colors.blue},
      {'titulo': 'Nozes', 'icone': Icons.park, 'cor': Colors.brown},
      {'titulo': 'Frutos do mar', 'icone': Icons.phishing, 'cor': Colors.teal},
      {'titulo': 'Outra', 'icone': Icons.edit, 'cor': Colors.grey},
    ];

    return Column(
      children: opcoes.map((opcao) {
        String titulo = opcao['titulo'];
        bool isSelected = _profile.restricoes.contains(titulo) ||
            _profile.restricoes.any((r) => r.startsWith('Outra:') && titulo == 'Outra');

        return Column(
          children: [
            CheckboxListTile(
              title: Row(
                children: [
                  Icon(opcao['icone'], color: opcao['cor'], size: 24),
                  const SizedBox(width: 12),
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              activeColor: AppTheme.primaryOrange,
              checkColor: AppTheme.pureWhite,
              value: isSelected,
              onChanged: (bool? checked) {
                setState(() {
                  if (titulo == 'Nenhuma' && checked == true) {
                    _profile.restricoes.clear();
                    _profile.restricoes.add('Nenhuma');
                  } else {
                    _profile.restricoes.remove('Nenhuma');
                    if (checked == true) {
                      _profile.restricoes.add(titulo);
                    } else {
                      _profile.restricoes.remove(titulo);
                      if (titulo == 'Outra') {
                        _profile.restricoes.removeWhere((item) => item.startsWith('Outra:'));
                      }
                    }
                  }
                });
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              tileColor: AppTheme.pureWhite,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            const SizedBox(height: 8),
            if (titulo == 'Outra' && isSelected)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  controller: _outraRestricaoController,
                  onChanged: (val) {
                    _profile.restricoes.removeWhere((item) => item.startsWith('Outra:'));
                    if (val.isNotEmpty) {
                      _profile.restricoes.add('Outra: $val');
                    } else {
                      _profile.restricoes.add('Outra');
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Descreva sua alergia/restrição',
                    filled: true,
                    fillColor: AppTheme.pureWhite,
                    prefixIcon: const Icon(Icons.edit, color: AppTheme.primaryOrange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRoutinePage() {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text('Janela de alimentação', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Selecione os horários da primeira e última refeição', style: TextStyle(color: AppTheme.textGray)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildTimePickerButton('De', _horaInicioAlimentacao, (time) {
                setState(() {
                  _horaInicioAlimentacao = time;
                  _profile.horaInicioAlimentacao = time;
                  _updateJanelaAlimentacao();
                });
              }),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePickerButton('Até', _horaFimAlimentacao, (time) {
                setState(() {
                  _horaFimAlimentacao = time;
                  _profile.horaFimAlimentacao = time;
                  _updateJanelaAlimentacao();
                });
              }),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Text('Gostaria de receber lembretes?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildIconSelectionList([
          {'titulo': 'De manhã', 'icone': Icons.wb_sunny, 'cor': Colors.orange},
          {'titulo': 'Antes das refeições', 'icone': Icons.restaurant, 'cor': Colors.redAccent},
          {'titulo': 'A cada 3 horas', 'icone': Icons.timer, 'cor': Colors.blue},
          {'titulo': 'Não quero lembretes', 'icone': Icons.notifications_off, 'cor': Colors.grey},
        ], (val) => setState(() => _profile.lembretes = val), _profile.lembretes),
      ],
    );
  }

  void _updateJanelaAlimentacao() {
    if (_horaInicioAlimentacao != null && _horaFimAlimentacao != null) {
      final inicio =
          '${_horaInicioAlimentacao!.hour.toString().padLeft(2, '0')}:${_horaInicioAlimentacao!.minute.toString().padLeft(2, '0')}';
      final fim =
          '${_horaFimAlimentacao!.hour.toString().padLeft(2, '0')}:${_horaFimAlimentacao!.minute.toString().padLeft(2, '0')}';
      _profile.janelaAlimentacao = '$inicio às $fim';
    }
  }

  Widget _buildTimePickerButton(String label, TimeOfDay? time, Function(TimeOfDay) onPicked) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.pureWhite,
        foregroundColor: AppTheme.textDark,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      icon: const Icon(Icons.access_time, color: AppTheme.primaryOrange),
      label: Text(time != null
          ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
          : label),
      onPressed: () async {
        TimeOfDay? picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
            cancelText: 'Cancelar',
            confirmText: 'Confirmar',
            helpText: 'Selecione o horario',
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppTheme.primaryOrange,
                  ),
                ),
                child: child!,
              );
            });
        if (picked != null) onPicked(picked);
      },
    );
  }

  Widget _buildCaloriesModePage() {
    if (_profile.modoCalorias.isEmpty) {
      _profile.modoCalorias = 'Modo Inteligente';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Como as atividades afetam suas calorias?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildCardOption(
            'Modo Inteligente',
            'Só aumenta sua meta diária de comida se o seu treino queimar mais calorias do que a sua rotina base já previa. Evita a contagem dupla de calorias.',
            'Modo Inteligente',
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          _buildCardOption(
            'Modo Todas as Calorias',
            'Soma absolutamente toda caloria gasta no exercício à sua meta, permitindo que você "coma de volta" tudo o que queimou.',
            'Todas as Calorias',
            Icons.local_fire_department,
          ),
        ],
      ),
    );
  }

  Widget _buildCardOption(String title, String subtitle, String value, IconData icon) {
    bool isSelected = _profile.modoCalorias == value;
    return InkWell(
      onTap: () => setState(() => _profile.modoCalorias = value),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange.withOpacity(0.1) : AppTheme.pureWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.transparent, width: 2),
          boxShadow: [if (!isSelected) BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primaryOrange : AppTheme.textGray, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primaryOrange : AppTheme.textDark)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textGray, height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTextField(String hint, IconData icon, String initialValue, Function(String) onChanged) {
    return TextFormField(
      initialValue: initialValue,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryOrange),
        filled: true,
        fillColor: AppTheme.pureWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSelectionGrid(List<String> options, Function(String) onSelect, String selected) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map((opt) => ChoiceChip(
                label: Text(opt,
                    style: TextStyle(
                        color: selected == opt ? AppTheme.pureWhite : AppTheme.textDark, fontSize: 16)),
                selected: selected == opt,
                selectedColor: AppTheme.primaryOrange,
                backgroundColor: AppTheme.pureWhite,
                onSelected: (bool s) => onSelect(opt),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ))
          .toList(),
    );
  }

  Widget _buildIconSelectionList(List<Map<String, dynamic>> options, Function(String) onSelect, String selected) {
    return Column(
      children: options.map((opt) {
        String titulo = opt['titulo'];
        IconData icone = opt['icone'];
        Color cor = opt['cor'];
        bool isSelected = selected == titulo;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: () => onSelect(titulo),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryOrange : AppTheme.pureWhite,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [if (!isSelected) BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
                ),
                child: Row(
                  children: [
                    Icon(icone, color: isSelected ? AppTheme.pureWhite : cor, size: 28),
                    const SizedBox(width: 16),
                    Text(titulo,
                        style: TextStyle(
                            fontSize: 16,
                            color: isSelected ? AppTheme.pureWhite : AppTheme.textDark,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailedSelectionList(List<Map<String, dynamic>> options, Function(String) onSelect, String selected) {
    return Column(
      children: options.map((opt) {
        String titulo = opt['titulo'];
        String desc = opt['desc'];
        IconData icone = opt['icone'];
        Color cor = opt['cor'];
        bool isSelected = selected == titulo;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: InkWell(
              onTap: () => onSelect(titulo),
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryOrange.withOpacity(0.1) : AppTheme.pureWhite,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.transparent, width: 2),
                  boxShadow: [if (!isSelected) BoxShadow(color: Colors.grey.shade200, blurRadius: 5)],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: cor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(icone, color: cor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo,
                              style: TextStyle(
                                  fontSize: 18,
                                  color: isSelected ? AppTheme.primaryOrange : AppTheme.textDark,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(desc, style: const TextStyle(fontSize: 14, color: AppTheme.textGray)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}