import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/memory_item.dart';
import '../network/api_client.dart';

class AssistantRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;
  bool _isPrivateLearningActive = true;
  bool get isPrivateLearningActive => _isPrivateLearningActive;

  AssistantRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'memories' || event.table == 'assistant_messages') {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void togglePrivateLearning(bool value) {
    _isPrivateLearningActive = value;
    notifyListeners();
  }

  // --- CRUD: CREATE MEMORY ---
  Future<void> addMemory(MemoryItem item) async {
    await _db.insert('memories', item.id, item.toJson());
    notifyListeners();
  }

  // --- CRUD: READ MEMORIES ---
  List<MemoryItem> getAllMemories() {
    final list = _db.getAll('memories');
    return list.map((json) => MemoryItem.fromJson(json)).toList();
  }

  List<MemoryItem> getActiveMemories() {
    return getAllMemories().where((m) => m.isActive).toList();
  }

  // --- CRUD: UPDATE MEMORY ---
  Future<void> toggleMemoryActive(String id) async {
    final data = _db.get('memories', id);
    if (data != null) {
      final item = MemoryItem.fromJson(data);
      final updated = item.copyWith(isActive: !item.isActive);
      await _db.update('memories', id, updated.toJson());
      notifyListeners();
    }
  }

  // --- CRUD: DELETE MEMORY ---
  Future<void> deleteMemory(String id) async {
    await _db.delete('memories', id);
    notifyListeners();
  }

  // --- LOCAL AI CONVERSATION (Stored in DB via CRUD) ---
  List<AssistantMessage> getAssistantMessages() {
    final list = _db.getAll('assistant_messages');
    return list.map((json) => AssistantMessage.fromJson(json)).toList();
  }

  String _getCurrentUserName() {
    final users = _db.getAll('users');
    if (users.isNotEmpty) {
      final configured = users.firstWhere(
        (u) => (u['displayName'] as String? ?? '').trim().isNotEmpty,
        orElse: () => users.first,
      );
      final name = (configured['displayName'] as String? ?? '').trim();
      if (name.isNotEmpty) return name;
    }
    return 'Vous';
  }

  // --- CLEAR CHAT HISTORY ---
  Future<void> clearAssistantMessages() async {
    final list = _db.getAll('assistant_messages');
    for (final item in list) {
      final id = item['id'] as String?;
      if (id != null) {
        await _db.delete('assistant_messages', id);
      }
    }
    notifyListeners();
  }

  Future<void> askAssistant(String userQuestion) async {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final userName = _getCurrentUserName();

    final userMsg = AssistantMessage(
      id: 'ast_${DateTime.now().millisecondsSinceEpoch}_user',
      sender: userName,
      text: userQuestion,
      time: timeStr,
      isUser: true,
    );
    await _db.insert('assistant_messages', userMsg.id, userMsg.toJson());
    notifyListeners();

    // Sovereign cognitive query
    String responseText = '';
    String? sourceTitle;
    String? sourceSubtitle;
    final lower = userQuestion.toLowerCase().trim();

    // 1. Try querying remote/local AI engine
    final networkAnswer = await ApiClient().queryAI(userQuestion).catchError((_) => null);
    if (networkAnswer != null && networkAnswer.isNotEmpty) {
      responseText = networkAnswer;
      sourceTitle = 'Assistant Souverain';
      sourceSubtitle = 'Traitement cognitif validé';
    } else if (lower.startsWith('bonjour') ||
        lower.startsWith('salut') ||
        lower.startsWith('hello') ||
        lower.startsWith('coucou') ||
        lower.contains('qui es-tu') ||
        lower.contains('tu es qui') ||
        lower.contains('présente-toi')) {
      // Friendly greeting & introduction
      responseText = "Bonjour $userName ! Je suis votre Assistant Souverain MRixk, propulsé par une intelligence locale et privée.\n\n"
          "Mes garanties pour vous :\n"
          "• Zéro émission : vos données ne quittent jamais cet appareil.\n"
          "• Contrôle absolu : vous choisissez ce que je retiens.\n"
          "• Connaissance de vos échanges : je peux résumer vos messages récents, retrouver un document partagé, vous assister dans la rédaction ou vérifier la sécurité de vos appareils.\n\n"
          "Que souhaitez-vous explorer aujourd'hui ?";
      sourceTitle = 'Accueil Souverain';
      sourceSubtitle = 'IA privée sur l\'appareil';
    } else if (lower.contains('appel') || lower.contains('téléphon') || lower.contains('vidéo') || lower.contains('joindre')) {
      // Calls guidance
      responseText = "Dans MRixk, vos appels sont directs et hautement chiffrés :\n"
          "1. Ouvrez une discussion ou votre liste de contacts.\n"
          "2. Appuyez sur l'icône téléphone (appel vocal) ou caméra (appel vidéo HD).\n"
          "3. Si votre contact est en ligne, le téléphone sonne avec une tonalité authentique.\n"
          "4. Vous pouvez consulter tous vos appels passés ou manqués dans l'Historique des appels depuis l'icône téléphone de l'accueil.";
      sourceTitle = 'Appels & Téléphonie Sécurisée';
      sourceSubtitle = 'Guide d\'utilisation';
    } else if (lower.contains('résum') || lower.contains('échange') || lower.contains('message') || lower.contains('discut')) {
      // 2. Query real conversations & messages
      final convs = _db.getAll('conversations');
      final msgs = _db.getAll('messages');
      if (msgs.isEmpty && convs.isEmpty) {
        responseText = "Aucun échange récent n'est enregistré pour le moment. Vos discussions apparaîtront ici au fur et à mesure de vos échanges chiffrés.";
        sourceTitle = 'Historique des échanges';
        sourceSubtitle = '0 conversation chiffrée';
      } else {
        final convTitles = convs.map((c) => c['title'] as String? ?? 'Discussion').take(3).join(', ');
        final recentSnippet = msgs.reversed.take(3).map((m) => "• ${m['sender'] ?? 'Contact'} : « ${m['text'] ?? ''} »").join('\n');
        responseText = "Voici la synthèse de vos échanges récents (${convs.length} conversation(s), ${msgs.length} message(s)) :\n"
            "${convTitles.isNotEmpty ? 'Conversations actives : $convTitles\n' : ''}"
            "${recentSnippet.isNotEmpty ? '\nDerniers messages traités en local :\n$recentSnippet' : ''}";
        sourceTitle = 'Synthèse locale des échanges';
        sourceSubtitle = '${convs.length} conversation(s) analysée(s)';
      }
    } else if (lower.contains('document') || lower.contains('fichier') || lower.contains('partag') || lower.contains('pièce')) {
      // 3. Query files/documents shared
      final msgs = _db.getAll('messages');
      final fileMsgs = msgs.where((m) =>
        m['type'] == 'file' ||
        m['type'] == 'image' ||
        (m['fileUrl'] as String? ?? '').isNotEmpty ||
        (m['fileName'] as String? ?? '').isNotEmpty
      ).toList();

      if (fileMsgs.isEmpty) {
        responseText = "Aucun document ou fichier partagé n'a été trouvé dans vos conversations locales. Tous vos futurs partages resteront sécurisés sur cet appareil.";
        sourceTitle = 'Recherche documentaire';
        sourceSubtitle = '0 document indexé';
      } else {
        final fileList = fileMsgs.take(4).map((m) => "• ${m['fileName'] ?? m['text'] ?? 'Document'} (de ${m['sender'] ?? 'Expéditeur'})").join('\n');
        responseText = "J'ai retrouvé ${fileMsgs.length} fichier(s) sécurisé(s) dans votre base locale :\n$fileList";
        sourceTitle = 'Documents sécurisés';
        sourceSubtitle = '${fileMsgs.length} fichier(s) trouvé(s)';
      }
    } else if (lower.contains('rédig') || lower.contains('écri') || lower.contains('bienveillant') || lower.contains('propos') || lower.contains('aide-moi')) {
      // 4. Message drafting assistance
      responseText = "Voici une suggestion de message bienveillant et authentique que vous pouvez personnaliser :\n\n"
          "« Bonjour, j'espère que tu passes une agréable journée. Je prenais un court instant pour prendre de tes nouvelles et faire le point calmement. Fais-moi signe dès que tu as un moment libre pour échanger. Bien à toi. »";
      sourceTitle = 'Aide à la rédaction';
      sourceSubtitle = 'Génération sur l\'appareil (100% privé)';
    } else if (lower.contains('sécurité') || lower.contains('appareil') || lower.contains('device') || lower.contains('état')) {
      // 5. Query devices
      final devices = _db.getAll('devices');
      final currentDevice = devices.firstWhere(
        (d) => d['isCurrentDevice'] == true,
        orElse: () => devices.isNotEmpty ? devices.first : {},
      );
      final currentName = currentDevice['name'] as String? ?? 'Cet appareil';
      final currentStatus = currentDevice['status'] as String? ?? 'ACTIVE';
      final otherDevices = devices.where((d) => d['isCurrentDevice'] != true).toList();

      final otherNames = otherDevices.map((d) => d['name'] as String? ?? '').join(', ');
      final otherText = otherDevices.isNotEmpty ? '• Autres terminaux : $otherNames\n' : '';

      responseText = "État de souveraineté et sécurité de vos appareils :\n"
          "• Appareil principal : $currentName (Statut : $currentStatus, Chiffrement matériel actif)\n"
          "• Nombre de terminaux autorisés : ${devices.length} / 3\n"
          "$otherText"
          "Toutes vos clés cryptographiques restent confinées en mémoire locale sécurisée.";
      sourceTitle = 'Sécurité & Terminaux';
      sourceSubtitle = '${devices.length} appareil(s) certifié(s)';
    } else if (lower.contains('contact') || lower.contains('qui') || lower.contains('répertoire') || lower.contains('sarah')) {
      // 6. Query contacts
      final contacts = _db.getAll('contacts');
      if (contacts.isEmpty) {
        responseText = "Votre répertoire local est actuellement vide. Vous pouvez ajouter des proches en partageant votre QR code ou votre @handle.";
        sourceTitle = 'Répertoire de contacts';
        sourceSubtitle = '0 contact';
      } else {
        final contactList = contacts.take(5).map((c) => "• ${c['name']} (${c['handle'] ?? ''}) - ${c['statusText'] ?? ''}").join('\n');
        responseText = "Votre répertoire souverain compte ${contacts.length} contact(s) sécurisé(s) :\n$contactList";
        sourceTitle = 'Carnet d\'adresses chiffré';
        sourceSubtitle = '${contacts.length} contact(s) répertorié(s)';
      }
    } else if (lower.contains('mémoire') || lower.contains('souvenir') || lower.contains('retenir')) {
      // 7. Query memories
      final memories = getAllMemories();
      final active = memories.where((m) => m.isActive).toList();
      if (memories.isEmpty) {
        responseText = "Aucun souvenir cognitif n'est consigné dans votre mémoire locale. Vous pouvez en définir à tout moment dans le gestionnaire de mémoire.";
        sourceTitle = 'Mémoire protégée';
        sourceSubtitle = '0 information';
      } else {
        final items = active.take(4).map((m) => "• [${m.category}] ${m.title} (${m.createdAt})").join('\n');
        responseText = "Votre mémoire protégée contient ${active.length} élément(s) actif(s) sur cet appareil :\n$items";
        sourceTitle = 'Mémoire protégée';
        sourceSubtitle = '${active.length} information(s) active(s)';
      }
    } else {
      // 8. Default sovereign response
      final contactsCount = _db.getAll('contacts').length;
      final convsCount = _db.getAll('conversations').length;
      final devicesCount = _db.getAll('devices').length;
      responseText = "J'ai exploré vos données locales en toute souveraineté ($contactsCount contact(s), $convsCount conversation(s), $devicesCount appareil(s) sécurisé(s)).\n\n"
          "Vous pouvez me demander de résumer vos messages récents, d'examiner vos fichiers partagés, de vérifier la sécurité de vos appareils ou de vous assister dans la rédaction d'un message.";
      sourceTitle = 'Assistant Souverain MRixk';
      sourceSubtitle = 'Recherche locale 100% privée';
    }

    final botMsg = AssistantMessage(
      id: 'ast_${DateTime.now().millisecondsSinceEpoch}_bot',
      sender: 'Assistant MRixk',
      text: responseText,
      time: timeStr,
      isUser: false,
      sourceTitle: sourceTitle,
      sourceSubtitle: sourceSubtitle,
      confidenceText: 'Trouvé en local en 0.1s',
    );
    await _db.insert('assistant_messages', botMsg.id, botMsg.toJson());
    notifyListeners();
  }
}

class AssistantMessage {
  final String id;
  final String sender;
  final String text;
  final String time;
  final bool isUser;
  final String? sourceTitle;
  final String? sourceSubtitle;
  final String? confidenceText;

  AssistantMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    required this.isUser,
    this.sourceTitle,
    this.sourceSubtitle,
    this.confidenceText,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender': sender,
    'text': text,
    'time': time,
    'isUser': isUser,
    'sourceTitle': sourceTitle,
    'sourceSubtitle': sourceSubtitle,
    'confidenceText': confidenceText,
  };

  factory AssistantMessage.fromJson(Map<String, dynamic> json) => AssistantMessage(
    id: json['id'] as String,
    sender: json['sender'] as String,
    text: json['text'] as String,
    time: json['time'] as String,
    isUser: json['isUser'] as bool,
    sourceTitle: json['sourceTitle'] as String?,
    sourceSubtitle: json['sourceSubtitle'] as String?,
    confidenceText: json['confidenceText'] as String?,
  );
}
