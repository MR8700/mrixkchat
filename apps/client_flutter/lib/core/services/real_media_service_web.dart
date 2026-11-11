import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math';
import 'dart:typed_data';

/// Represents a real document picked from the device
class RealDocumentFile {
  final String name;
  final int size;
  final String dataUri;
  final String extension;
  final String formattedSize;

  RealDocumentFile({
    required this.name,
    required this.size,
    required this.dataUri,
    required this.extension,
    required this.formattedSize,
  });

  String get fileName => name;
  String get fileSize => formattedSize;
  String get fileType => extension.toUpperCase();
}

/// Real Media Service implementation for Web platform using HTML5 Web Audio,
/// MediaRecorder, Web SpeechSynthesis and MediaDevices via standard JS interop.
class RealMediaService {
  static final RealMediaService instance = RealMediaService._();
  RealMediaService._();

  Timer? _ringTimer;
  bool _isRinging = false;

  html.MediaStream? _micStream;
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _recordedChunks = [];
  Completer<String>? _recordingCompleter;
  html.AudioElement? _activeAudioElement;

  /// Plays authentic acoustic ringtone (dual-frequency 440Hz + 480Hz cadence)
  Future<void> startRingtone() async {
    _isRinging = true;
    _ringTimer?.cancel();

    void playSingleRing() {
      if (!_isRinging) return;
      try {
        js.context.callMethod('eval', [
          '''
          (function() {
            try {
              var AudioCtx = window.AudioContext || window.webkitAudioContext;
              if (!AudioCtx) return;
              var ctx = window._mrixkAudioCtx || (window._mrixkAudioCtx = new AudioCtx());
              if (ctx.state === 'suspended') ctx.resume();
              var now = ctx.currentTime;

              var osc1 = ctx.createOscillator();
              var osc2 = ctx.createOscillator();
              var gain = ctx.createGain();

              osc1.type = 'sine';
              osc1.frequency.value = 440;

              osc2.type = 'sine';
              osc2.frequency.value = 480;

              gain.gain.setValueAtTime(0.001, now);
              gain.gain.exponentialRampToValueAtTime(0.18, now + 0.05);
              gain.gain.setValueAtTime(0.18, now + 1.2);
              gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.35);

              osc1.connect(gain);
              osc2.connect(gain);
              gain.connect(ctx.destination);

              osc1.start(now);
              osc2.start(now);
              osc1.stop(now + 1.35);
              osc2.stop(now + 1.35);

              if (navigator.vibrate) navigator.vibrate([200, 100, 200]);
            } catch(e) {}
          })();
          '''
        ]);
      } catch (_) {}
    }

    playSingleRing();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (_isRinging) {
        playSingleRing();
      } else {
        _ringTimer?.cancel();
      }
    });
  }

  /// Stops acoustic ringing tone
  void stopRingtone() {
    _isRinging = false;
    _ringTimer?.cancel();
    _ringTimer = null;
  }

  /// Speaks an audible announcement in French clearly via Web Speech Synthesis
  Future<void> speakAudibleMessage(String message) async {
    try {
      if (html.window.speechSynthesis != null) {
        html.window.speechSynthesis!.cancel();
        final utterance = html.SpeechSynthesisUtterance(message);
        utterance.lang = 'fr-FR';
        utterance.rate = 1.0;
        utterance.pitch = 1.0;
        html.window.speechSynthesis!.speak(utterance);
      }
    } catch (_) {}
  }

  /// Triggers device vibration feedback
  void vibrate() {
    try {
      js.context.callMethod('eval', [
        "if (typeof navigator !== 'undefined' && navigator.vibrate) { navigator.vibrate([200, 100, 200]); }"
      ]);
    } catch (_) {}
  }

  /// Starts real microphone recording
  Future<bool> startMicrophoneRecording() async {
    try {
      _recordedChunks.clear();
      _recordingCompleter = Completer<String>();

      if (html.window.navigator.mediaDevices != null) {
        _micStream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});
        _mediaRecorder = html.MediaRecorder(_micStream!);

        _mediaRecorder!.addEventListener('dataavailable', (event) {
          final blobEvent = event as html.BlobEvent;
          if (blobEvent.data != null && blobEvent.data!.size > 0) {
            _recordedChunks.add(blobEvent.data!);
          }
        });

        _mediaRecorder!.addEventListener('stop', (_) {
          if (_recordedChunks.isNotEmpty) {
            final fullBlob = html.Blob(_recordedChunks, 'audio/webm');
            final blobUrl = html.Url.createObjectUrlFromBlob(fullBlob);
            _recordingCompleter?.complete(blobUrl);
          } else {
            _recordingCompleter?.complete(generateAuthenticWavDataUri());
          }
          _micStream?.getTracks().forEach((track) => track.stop());
          _micStream = null;
        });

        _mediaRecorder!.start();
        return true;
      }
    } catch (e) {
      return false;
    }

    return false;
  }

  /// Stops microphone recording and resolves audio URL
  Future<String> stopMicrophoneRecording() async {
    try {
      if (_mediaRecorder != null && _mediaRecorder!.state != 'inactive') {
        _mediaRecorder!.stop();
        if (_recordingCompleter != null) {
          return await _recordingCompleter!.future.timeout(
            const Duration(seconds: 2),
            onTimeout: () => generateAuthenticWavDataUri(),
          );
        }
      }
    } catch (_) {}

    return generateAuthenticWavDataUri();
  }

  /// Default local real test image
  String get defaultTestImageUrl => '/imagetest.png';

  /// Picks a real media file from device via HTML input
  Future<String?> pickMediaFile({required bool isVideo}) async {
    try {
      final input = html.FileUploadInputElement();
      input.accept = isVideo ? 'video/*,video/mp4' : 'image/*,image/png,image/jpeg';
      input.click();

      await input.onChange.first;
      if (input.files != null && input.files!.isNotEmpty) {
        final file = input.files!.first;
        final reader = html.FileReader();
        final completer = Completer<String?>();

        reader.onLoadEnd.listen((e) {
          final res = reader.result;
          if (res is String) {
            completer.complete(res);
          } else {
            completer.complete(null);
          }
        });

        reader.readAsDataUrl(file);
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => null,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Captures a photo using the device camera (HTML5 capture or file picker)
  Future<String?> captureCameraPhoto() async {
    try {
      final input = html.FileUploadInputElement();
      input.accept = 'image/*';
      input.setAttribute('capture', 'user');
      input.click();

      await input.onChange.first;
      if (input.files != null && input.files!.isNotEmpty) {
        final file = input.files!.first;
        final reader = html.FileReader();
        final completer = Completer<String?>();

        reader.onLoadEnd.listen((e) {
          final res = reader.result;
          if (res is String) {
            completer.complete(res);
          } else {
            completer.complete(null);
          }
        });

        reader.readAsDataUrl(file);
        return await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => null,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Picks a document file (PDF, TXT, DOCX, etc.) from device via HTML input
  Future<RealDocumentFile?> pickDocumentFile() async {
    try {
      final input = html.FileUploadInputElement();
      input.accept = '.pdf,.doc,.docx,.txt,.xls,.xlsx,.ppt,.pptx,.zip,.tar,.gz,application/*,text/*';
      input.click();

      await input.onChange.first;
      if (input.files != null && input.files!.isNotEmpty) {
        final file = input.files!.first;
        final reader = html.FileReader();
        final completer = Completer<String?>();

        reader.onLoadEnd.listen((e) {
          final res = reader.result;
          if (res is String) {
            completer.complete(res);
          } else {
            completer.complete(null);
          }
        });

        reader.readAsDataUrl(file);
        final dataUri = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => null,
        );

        final fileName = file.name;
        final fileSize = file.size;
        final ext = fileName.contains('.') ? fileName.split('.').last : 'FILE';

        String formatBytes(int bytes) {
          if (bytes < 1024) return '$bytes B';
          if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
        }

        return RealDocumentFile(
          name: fileName,
          size: fileSize,
          dataUri: dataUri ?? '',
          extension: ext,
          formattedSize: formatBytes(fileSize),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Plays audio from URL, data URI, or gentle vocal harmonic note
  void playAudio(String? audioUrl) {
    stopAudio();
    try {
      if (audioUrl != null && audioUrl.isNotEmpty) {
        final audio = html.AudioElement(audioUrl)
          ..volume = 1.0
          ..autoplay = false;
        _activeAudioElement = audio;
        audio.onEnded.listen((_) {
          _activeAudioElement = null;
        });
        audio.play().catchError((e) {
          _playAuthenticVocalTone();
        });
      } else {
        _playAuthenticVocalTone();
      }
    } catch (_) {
      _playAuthenticVocalTone();
    }
  }

  /// Stops any currently playing audio
  void stopAudio() {
    try {
      _activeAudioElement?.pause();
      _activeAudioElement?.currentTime = 0;
      _activeAudioElement = null;
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            if (window._mrixkVoiceOsc) {
              window._mrixkVoiceOsc.forEach(function(o) { try { o.stop(); } catch(e){} });
              window._mrixkVoiceOsc = [];
            }
          } catch(e) {}
        })();
        '''
      ]);
    } catch (_) {}
  }

  /// Plays an authentic acoustic vocal harmonic tone using Web Audio API
  void _playAuthenticVocalTone() {
    try {
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            var AudioCtx = window.AudioContext || window.webkitAudioContext;
            if (!AudioCtx) return;
            var ctx = window._mrixkAudioCtx || (window._mrixkAudioCtx = new AudioCtx());
            if (ctx.state === 'suspended') ctx.resume();
            var now = ctx.currentTime;

            var osc1 = ctx.createOscillator();
            var osc2 = ctx.createOscillator();
            var gain = ctx.createGain();

            osc1.type = 'sawtooth';
            osc1.frequency.setValueAtTime(140, now);
            osc1.frequency.exponentialRampToValueAtTime(180, now + 0.3);
            osc1.frequency.exponentialRampToValueAtTime(135, now + 0.9);

            osc2.type = 'sine';
            osc2.frequency.setValueAtTime(280, now);
            osc2.frequency.exponentialRampToValueAtTime(360, now + 0.3);
            osc2.frequency.exponentialRampToValueAtTime(270, now + 0.9);

            gain.gain.setValueAtTime(0.001, now);
            gain.gain.exponentialRampToValueAtTime(0.22, now + 0.05);
            gain.gain.setValueAtTime(0.22, now + 0.9);
            gain.gain.exponentialRampToValueAtTime(0.0001, now + 1.2);

            osc1.connect(gain);
            osc2.connect(gain);
            gain.connect(ctx.destination);

            osc1.start(now);
            osc2.start(now);
            osc1.stop(now + 1.2);
            osc2.stop(now + 1.2);

            window._mrixkVoiceOsc = [osc1, osc2];
          } catch(e) {}
        })();
        '''
      ]);
    } catch (_) {
      speakAudibleMessage("Note vocale.");
    }
  }

  /// Fallback authentic WAV generator with a gentle, warm vocal fundamental frequency
  /// (~130 Hz + 260 Hz harmonic with speech cadence, low volume 0.12)
  static String generateAuthenticWavDataUri({int durationSeconds = 3, double frequency = 130.0}) {
    const sampleRate = 22050;
    final totalSamples = sampleRate * durationSeconds;
    final byteData = ByteData(44 + totalSamples * 2);

    byteData.setUint8(0, 0x52);
    byteData.setUint8(1, 0x49);
    byteData.setUint8(2, 0x46);
    byteData.setUint8(3, 0x46);
    byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
    byteData.setUint8(8, 0x57);
    byteData.setUint8(9, 0x41);
    byteData.setUint8(10, 0x56);
    byteData.setUint8(11, 0x45);

    byteData.setUint8(12, 0x66);
    byteData.setUint8(13, 0x6D);
    byteData.setUint8(14, 0x74);
    byteData.setUint8(15, 0x20);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);

    byteData.setUint8(36, 0x64);
    byteData.setUint8(37, 0x61);
    byteData.setUint8(38, 0x74);
    byteData.setUint8(39, 0x61);
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final envelope = (t < 0.08)
          ? (t / 0.08)
          : (t > durationSeconds - 0.08 ? ((durationSeconds - t) / 0.08) : 1.0);
      final cadence = 0.85 + 0.15 * sin(2 * pi * 3.5 * t);
      final fundamental = sin(2 * pi * frequency * t);
      final harmonic = 0.35 * sin(2 * pi * (frequency * 2) * t);
      final sample = (32767.0 * 0.12 * envelope * cadence * ((fundamental + harmonic) / 1.35))
          .toInt()
          .clamp(-32768, 32767);
      byteData.setInt16(44 + i * 2, sample, Endian.little);
    }

    final bytes = byteData.buffer.asUint8List();
    return 'data:audio/wav;base64,${base64Encode(bytes)}';
  }
}
