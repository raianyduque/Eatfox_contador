// pagina de configuraçoes, editar dados basicos com nome, sexo, idade, meta de agua, calorias, macros BASE, excluir e sair da conta.

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  final List<String> _avatarPresets = [
    'https://cdn-icons-png.flaticon.com/512/4140/4140048.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140047.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140037.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140051.png',
    'https://cdn-icons-png.flaticon.com/512/4140/4140061.png',
  ];

  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('ic_notificacao'); 

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Usuário clicou na notificação: ${response.payload}');
      },
    );

    final androidImpl = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  Future<void> _scheduleLembretes(bool ativo, String frequencia) async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    
    if (!ativo) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lembretes_channel',
      'Lembretes do App',
      channelDescription: 'Notificações de lembretes diários e refeições',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails, 
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        999,
        'Lembretes Ativados! 🔔',
        'Seus lembretes foram configurados com sucesso.',
        platformDetails,
      );

      if (frequencia == 'De manhã' || frequencia == 'Antes das refeições') {
        await _flutterLocalNotificationsPlugin.periodicallyShow(
          0,
          'Hora de registrar! 🍽',
          'Não esqueça de marcar suas refeições e bater metas.',
          RepeatInterval.daily,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } else if (frequencia.contains('A cada')) {
        await _flutterLocalNotificationsPlugin.periodicallyShow(
          1,
          'Mantenha o foco! 💧',
          'Lembre-se de beber água e conferir suas atividades.',
          RepeatInterval.hourly,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Erro ao agendar notificação: $e');
    }
  }

  Future<void> _updateFields(Map<String, dynamic> dataToUpdate) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('usuarios')
            .doc(user.uid)
            .set(dataToUpdate, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configurações atualizadas com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao atualizar: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

// ignore: unused_element
Future<void> _uploadProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile == null) return; // Usuário cancelou
    try {
      final directory = await getApplicationDocumentsDirectory();
      final String userUid = _auth.currentUser?.uid ?? 'local_user';
      
      // Adicionado timestamp no nome do arquivo para contornar o cache de imagem do Flutter
      // Isso força a UI a atualizar instantaneamente quando uma nova foto é escolhida.
      final String localPath = '${directory.path}/perfil_${userUid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final File savedImage = await File(pickedFile.path).copy(localPath);
      
      // Limpar cache de imagens para garantir
      PaintingBinding.instance.imageCache.clear();
      
      await _updateFields({
        'fotoUrl': savedImage.path,
        'foto_perfil': savedImage.path,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto atualizada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar foto no celular: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  dynamic _getValue(Map<String, dynamic> data, List<String> keys, dynamic defaultValue) {
    for (String key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key];
      }
    }
    return defaultValue;
  }

  // ignore: unused_element
  ImageProvider? _getProfileImage(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) return null;
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      return NetworkImage(photoPath);
    }
    return FileImage(File(photoPath));
  }


