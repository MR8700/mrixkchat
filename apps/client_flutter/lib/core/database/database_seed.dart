import '../models/call_log.dart';
import '../models/contact.dart';
import '../models/conversation.dart';
import '../models/device.dart';
import '../models/memory_item.dart';
import '../models/message.dart';
import '../models/moment.dart';
import '../models/user_profile.dart';
import '../services/real_media_service.dart';
import 'local_database.dart';

/// Seeds clean production database: all test users, conversations & moments purged.
/// Does NOT configure any pre-set user name: the user defines their own identity on first open.
/// Contains strictly one single sovereign external contact who is offline (Dr. Sarah Connor),
/// with whom no conversation or messages exist yet.
Future<void> seedCleanProductionDatabase(LocalDatabase db) async {
  // 1. Devices CRUD insert (Single Current Device)
  final device = Device(
    id: 'dev_1',
    name: 'Téléphone Principal (Cet appareil)',
    platform: 'Android',
    status: 'ACTIVE',
    lastSeenText: "En cours d'utilisation",
    isCurrentDevice: true,
    iconType: 'phone',
  );
  await db.insert('devices', device.id, device.toJson());

  // 2. Exactly one single contact who is verified (Dr. Sarah Connor)
  final singleContact = Contact(
    id: 'contact_sarah',
    name: 'Dr. Sarah Connor',
    handle: '@sarah.connor',
    avatarUrl: '',
    statusText: 'Recherche & IA 🧬 (En ligne)',
    isOnline: true,
    isVerified: true,
    category: 'C',
  );
  await db.insert('contacts', singleContact.id, singleContact.toJson());

  // 3. Conversations: STRICTLY EMPTY (No existing discussion)
  // 4. Messages: STRICTLY EMPTY (No existing messages)
  // 5. Moments: STRICTLY EMPTY (No existing moments)
  // 6. Users: STRICTLY EMPTY until the user configures their own identity
}

