# mrixk_client

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Appels audio et vidéo WebRTC

Le client échange les descriptions SDP et les candidats ICE via l’API/WebSocket MRixk, puis établit le flux média chiffré de pair à pair avec `flutter_webrtc`. L’accès au micro et à la caméra est demandé au démarrage d’un appel.

Le client inclut un serveur STUN pour les connexions directes. Pour fonctionner derrière les NAT et pare-feux restrictifs, configurez aussi un relais TURN et fournissez ses paramètres au build :

```sh
flutter build apk \
  --dart-define=TURN_URL=turn:turn.example.net:3478 \
  --dart-define=TURN_USERNAME=identifiant-temporaire \
  --dart-define=TURN_PASSWORD=secret-temporaire
```

Utilisez des identifiants TURN courts et renouvelés par appareil. Sans TURN, certains réseaux mobiles ou d’entreprise ne permettront pas d’établir l’appel.