void _openPhotoPicker(String? currentPhotoUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 16,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Foto de Perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
            const SizedBox(height: 16),
            const Text('Escolha um avatar:', style: TextStyle(fontSize: 14, color: AppTheme.textGray, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              height: 75,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarPresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final url = _avatarPresets[index];
                  return GestureDetector(
                    onTap: () {
                      _updateFields({'fotoUrl': url, 'foto_perfil': url});
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: AppTheme.primaryOrange.withOpacity(0.05),
                        backgroundImage: NetworkImage(url),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryOrange,
                  side: const BorderSide(color: AppTheme.primaryOrange),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context); 
                  _uploadProfilePicture(); 
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Escolher da Galeria', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
        

            if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    _updateFields({'fotoUrl': null, 'foto_perfil': null});
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remover Foto Atual', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openCustomReminderDialog() {
    TextEditingController horasCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Lembrete Personalizado', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: TextField(
          controller: horasCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'A cada quantas horas?',
            suffixText: 'horas',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange)),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              String val = horasCtrl.text.trim();
              if (val.isNotEmpty) {
                String nomeOpcao = 'A cada $val horas';
                _updateFields({
                  'opcaoLembrete': nomeOpcao,
                  'opcao_lembrete': nomeOpcao,
                  'frequenciaLembrete': nomeOpcao,
                  'lembretes': true,
                  'lembrete': true,
                  'lembretesAtivos': true,
                  'lembretes_ativos': true,
                  'notificacoes': true,
                  'notificacoesAtivas': true,
                });
                _scheduleLembretes(true, nomeOpcao);
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _openLembretesModal(String currentOption) {
    List<Map<String, String>> opcoes = [
      {
        'nome': 'Não quero lembretes',
        'descricao': 'Desativar todas as notificações e avisos do aplicativo.',
      },
      {
        'nome': 'De manhã',
        'descricao': 'Lembrete diário no início do dia para abrir o app e registrar suas refeições.',
      },
      {
        'nome': 'Antes das refeições',
        'descricao': 'Notificações antes dos horários de café, almoço e jantar para marcar seus pratos.',
      },
      {
        'nome': 'A cada 3 horas',
        'descricao': 'Lembretes periódicos ao longo do dia para se manter ativo.',
      },
      {
        'nome': 'Personalizado',
        'descricao': 'Escolha um intervalo de horas específico para ser lembrado.',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Frequência dos Lembretes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 8),
              const Text('Escolha quando deseja receber avisos:', style: TextStyle(fontSize: 14, color: AppTheme.textGray)),
              const SizedBox(height: 20),
              ...opcoes.map((opt) {
                bool isKnown = ['não quero lembretes', 'de manhã', 'antes das refeições', 'a cada 3 horas'].contains(currentOption.toLowerCase());
                bool isSelected;
                if (opt['nome'] == 'Personalizado') {
                  isSelected = !isKnown && currentOption.isNotEmpty && currentOption.toLowerCase() != 'nenhuma';
                } else {
                  isSelected = opt['nome'].toString().toLowerCase() == currentOption.toLowerCase();
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryOrange.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade200, width: 1.5),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Icon(
                      opt['nome'] == 'Personalizado' ? Icons.timer : (opt['nome'] == 'Não quero lembretes' ? Icons.notifications_off : Icons.notifications_active),
                      color: isSelected ? AppTheme.primaryOrange : AppTheme.textGray,
                    ),
                    title: Text(
                      opt['nome']!,
                      style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppTheme.primaryOrange : AppTheme.textDark),
                    ),
                    subtitle: Text(opt['descricao']!, style: const TextStyle(fontSize: 12, color: AppTheme.textGray)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryOrange, size: 24) : null,
                    onTap: () {
                      if (opt['nome'] == 'Personalizado') {
                        Navigator.pop(context);
                        _openCustomReminderDialog();
                      } else if (opt['nome'] == 'Não quero lembretes') {
                        _updateFields({
                          'opcaoLembrete': opt['nome'],
                          'opcao_lembrete': opt['nome'],
                          'frequenciaLembrete': opt['nome'],
                          'lembretes': false,
                          'lembrete': false,
                          'lembretesAtivos': false,
                          'lembretes_ativos': false,
                          'notificacoes': false,
                          'notificacoesAtivas': false,
                        });
                        _scheduleLembretes(false, opt['nome']!);
                        Navigator.pop(context);
                      } else {
                        _updateFields({
                          'opcaoLembrete': opt['nome'],
                          'opcao_lembrete': opt['nome'],
                          'frequenciaLembrete': opt['nome'],
                          'lembretes': true,
                          'lembrete': true,
                          'lembretesAtivos': true,
                          'lembretes_ativos': true,
                          'notificacoes': true,
                          'notificacoesAtivas': true,
                        });
                        _scheduleLembretes(true, opt['nome']!);
                        Navigator.pop(context);
                      }
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _openTextEditor({
    required String title,
    required List<String> fieldKeys,
    required dynamic currentValue,
    TextInputType keyboardType = TextInputType.text,
    String unit = '',
    String? Function(dynamic)? validator,
  }) {
    TextEditingController controller = TextEditingController(text: currentValue?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Editar $title', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: true,
          decoration: InputDecoration(
            suffixText: unit,
            hintText: 'Digite o novo valor',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange)),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              String text = controller.text.trim();
              dynamic val;
              
              if (keyboardType == TextInputType.number || keyboardType == const TextInputType.numberWithOptions(decimal: true)) {
                val = num.tryParse(text.replaceAll(',', '.')) ?? currentValue;
              } else {
                val = text;
              }

              if (validator != null) {
                String? errorMsg = validator(val);
                if (errorMsg != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg), 
                      backgroundColor: Colors.redAccent, 
                      duration: const Duration(seconds: 3)
                    ),
                  );
                  return; 
                }
              }

              Map<String, dynamic> updates = {};
              for (String key in fieldKeys) {
                updates[key] = val;
              }

              _updateFields(updates);
              Navigator.pop(context);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _openMacrosEditor(Map<String, dynamic> data) {
    TextEditingController protCtrl = TextEditingController(text: _getValue(data, ['metaProteina', 'meta_proteina'], 0).toString());
    TextEditingController carboCtrl = TextEditingController(text: _getValue(data, ['metaCarbo', 'meta_carbo'], 0).toString());
    TextEditingController gordCtrl = TextEditingController(text: _getValue(data, ['metaGordura', 'meta_gordura'], 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Metas de Macros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMacroField('Proteínas (g)', protCtrl, Colors.redAccent, Icons.egg_alt),
              const SizedBox(height: 16),
              _buildMacroField('Carboidratos (g)', carboCtrl, Colors.orange, Icons.breakfast_dining),
              const SizedBox(height: 16),
              _buildMacroField('Gorduras (g)', gordCtrl, Colors.amber.shade700, Icons.water_drop),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryOrange,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              int prot = int.tryParse(protCtrl.text) ?? 0;
              int carbo = int.tryParse(carboCtrl.text) ?? 0;
              int gord = int.tryParse(gordCtrl.text) ?? 0;

              _updateFields({
                'metaProteina': prot,
                'meta_proteina': prot,
                'metaCarbo': carbo,
                'meta_carbo': carbo,
                'metaGordura': gord,
                'meta_gordura': gord,
              });
              Navigator.pop(context);
            },
            child: const Text('Salvar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroField(String label, TextEditingController ctrl, Color color, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: color),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: color)),
      ),
    );
  }

  void _openSingleSelectModal({
    required String title,
    required List<Map<String, dynamic>> options,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 16,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              const SizedBox(height: 16),
              ...options.map((opt) {
                bool isSelected = opt['nome'].toString().toLowerCase() == currentValue.toLowerCase();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryOrange.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppTheme.primaryOrange : Colors.grey.shade200, width: 1.5),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Icon(opt['icone'], color: isSelected ? AppTheme.primaryOrange : AppTheme.textGray),
                    title: Text(opt['nome'], style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? AppTheme.primaryOrange : AppTheme.textDark)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppTheme.primaryOrange, size: 24) : null,
                    onTap: () {
                      onSelected(opt['nome']);
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _openMultiSelectRestrictionsModal(dynamic currentRestricoes) {
    List<String> listAtual = [];
    if (currentRestricoes is List) {
      listAtual = List<String>.from(currentRestricoes.map((e) => e.toString().trim()));
    } else if (currentRestricoes is String && currentRestricoes.trim().isNotEmpty) {
      listAtual = currentRestricoes.split(',').map((e) => e.trim()).toList();
    }

    List<Map<String, dynamic>> opcoes = [
      {'nome': 'Nenhuma', 'icone': Icons.check_circle_outline},
      {'nome': 'Glúten', 'icone': Icons.bakery_dining},
      {'nome': 'Lactose', 'icone': Icons.water_drop},
      {'nome': 'Nozes', 'icone': Icons.spa},
      {'nome': 'Frutos do mar', 'icone': Icons.set_meal},
      {'nome': 'Açúcar', 'icone': Icons.icecream},
      {'nome': 'Soja', 'icone': Icons.eco},
    ];

    Map<String, String> defaultMapLowerToExact = {};
    for (var opt in opcoes) {
      defaultMapLowerToExact[opt['nome'].toString().toLowerCase()] = opt['nome'].toString();
    }

    Set<String> selecionados = {};
    List<String> customItems = [];

    for (String item in listAtual) {
      if (item.isEmpty) continue;
      String itemLower = item.toLowerCase();
      if (defaultMapLowerToExact.containsKey(itemLower)) {
        selecionados.add(defaultMapLowerToExact[itemLower]!);
      } else if (itemLower != 'nenhuma') {
        if (item.contains(',')) {
          List<String> parts = item.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          for (var p in parts) {
            if (defaultMapLowerToExact.containsKey(p.toLowerCase())) {
              selecionados.add(defaultMapLowerToExact[p.toLowerCase()]!);
            } else if (p.toLowerCase() != 'nenhuma' && !customItems.contains(p)) {
              customItems.add(p);
            }
          }
        } else if (!customItems.contains(item)) {
          customItems.add(item);
        }
      }
    }

    String customValue = customItems.join(', ');
    TextEditingController outraCtrl = TextEditingController(text: customValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 16,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Alergias e Restrições', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: opcoes.map((opt) {
                      bool isSel = selecionados.contains(opt['nome']);
                      return FilterChip(
                        avatar: Icon(opt['icone'], size: 18, color: isSel ? Colors.white : AppTheme.textDark),
                        label: Text(opt['nome']),
                        selected: isSel,
                        showCheckmark: false,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        backgroundColor: Colors.grey.shade50,
                        selectedColor: AppTheme.primaryOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSel ? AppTheme.primaryOrange : Colors.grey.shade200)
                        ),
                        labelStyle: TextStyle(color: isSel ? Colors.white : AppTheme.textDark, fontWeight: isSel ? FontWeight.bold : FontWeight.w500),
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (opt['nome'] == 'Nenhuma') {
                              selecionados.clear();
                              if (selected) selecionados.add('Nenhuma');
                            } else {
                              selecionados.remove('Nenhuma');
                              if (selected) {
                                selecionados.add(opt['nome']);
                              } else {
                                selecionados.remove(opt['nome']);
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: outraCtrl,
                    decoration: InputDecoration(
                      hintText: 'Outra restrição específica...',
                      prefixIcon: const Icon(Icons.edit, color: AppTheme.textGray),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryOrange)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        List<String> defaultNames = opcoes.map((e) => e['nome'] as String).toList();
                        selecionados.removeWhere((item) => !defaultNames.contains(item));
                        
                        String customText = outraCtrl.text.trim();
                        if (customText.isNotEmpty) {
                          selecionados.remove('Nenhuma');
                          List<String> items = customText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          for (var i in items) {
                            if (!selecionados.contains(i)) {
                              selecionados.add(i);
                            }
                          }
                        }

                        List<String> resultado = selecionados.isEmpty ? ['Nenhuma'] : selecionados.toList();
                        _updateFields({
                          'restricoes': resultado,
                          'alergias': resultado,
                          'restricoesAlimentares': resultado,
                          'restricoes_alimentares': resultado,
                          'outraRestricao': customText,
                          'outra_restricao': customText,
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Salvar Restrições', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmarSair() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sair da Conta', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
        content: const Text('Deseja realmente desconectar da sua conta?', style: TextStyle(fontSize: 16, color: AppTheme.textGray)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _auth.signOut();

              if (mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthScreen()), 
                  (route) => false,
                );
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _excluirConta() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Excluir Conta', style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
        content: const Text('Esta ação excluirá permanentemente todos os seus dados e não poderá ser desfeita. Tem certeza?', style: TextStyle(fontSize: 16, color: AppTheme.textGray)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.textGray, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              User? user = _auth.currentUser;
              if (user != null) {
                String uid = user.uid;

                List<String> colecoesExpandidas = [
                  'historico', 'historico_diario', 'atividades', 'refeicoes', 'refeicao', 'agua', 'metas', 
                  'peso', 'jejum', 'ciclos', 'dados_menstruais', 'dadosMenstruacao', 'saude_feminina',
                  'treinos', 'exercicios', 'lembretes', 'notificacoes', 'diario'
                ];

                for (String sub in colecoesExpandidas) {
                  try {
                    var snap = await _firestore.collection('usuarios').doc(uid).collection(sub).get();
                    for (var doc in snap.docs) {
                      await doc.reference.delete();
                    }
                  } catch (_) {}
                  try {
                    var snapUsers = await _firestore.collection('users').doc(uid).collection(sub).get();
                    for (var doc in snapUsers.docs) {
                      await doc.reference.delete();
                    }
                  } catch (_) {}
                }

                for (String col in colecoesExpandidas) {
                  try {
                    await _firestore.collection(col).doc(uid).delete();
                    
                    var snapUserId = await _firestore.collection(col).where('userId', isEqualTo: uid).get();
                    for (var doc in snapUserId.docs) {
                      await doc.reference.delete();
                    }
                    var snapUid = await _firestore.collection(col).where('uid', isEqualTo: uid).get();
                    for (var doc in snapUid.docs) {
                      await doc.reference.delete();
                    }
                  } catch (_) {}
                }

                try {
                  await _firestore.collection('usuarios').doc(uid).delete();
                } catch (_) {}
                try {
                  await _firestore.collection('users').doc(uid).delete();
                } catch (_) {}

                bool authDeletado = false;
                try {
                  await user.delete();
                  authDeletado = true;
                } catch (_) {}

                try {
                  await _auth.signOut();
                } catch (_) {}

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()), 
                    (route) => false,
                  );

                  if (!authDeletado) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dados excluídos! Por segurança do Firebase, faça login novamente para confirmar a exclusão da conta de acesso.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        title: const Text('Configurações', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textDark, fontSize: 22)),
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textDark, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('usuarios').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange));
          }

          Map<String, dynamic> perfil = {};
          if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
            perfil = snapshot.data!.data() as Map<String, dynamic>;
          }

          String fotoUrl = _getValue(perfil, ['fotoUrl', 'foto_perfil'], '');
          String nome = _getValue(perfil, ['nome'], 'Usuário');
          int agua = _getValue(perfil, ['metaAgua', 'meta_agua'], 2000);
          dynamic pesoMeta = _getValue(perfil, ['metaPeso', 'meta_peso'], 0);
          int calConsumir = _getValue(perfil, ['metaCalorias', 'meta_calorias'], 2000);
          int calQueimar = _getValue(perfil, ['metaAtividade'], 300);
          int prot = _getValue(perfil, ['metaProteina', 'meta_proteina'], 0);
          int carbo = _getValue(perfil, ['metaCarbo', 'meta_carbo'], 0);
          int gord = _getValue(perfil, ['metaGordura', 'meta_gordura'], 0);

          String nivelAtividade = _getValue(perfil, ['nivelEsporte', 'nivel_atividade', 'nivelAtividade'], 'Pouco ativo');
          String dieta = _getValue(perfil, ['tipoDieta', 'dieta'], 'Equilibrada');
          
          dynamic restricoesRaw = _getValue(perfil, ['restricoes', 'alergias', 'restricoesAlimentares', 'restricoes_alimentares'], 'Nenhuma');
          dynamic outraRestricaoRaw = _getValue(perfil, ['outraRestricao', 'outra_restricao', 'outrasRestricoes'], '');

          List<String> restricoesCombinadas = [];
          if (restricoesRaw is List) {
            restricoesCombinadas = List<String>.from(restricoesRaw.map((e) => e.toString().trim()));
          } else if (restricoesRaw is String && restricoesRaw.isNotEmpty) {
            restricoesCombinadas = restricoesRaw.split(',').map((e) => e.trim()).toList();
          }

          if (outraRestricaoRaw != null && outraRestricaoRaw.toString().trim().isNotEmpty) {
            String customVal = outraRestricaoRaw.toString().trim();
            if (!restricoesCombinadas.contains(customVal)) {
              restricoesCombinadas.remove('Nenhuma');
              restricoesCombinadas.add(customVal);
            }
          }

          String restricoesTexto = restricoesCombinadas.isEmpty ? 'Nenhuma' : restricoesCombinadas.join(', ');

          dynamic rawLembretes = _getValue(perfil, ['lembretes', 'lembrete', 'lembretesAtivos', 'lembretes_ativos', 'notificacoes', 'notificacoesAtivas'], null);
          String rawOpcao = _getValue(perfil, ['opcaoLembrete', 'opcao_lembrete', 'frequenciaLembrete', 'frequencia_lembretes', 'horarioLembrete'], '').toString().trim();

          String normalizar(String texto) {
            return texto.toLowerCase()
                .replaceAll('ã', 'a').replaceAll('á', 'a').replaceAll('â', 'a')
                .replaceAll('é', 'e').replaceAll('ê', 'e')
                .replaceAll('í', 'i')
                .replaceAll('ó', 'o').replaceAll('ô', 'o')
                .replaceAll('ú', 'u')
                .trim();
          }

          
          String textoOpcao = rawOpcao;
          if (textoOpcao.isEmpty && rawLembretes is String) {
            textoOpcao = rawLembretes;
          }

          String opcaoNorm = normalizar(textoOpcao);
          List<String> termosDesativados = ['nao quero lembretes', 'nenhuma', 'nenhum', 'desativado', 'desativada', 'off', 'false', '0', 'nao', ''];

          String opcaoLembrete;

 
          if (opcaoNorm.isNotEmpty && !termosDesativados.contains(opcaoNorm)) {
           
            opcaoLembrete = textoOpcao;
          } else if (rawLembretes == true || normalizar(rawLembretes.toString()) == 'true' || normalizar(rawLembretes.toString()) == 'ativo') {
            
            opcaoLembrete = 'De manhã'; 
          } else {
            opcaoLembrete = 'Não quero lembretes';
          }

          String mascote = _getValue(perfil, ['mascotName', 'nomeMascote'], 'Bixinho');
          List<String> ordemCards = List<String>.from(_getValue(perfil, ['ordemCards'], ['calorias', 'atividades', 'plano', 'agua', 'peso', 'jejum']));

          String genero = _getValue(perfil, ['sexo', 'genero'], 'Não informado');
          dynamic idade = _getValue(perfil, ['idade'], 0);
          dynamic altura = _getValue(perfil, ['altura'], 0);
          dynamic pesoAtual = _getValue(perfil, ['peso'], 0);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            children: [
              _buildProfileHeader(fotoUrl, nome, user?.email ?? ''),

              const SizedBox(height: 32),

              _buildSectionHeader('METAS'),
              _buildCardTile(
                icon: Icons.water_drop,
                iconColor: Colors.blue,
                title: 'Meta de Água',
                subtitle: '$agua ml',
                onTap: () => _openTextEditor(
                  title: 'Meta de Água',
                  fieldKeys: ['metaAgua', 'meta_agua'],
                  currentValue: agua,
                  keyboardType: TextInputType.number,
                  unit: 'ml',
                ),
              ),
              _buildCardTile(
                icon: Icons.monitor_weight,
                iconColor: Colors.teal,
                title: 'Meta de Peso',
                subtitle: '$pesoMeta kg',
                onTap: () {
                  double h = altura is num ? altura.toDouble() : 0.0;
                  _openTextEditor(
                    title: 'Meta de Peso',
                    fieldKeys: ['metaPeso', 'meta_peso'],
                    currentValue: pesoMeta,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    unit: 'kg',
                    validator: (val) {
                      if (val == null || val <= 0) return 'Insira um peso válido.';
                      if (h > 0) {
                        double heightM = h / 100.0;
                        double bmi = val / (heightM * heightM);
                        if (bmi < 15.0) return 'Atenção: Meta muito baixa e não saudável para sua altura.';
                        if (bmi > 45.0) return 'Atenção: Meta muito alta e desproporcional para sua altura.';
                      }
                      return null;
                    }
                  );
                },
              ),
              _buildCardTile(
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                title: 'Calorias a Consumir',
                subtitle: '$calConsumir kcal',
                onTap: () => _openTextEditor(
                  title: 'Calorias a Consumir',
                  fieldKeys: ['metaCalorias', 'meta_calorias'],
                  currentValue: calConsumir,
                  keyboardType: TextInputType.number,
                  unit: 'kcal',
                ),
              ),
              _buildCardTile(
                icon: Icons.donut_small_rounded,
                iconColor: Colors.purple,
                title: 'Macronutrientes',
                subtitle: 'P: ${prot}g | C: ${carbo}g | G: ${gord}g',
                onTap: () => _openMacrosEditor(perfil),
              ),
              _buildCardTile(
                icon: Icons.fitness_center,
                iconColor: Colors.deepOrange,
                title: 'Meta de Atividade (Queima)',
                subtitle: '$calQueimar kcal', 
                onTap: () => _openTextEditor(
                  title: 'Meta de Atividade',
                  fieldKeys: ['metaAtividade'], 
                  currentValue: calQueimar,
                  keyboardType: TextInputType.number,
                  unit: 'kcal',
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('ESTILO DE VIDA E DIETA'),
              _buildCardTile(
                icon: Icons.directions_run,
                iconColor: Colors.green,
                title: 'Nível de Atividade',
                subtitle: nivelAtividade,
                onTap: () => _openSingleSelectModal(
                  title: 'Nível de Atividade',
                  options: [
                    {'nome': 'Não ativo', 'icone': Icons.weekend},
                    {'nome': 'Pouco ativo', 'icone': Icons.directions_walk},
                    {'nome': 'Moderadamente ativo', 'icone': Icons.directions_run},
                    {'nome': 'Muito ativo', 'icone': Icons.fitness_center},
                    {'nome': 'Extremamente ativo', 'icone': Icons.local_fire_department},
                  ],
                  currentValue: nivelAtividade,
                  onSelected: (val) => _updateFields({'nivelEsporte': val, 'nivel_atividade': val}),
                ),
              ),
              _buildCardTile(
                icon: Icons.restaurant_menu,
                iconColor: Colors.amber.shade800,
                title: 'Dieta',
                subtitle: dieta,
                onTap: () => _openSingleSelectModal(
                  title: 'Tipo de Dieta',
                  options: [
                    {'nome': 'Equilibrada', 'icone': Icons.restaurant_menu},
                    {'nome': 'Vegetariana', 'icone': Icons.grass},
                    {'nome': 'Vegana', 'icone': Icons.eco},
                    {'nome': 'Paleo', 'icone': Icons.kebab_dining},
                    {'nome': 'Cetogênica', 'icone': Icons.set_meal},
                    {'nome': 'Rica em proteínas', 'icone': Icons.egg_alt},
                  ],
                  currentValue: dieta,
                  onSelected: (val) => _updateFields({'tipoDieta': val, 'dieta': val}),
                ),
              ),
              _buildCardTile(
                icon: Icons.block,
                iconColor: Colors.redAccent,
                title: 'Alergias e Restrições',
                subtitle: restricoesTexto,
                onTap: () => _openMultiSelectRestrictionsModal(restricoesCombinadas),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('APLICATIVO'),
              _buildCardTile(
                icon: Icons.pets,
                iconColor: Colors.pink,
                title: 'Nome do Mascote',
                subtitle: mascote,
                onTap: () => _openTextEditor(
                  title: 'Nome do Mascote',
                  fieldKeys: ['mascotName', 'nomeMascote'],
                  currentValue: mascote,
                ),
              ),
              _buildCardTile(
                icon: Icons.swap_vert,
                iconColor: Colors.blueGrey,
                title: 'Posição dos Cards',
                subtitle: 'Reorganizar ordem da tela inicial',
                onTap: () async {
                  final novaOrdem = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ReorderCardsScreen(ordemAtual: ordemCards)),
                  );
                  if (novaOrdem != null) {
                    _updateFields({'ordemCards': novaOrdem});
                  }
                },
              ),
              _buildCardTile(
                icon: Icons.notifications_active,
                iconColor: AppTheme.primaryOrange,
                title: 'Lembretes',
                subtitle: opcaoLembrete,
                onTap: () => _openLembretesModal(opcaoLembrete),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('DADOS PESSOAIS'),
              _buildCardTile(
                icon: Icons.person,
                iconColor: Colors.indigo,
                title: 'Nome',
                subtitle: nome,
                onTap: () => _openTextEditor(
                  title: 'Nome',
                  fieldKeys: ['nome'],
                  currentValue: nome,
                ),
              ),
              _buildCardTile(
                icon: Icons.wc,
                iconColor: Colors.purple,
                title: 'Gênero',
                subtitle: genero,
                onTap: () => _openSingleSelectModal(
                  title: 'Gênero Biológico',
                  options: [
                    {'nome': 'Feminino', 'icone': Icons.female},
                    {'nome': 'Masculino', 'icone': Icons.male},
                  ], 
                  currentValue: genero,
                  onSelected: (val) => _updateFields({'sexo': val, 'genero': val}),
                ),
              ),
              _buildCardTile(
                icon: Icons.cake,
                iconColor: Colors.orange,
                title: 'Idade',
                subtitle: '$idade anos',
                onTap: () => _openTextEditor(
                  title: 'Idade',
                  fieldKeys: ['idade'],
                  currentValue: idade,
                  keyboardType: TextInputType.number,
                  unit: 'anos',
                ),
              ),
              _buildCardTile(
                icon: Icons.height,
                iconColor: Colors.cyan,
                title: 'Altura',
                subtitle: '$altura cm',
                onTap: () => _openTextEditor(
                  title: 'Altura',
                  fieldKeys: ['altura'],
                  currentValue: altura,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  unit: 'cm',
                ),
              ),
              _buildCardTile(
                icon: Icons.monitor_weight_outlined,
                iconColor: Colors.green,
                title: 'Peso Atual',
                subtitle: '$pesoAtual kg',
                onTap: () => _openTextEditor(
                  title: 'Peso Atual',
                  fieldKeys: ['peso'],
                  currentValue: pesoAtual,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  unit: 'kg',
                ),
              ),

              const SizedBox(height: 24),

              _buildSectionHeader('CONTA E SUPORTE'),
              
              _buildDeveloperCard(),
              const SizedBox(height: 12),

              _buildCardTile(
                icon: Icons.description_outlined,
                iconColor: Colors.grey.shade700,
                title: 'Termos de Serviço e Privacidade',
                subtitle: 'Versão 1.0.0',
                onTap: () {
                  String termosProfissionais = '''Termos de Serviço e Política de Privacidade

1. ACEITAÇÃO DOS TERMOS
Ao acessar e usar este aplicativo, você concorda em cumprir e estar vinculado a estes Termos de Serviço. Se você não concorda com qualquer parte destes termos, não deve usar nossos serviços.

2. COLETA DE DADOS PESSOAIS
Coletamos informações pessoais essenciais para o funcionamento do aplicativo, que incluem, mas não se limitam a: nome, e-mail, idade, peso, altura, gênero e metas de saúde. Estes dados são estritamente utilizados para personalizar sua experiência.

3. USO DAS INFORMAÇÕES
As informações fornecidas são utilizadas de forma algorítmica para o cálculo preciso de metas nutricionais, acompanhamento de atividades físicas, hidratação e melhoria contínua da inteligência do aplicativo.

4. ARMAZENAMENTO E SEGURANÇA
Seus dados são armazenados em servidores seguros, com criptografia de ponta a ponta durante a transmissão. Implementamos medidas de segurança robustas no padrão da indústria para proteger suas informações contra acesso não autorizado, alteração, divulgação ou destruição.

5. COMPARTILHAMENTO DE DADOS
Temos um compromisso rigoroso com a sua privacidade. Não vendemos, não alugamos e não compartilhamos suas informações pessoais com terceiros para fins publicitários. O compartilhamento só ocorrerá se exigido por mandado judicial ou obrigações legais.

6. DIREITOS DO USUÁRIO
Você possui total controle sobre seus dados. A qualquer momento, você tem o direito de acessar, retificar e excluir permanentemente suas informações pessoais utilizando as opções disponíveis nas Configurações do aplicativo.

7. SAÚDE E ISENÇÃO DE RESPONSABILIDADE MÉDICA
Este aplicativo fornece estimativas baseadas em fórmulas padrão de nutrição e condicionamento físico. Ele NÃO substitui o aconselhamento, diagnóstico ou tratamento médico profissional. Consulte sempre um médico ou nutricionista certificado antes de iniciar qualquer dieta ou programa de exercícios.

8. ALTERAÇÕES NOS TERMOS
Reservamo-nos o direito de atualizar ou modificar estes termos a qualquer momento, sem aviso prévio. O uso continuado do aplicativo após quaisquer alterações constitui a aceitação dos novos Termos. Recomendamos que você revise esta página periodicamente.''';

                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        height: MediaQuery.of(context).size.height * 0.75,
                        child: Column(
                          children: [
                            const Text('Termos e Privacidade', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Scrollbar(
                                child: SingleChildScrollView(
                                  child: Text(
                                    termosProfissionais,
                                    style: const TextStyle(fontSize: 15, height: 1.6, color: AppTheme.textGray),
                                    textAlign: TextAlign.justify,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryOrange,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Compreendi e Aceito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              _buildCardTile(
                icon: Icons.logout,
                iconColor: Colors.redAccent,
                title: 'Sair da Conta',
                subtitle: 'Desconectar sessão em segurança',
                onTap: _confirmarSair,
                isDangerous: true,
              ),
              _buildCardTile(
                icon: Icons.delete_forever,
                iconColor: Colors.red,
                title: 'Excluir Minha Conta',
                subtitle: 'Ação permanente e irreversível',
                onTap: _excluirConta,
                isDangerous: true,
              ),

              const SizedBox(height: 50),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String photoUrl, String name, String email) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 165,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/fundo.jpeg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: AppTheme.primaryOrange.withOpacity(0.1),
                          backgroundImage: _getProfileImage(photoUrl),
                          // ignore: unnecessary_null_comparison
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 45, color: AppTheme.primaryOrange)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _openPhotoPicker(photoUrl),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange, 
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textDark),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textGray, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeveloperCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.pink.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.pink.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: Image.network(
                    'https://cdn-icons-png.flaticon.com/512/174/174855.png',
                    width: 32,
                    height: 32,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Desenvolvido por', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
                      Text('Rayane Duque', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                      SizedBox(height: 2),
                      Text('Aluna de Análise de Sistemas da Unifeob', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple.shade700,
                      side: BorderSide(color: Colors.purple.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _launchURL('https://www.instagram.com/_rayduque?stkn=MXBxbmN3emxmanRiYQ=='),
                    child: const Text('@_rayduque', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.pink.shade700,
                      side: BorderSide(color: Colors.pink.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _launchURL('https://www.instagram.com/unifeob_oficial?stkn=ZTJ5a2J4NXpoNGx4'),
                    child: const Text('@unifeob_oficial', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível abrir o link')));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryOrange, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildCardTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDangerous = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDangerous ? Colors.red.shade100 : Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDangerous ? Colors.red.shade700 : AppTheme.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: isDangerous ? Colors.red.shade300 : AppTheme.textGray, fontWeight: FontWeight.w500),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: isDangerous ? Colors.red.shade200 : Colors.grey.shade300,
          size: 18,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryOrange,
        secondary: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
      ),
    );
  }
}