/// Seeds genuine, verified test data via CRUD inserts when database starts.
/// Strictly avoids static dummy strings in UI: everything comes from LocalDatabase.
Future<void> seedInitialDatabase(LocalDatabase db) async {
  // 1. User Profile CRUD insert
  final userProfile = UserProfile(
    id: 'user_richard',
    displayName: 'Richard MARE',
    handle: '@mrixk.richard',
    avatarUrl:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBJtx5mIqkHnR5_2AEJl8whigZY1P-Ppsr3iWQkiIjIiVQPXBdk32qz6X3dFn-KKWmF_ZpzpYc-YKUrZXLqo5v5E8ygyzgG5f0WSq3-ynWbQb8xj1MmTxTjleMKRzK8Kv84gjNvBzhHTdfrURVdi4S-ATHWee_uf-tI3NgsJmh_Vzh03ey_MoJHwv1bgF-8SCz8_nqqpVioBLBzVSmGePs_PasRnd6V59ZN-kNAEAo',
    statusMessage: "Toujours à l'écoute des nouvelles idées 💡",
    isOnline: true,
    deviceQuotaMax: 3,
    notificationsEnabled: true,
    themeMode: 'Ivoire',
    storageUsed: '1.2 Go',
  );
  await db.insert('users', userProfile.id, userProfile.toJson());
  await db.insert('settings', 'identity_configured', {'value': true});

  // 2. Devices CRUD inserts (Strict 3-device limit)
  final devices = [
    Device(
      id: 'dev_1',
      name: 'Téléphone Android (Cet appareil)',
      platform: 'Android',
      status: 'ACTIVE',
      lastSeenText: "En cours d'utilisation",
      isCurrentDevice: true,
      iconType: 'phone',
    ),
    Device(
      id: 'dev_2',
      name: 'MacBook Personnel',
      platform: 'macOS',
      status: 'ACTIVE',
      lastSeenText: 'En ligne ce matin',
      isCurrentDevice: false,
      iconType: 'laptop',
    ),
    Device(
      id: 'dev_3',
      name: 'iPad Pro',
      platform: 'iPadOS',
      status: 'ACTIVE',
      lastSeenText: 'Dernier accès hier',
      isCurrentDevice: false,
      iconType: 'tablet',
    ),
  ];
  for (final dev in devices) {
    await db.insert('devices', dev.id, dev.toJson());
  }

  // 3. Contacts CRUD inserts
  final contacts = [
    Contact(
      id: 'contact_amine',
      name: 'Amine Traoré',
      handle: '@amine.t',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAuBQ0RKTsmuyjfJRR-hJdxA9SNEFh09g_Ov4yS5s2471sykVEphazwgTKYWIECqeIzyA0cDmqXRQRrY6oLIAwFPP693adrp-n7EPBs8NtjuTVAod9xKPoMZe6kqqbbMMscdME6jlMaBITdDtK9Aw6Dz7aD53hVbTEalcFy8BxL8MHc2bM2YWOQeA6wgBXH78Q_3Wp9ikF9EA1sN_ecZ6HaMxYl8ARjCKwf-pT8bgo',
      statusText: 'En réunion créative',
      isOnline: false,
      isVerified: false,
      category: 'A',
    ),
    Contact(
      id: 'contact_aicha',
      name: 'Aïcha Ouedraogo',
      handle: '@aicha.o',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD02H-MuDhFnd_RJp4r1ONoWSWGnzPH4dbB067x3wBHK8kfkn5sucx2JRTslG07dL9GmV3k9312ln_EQlClYchbXwqp9NvQ0PiTlyPyo8kKjep7cP7t6KCG2jf1JXQC0ljDvs6TvTuTU_QTl9J9J959ImP0j3tblgpcrYJJvC6-R8TAhwyZ-KEBtUw_NkhRvtfTAqwvFvGsvIKrNdQlhG_AGQMNSzB9XSyIZMB7vm8',
      statusText: 'Partage de sourires ✨',
      isOnline: true,
      isVerified: true,
      isFavorite: true,
      category: 'A',
    ),
    Contact(
      id: 'contact_marc',
      name: 'Marc Delaunay',
      handle: '@marc.d',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDjuOp01aCyGb3MiFLNhDNbsm94oULBnGlisJ--YvDoW8DA_pOKtkXqYP6GLqPufbOpWN9fpGWtkWAJ9wX0QZ_glIaV20_dKHtz7ol4EEbq56IWcyraPZ1XASWS91VZkcCpQ83130quWwsXOAzA0ro-qy5ySKzLZVWh-6_ZH_yJPsmDqUqGx5SeNpsVOjBFWl33-HjgbXukytL2Q3Vu_TIoAkyw2mVU6ObNaRuHAR4',
      statusText: 'En voyage ✈️',
      isOnline: false,
      isVerified: false,
      category: 'D',
    ),
    Contact(
      id: 'contact_sophie',
      name: 'Sophie Valade',
      handle: '@sophie.v',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      statusText: 'Disponible • Validations en cours',
      isOnline: true,
      isVerified: true,
      isFavorite: true,
      category: 'S',
    ),
    Contact(
      id: 'contact_kabore',
      name: 'Dr. Kaboré',
      handle: '@dr.kabore',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDDXHDsbPZs3w3OxjcicYHePM7mxqc3YNtZF2IwcdikrFCwBGWkxp_GL5L6DH6tKSg1thshfY9TyfMxSgbCt4KzSi1H1M4apB_TL9Q6U_BN96R2dMWstkLfbOzC_MDnJq3ZiOHzp2II8YN36cJlRLNwFnZGhp7oO2kuIPQb8qjimw1QUh9lh_wUWq9vCrzTJvEo1-PySVpdO9UXQrnWYQku9z9nZgdBKmrnq9Kyf2s',
      statusText: 'En consultation bienveillante',
      isOnline: false,
      isVerified: true,
      category: 'K',
    ),
    Contact(
      id: 'contact_idriss',
      name: 'Dr. Idriss Traoré',
      handle: '@idriss.t',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPFAiD9Og5A8GtV1bmuIbN_eye-Uhvv5nO328ezbs4q4UUuEuMtM9kBVqGlHpXDbmxYD82XU9hARxi-KtSPWrW9i7L0sGfZLhmuhyhVyYYiqyIzQnmc896G3h9Jf-izVUbf4LY_bZKYBXK-z74Ql6WnBlZLEeJzzgQd47iFcXEgwEAx5TeCsLEqMyI6P3wau72sDeU2NzBDrYbfom1fYZPpjF3uYYgktrK-nz4t4w',
      statusText: 'Partenariat & Santé',
      isOnline: true,
      isVerified: true,
      category: 'T',
    ),
  ];
  for (final c in contacts) {
    await db.insert('contacts', c.id, c.toJson());
  }

  // 4. Conversations CRUD inserts
  final conversations = [
    Conversation(
      id: 'conv_sophie',
      title: 'Sophie Valade',
      peerAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      isOnline: true,
      isVerified: true,
      lastMessage: "Je t'ai envoyé la note vocale sur les avancées du projet !",
      lastMessageTime: '10:42',
      unreadCount: 2,
      hasVoiceNote: true,
      voiceNoteDuration: '0:42',
      isFavorite: true,
      tagText: 'Privé',
    ),
    Conversation(
      id: 'conv_group_mrixk',
      title: 'Équipe Projet MRixk',
      peerAvatar: '',
      isGroup: true,
      groupMembersCount: 5,
      description: 'Groupe de coordination souverain pour le projet MRixk. Débats techniques, formules mathématiques et architecture E2EE.',
      lastMessage: 'Marc : Les protocoles de validation sont validés 🎉',
      lastMessageTime: '09:15',
      unreadCount: 0,
      tagText: 'Projet équipe',
      groupMembers: const [
        GroupMember(
          id: 'user_richard',
          name: 'Richard MARE (Moi)',
          handle: '@mrixk.richard',
          avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBJtx5mIqkHnR5_2AEJl8whigZY1P-Ppsr3iWQkiIjIiVQPXBdk32qz6X3dFn-KKWmF_ZpzpYc-YKUrZXLqo5v5E8ygyzgG5f0WSq3-ynWbQb8xj1MmTxTjleMKRzK8Kv84gjNvBzhHTdfrURVdi4S-ATHWee_uf-tI3NgsJmh_Vzh03ey_MoJHwv1bgF-8SCz8_nqqpVioBLBzVSmGePs_PasRnd6V59ZN-kNAEAo',
          role: 'creator',
          connectedDevicesCount: 3,
        ),
        GroupMember(
          id: 'contact_sophie',
          name: 'Sophie Valade',
          handle: '@sophie.v',
          avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
          role: 'admin',
          connectedDevicesCount: 2,
        ),
        GroupMember(
          id: 'contact_marc',
          name: 'Marc Delaunay',
          handle: '@marc.d',
          avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDjuOp01aCyGb3MiFLNhDNbsm94oULBnGlisJ--YvDoW8DA_pOKtkXqYP6GLqPufbOpWN9fpGWtkWAJ9wX0QZ_glIaV20_dKHtz7ol4EEbq56IWcyraPZ1XASWS91VZkcCpQ83130quWwsXOAzA0ro-qy5ySKzLZVWh-6_ZH_yJPsmDqUqGx5SeNpsVOjBFWl33-HjgbXukytL2Q3Vu_TIoAkyw2mVU6ObNaRuHAR4',
          role: 'member',
          connectedDevicesCount: 1,
        ),
        GroupMember(
          id: 'contact_amine',
          name: 'Amine Traoré',
          handle: '@amine.t',
          avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAuBQ0RKTsmuyjfJRR-hJdxA9SNEFh09g_Ov4yS5s2471sykVEphazwgTKYWIECqeIzyA0cDmqXRQRrY6oLIAwFPP693adrp-n7EPBs8NtjuTVAod9xKPoMZe6kqqbbMMscdME6jlMaBITdDtK9Aw6Dz7aD53hVbTEalcFy8BxL8MHc2bM2YWOQeA6wgBXH78Q_3Wp9ikF9EA1sN_ecZ6HaMxYl8ARjCKwf-pT8bgo',
          role: 'member',
          connectedDevicesCount: 2,
        ),
        GroupMember(
          id: 'contact_aicha',
          name: 'Aïcha Ouedraogo',
          handle: '@aicha.o',
          avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD02H-MuDhFnd_RJp4r1ONoWSWGnzPH4dbB067x3wBHK8kfkn5sucx2JRTslG07dL9GmV3k9312ln_EQlClYchbXwqp9NvQ0PiTlyPyo8kKjep7cP7t6KCG2jf1JXQC0ljDvs6TvTuTU_QTl9J9J959ImP0j3tblgpcrYJJvC6-R8TAhwyZ-KEBtUw_NkhRvtfTAqwvFvGsvIKrNdQlhG_AGQMNSzB9XSyIZMB7vm8',
          role: 'member',
          connectedDevicesCount: 1,
        ),
      ],
    ),
    Conversation(
      id: 'conv_idriss',
      title: 'Dr. Idriss Traoré',
      peerAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPFAiD9Og5A8GtV1bmuIbN_eye-Uhvv5nO328ezbs4q4UUuEuMtM9kBVqGlHpXDbmxYD82XU9hARxi-KtSPWrW9i7L0sGfZLhmuhyhVyYYiqyIzQnmc896G3h9Jf-izVUbf4LY_bZKYBXK-z74Ql6WnBlZLEeJzzgQd47iFcXEgwEAx5TeCsLEqMyI6P3wau72sDeU2NzBDrYbfom1fYZPpjF3uYYgktrK-nz4t4w',
      isOnline: true,
      isVerified: true,
      lastMessage: 'Document partagé : Contrat de partenariat signé',
      lastMessageTime: 'Hier',
      unreadCount: 0,
      hasDocument: true,
      tagText: 'Partenaire',
    ),
    Conversation(
      id: 'conv_aicha',
      title: 'Aïcha Ouedraogo',
      peerAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuD02H-MuDhFnd_RJp4r1ONoWSWGnzPH4dbB067x3wBHK8kfkn5sucx2JRTslG07dL9GmV3k9312ln_EQlClYchbXwqp9NvQ0PiTlyPyo8kKjep7cP7t6KCG2jf1JXQC0ljDvs6TvTuTU_QTl9J9J959ImP0j3tblgpcrYJJvC6-R8TAhwyZ-KEBtUw_NkhRvtfTAqwvFvGsvIKrNdQlhG_AGQMNSzB9XSyIZMB7vm8',
      lastMessage: 'Message vocal • 1 min 18 s',
      lastMessageTime: 'Hier',
      unreadCount: 0,
      hasVoiceNote: true,
      voiceNoteDuration: '1:18',
    ),
    Conversation(
      id: 'conv_vault',
      title: 'Espace Personnel & Coffre',
      peerAvatar: '',
      lastMessage: 'Notes personnelles et souvenirs sauvegardés.',
      lastMessageTime: '02 Nov',
      unreadCount: 0,
      tagText: 'Mémoire personnelle protégée',
    ),
  ];
  for (final conv in conversations) {
    await db.insert('conversations', conv.id, conv.toJson());
  }

  // 5. Messages CRUD inserts (Sophie Valade conversation)
  final sophieMessages = [
    Message(
      id: 'msg_1',
      conversationId: 'conv_sophie',
      senderId: 'contact_sophie',
      senderName: 'Sophie Valade',
      senderAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      type: MessageType.text,
      content:
          "Bonjour Richard ! J'ai terminé toutes les vérifications de la nouvelle version. Tout fonctionne parfaitement et respecte l'ensemble de nos exigences de confidentialité.",
      time: '10:38',
      isOutgoing: false,
      isVerifiedSignature: true,
    ),
    Message(
      id: 'msg_2',
      conversationId: 'conv_sophie',
      senderId: 'user_richard',
      senderName: 'Richard MARE',
      senderAvatar: userProfile.avatarUrl,
      type: MessageType.text,
      content:
          'Excellente nouvelle ! As-tu eu le temps de vérifier la recherche instantanée et la sauvegarde directe sur le téléphone ?',
      time: '10:39',
      isOutgoing: true,
      isVerifiedSignature: true,
    ),
    Message(
      id: 'msg_3',
      conversationId: 'conv_sophie',
      senderId: 'contact_sophie',
      senderName: 'Sophie Valade',
      senderAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      type: MessageType.voice,
      content: 'Note vocale confidentielle',
      time: '10:41',
      isOutgoing: false,
      isVerifiedSignature: true,
      voiceDuration: '1:15',
      voiceUri: RealMediaService.generateAuthenticWavDataUri(durationSeconds: 3, frequency: 160.0),
      voiceTranscription:
          '« Les validations sont terminées, tout est prêt pour le lancement. »',
      waveform: [
        0.3, 0.5, 0.8, 0.4, 0.9, 0.6, 0.3, 0.7, 0.4, 0.6, 0.8, 0.5, 0.3, 0.6, 0.4, 0.7, 0.2
      ],
    ),
    Message(
      id: 'msg_4',
      conversationId: 'conv_sophie',
      senderId: 'user_richard',
      senderName: 'Richard MARE',
      senderAvatar: userProfile.avatarUrl,
      type: MessageType.document,
      content: 'Dossier partagé',
      time: '10:42',
      isOutgoing: true,
      fileName: 'Dossier_Lancement_Final.pdf',
      fileSize: '2.8 Mo',
      fileType: 'PDF',
      reactions: {'👍': 1, '✨': 1},
    ),
    Message(
      id: 'msg_5',
      conversationId: 'conv_sophie',
      senderId: 'contact_sophie',
      senderName: 'Sophie Valade',
      senderAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      type: MessageType.image,
      content: 'Aperçu de la maquette architecture 📷',
      time: '10:43',
      isOutgoing: false,
      imageUri: '/imagetest.png',
      reactions: {'❤️': 1},
    ),
    Message(
      id: 'msg_6',
      conversationId: 'conv_sophie',
      senderId: 'contact_sophie',
      senderName: 'Sophie Valade',
      senderAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      type: MessageType.video,
      content: 'Démonstration du flux cryptographique 🎬',
      time: '10:44',
      isOutgoing: false,
      videoUri: 'https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4',
      videoDuration: '0:45',
      reactions: {'🔥': 1},
    ),
  ];
  for (final msg in sophieMessages) {
    await db.insert('messages', msg.id, msg.toJson());
  }

  // 6. Moments CRUD inserts
  final moments = [
    Moment(
      id: 'moment_sophie',
      authorId: 'contact_sophie',
      authorName: 'Sophie Valade',
      authorAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      authorBadge: 'verified',
      type: MomentType.image,
      timeAgo: 'Il y a 27 minutes • Vue sur mer',
      caption:
          "Une pause bien méritée après une belle semaine d’équipe ! Le bruit des vagues pour recharger l'esprit 🌅✨",
      mediaUrl: '/imagetest.png',
      location: 'Biarritz, Côte Basque',
      heartCount: 24,
      moodCount: 8,
      celebrationCount: 5,
      commentCount: 4,
    ),
    Moment(
      id: 'moment_kabore',
      authorId: 'contact_kabore',
      authorName: 'Dr. Kaboré',
      authorAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDDXHDsbPZs3w3OxjcicYHePM7mxqc3YNtZF2IwcdikrFCwBGWkxp_GL5L6DH6tKSg1thshfY9TyfMxSgbCt4KzSi1H1M4apB_TL9Q6U_BN96R2dMWstkLfbOzC_MDnJq3ZiOHzp2II8YN36cJlRLNwFnZGhp7oO2kuIPQb8qjimw1QUh9lh_wUWq9vCrzTJvEo1-PySVpdO9UXQrnWYQku9z9nZgdBKmrnq9Kyf2s',
      authorBadge: 'Conseil',
      type: MomentType.voice,
      timeAgo: 'Ce matin à 08:45 • Note vocale',
      caption:
          "Petite pensée sur l'équilibre, le souffle et le plaisir d'avancer à son propre tempo aujourd'hui 🍃",
      voiceTitle: 'Douceur matinale',
      voiceDuration: '0:14 / 0:32',
      heartCount: 42,
    ),
    Moment(
      id: 'moment_amine',
      authorId: 'contact_amine',
      authorName: 'Amine T.',
      authorAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC0dOsE9NJ79A4_LFe9DGoDMHbyXKCJP3pFqVJGSrpLz0Xs7e_SR9b0s2JvWxfMsHnwkOi-nsVbS8KuGCZyoNAno-cog1JrW6iAovJNYW7IZjryPZpqhP50cXpVwx72303m05y4EecFjnaaMqFex5PuuwMHJomOF2YedrYODOTf3EcejTDxVUZq6Ku3v2bvjPl8mbUbQZlcmzpV6HxRNTyfb7kuvEJ7apkkJRtemTU',
      authorBadge: 'stars',
      type: MomentType.quote,
      timeAgo: 'Hier • Célébration collective',
      caption:
          'Objectif du mois atteint ! Merci à tous pour l’énergie partagée et la bienveillance au quotidien 🚀✨',
      heartCount: 38,
      moodCount: 19,
      celebrationCount: 12,
    ),
  ];
  for (final m in moments) {
    await db.insert('moments', m.id, m.toJson());
  }

  // 7. Personal Cognitive Memories CRUD inserts
  final memories = [
    MemoryItem(
      id: 'mem_1',
      title: 'Projet MRixk : Architecture cible',
      detail: 'Source: Document interne • Confiance: 98% • Déclaré',
      category: 'Projet',
      confidence: 0.98,
      createdAt: 'Aujourd\'hui',
    ),
    MemoryItem(
      id: 'mem_2',
      title: 'Référence contrat #CTR-2024-88B',
      detail: 'Signé le 14 février avec le studio • Pièce jointe chiffrée',
      category: 'Contrat',
      confidence: 0.99,
      createdAt: 'Aujourd\'hui',
    ),
    MemoryItem(
      id: 'mem_3',
      title: 'Préférence de langue : Français',
      detail: 'Source: Préférences utilisateur • Validé',
      category: 'Préférence',
      confidence: 1.0,
      createdAt: '01 Nov',
    ),
    MemoryItem(
      id: 'mem_4',
      title: 'Équipe de confiance synchronisée',
      detail: 'Sophie Valade, Amine Traoré, Dr. Kaboré • Clés vérifiées',
      category: 'Réseau',
      confidence: 0.96,
      createdAt: '02 Nov',
    ),
  ];
  for (final mem in memories) {
    await db.insert('memories', mem.id, mem.toJson());
  }

  // 8. Call History CRUD inserts
  final initialCallLogs = [
    CallLog(
      id: 'call_1',
      peerName: 'Sophie Valade',
      peerAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBnQ6ZoC8wo3nLNU4wcm4uKYUvFAlBfMoP6saRcHGC1Pyc3O5sN3p45KfqLgu4iL5VgpHoAlSS9zFmJvzAoOMjpjts3jHV0wARsChitgTFNBJPSnJMkUsGNr6gfnlASfDCJOGtd1tb9whRc-S_2YEtwMojts7ttsd8CBl-ooFjsDwDZyGLGddcGKgOxk9A0SbOaLDb3Y-9HJ_vZRT88CL8KsSybmD4rrKu6RU-v8zc',
      isVideo: false,
      direction: CallDirection.outgoing,
      timestamp: 'Aujourd\'hui à 10:45',
      duration: '04:12',
    ),
    CallLog(
      id: 'call_2',
      peerName: 'Dr. Idriss Traoré',
      peerAvatar:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBPFAiD9Og5A8GtV1bmuIbN_eye-Uhvv5nO328ezbs4q4UUuEuMtM9kBVqGlHpXDbmxYD82XU9hARxi-KtSPWrW9i7L0sGfZLhmuhyhVyYYiqyIzQnmc896G3h9Jf-izVUbf4LY_bZKYBXK-z74Ql6WnBlZLEeJzzgQd47iFcXEgwEAx5TeCsLEqMyI6P3wau72sDeU2NzBDrYbfom1fYZPpjF3uYYgktrK-nz4t4w',
      isVideo: true,
      direction: CallDirection.incoming,
      timestamp: 'Hier à 16:20',
      duration: '12:45',
    ),
    CallLog(
      id: 'call_3',
      peerName: 'Dr. Sarah Connor',
      peerAvatar: '',
      isVideo: false,
      direction: CallDirection.missed,
      timestamp: 'Hier à 11:05',
      duration: 'Sans réponse',
    ),
  ];
  for (final log in initialCallLogs) {
    await db.insert('call_logs', log.id, log.toJson());
  }
}
