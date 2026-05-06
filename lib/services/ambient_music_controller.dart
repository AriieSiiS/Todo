import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AmbientMusicController extends ChangeNotifier {
  AmbientMusicController({bool enabled = true}) : _enabled = enabled;

  static const String _assetPath =
      'resources/Persona 5 but it\'s Lofi ~ Chill Lofi Mix for Study_Work (1 Hour) [aM9dxd2nRwE] (1).mp3';

  final bool _enabled;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 0.58;
  bool _isReady = false;
  bool _isPlaying = false;
  String? _errorMessage;

  Duration get duration => _duration;
  Duration get position => _position;
  double get volume => _volume;
  bool get isReady => _isReady;
  bool get isPlaying => _isPlaying;
  String? get errorMessage => _errorMessage;
  String get title => 'Persona 5 Lofi';
  String get subtitle => 'Loop ambiente para foco y calma';

  Future<void> initialize() async {
    if (!_enabled || _isReady) {
      return;
    }
    _player ??= AudioPlayer();
    _wireStreams();
    try {
      await _player!.setAsset(_assetPath);
      await _player!.setLoopMode(LoopMode.one);
      await _player!.setVolume(_volume);
      _duration = _player!.duration ?? Duration.zero;
      _isReady = true;
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'No se pudo cargar la musica: $error';
      notifyListeners();
    }
  }

  Future<void> play() async {
    if (!_enabled || _player == null) {
      return;
    }
    try {
      await _player!.play();
    } catch (error) {
      _errorMessage =
          'No se pudo reproducir automaticamente. Pulsa play para intentarlo.';
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player?.pause();
  }

  Future<void> togglePlayback() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration value) async {
    await _player?.seek(value);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 1);
    await _player?.setVolume(_volume);
    notifyListeners();
  }

  void _wireStreams() {
    final player = _player;
    if (player == null) {
      return;
    }
    _playerStateSubscription = player.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        unawaited(player.seek(Duration.zero));
        unawaited(player.play());
      }
      notifyListeners();
    });

    _durationSubscription = player.durationStream.listen((value) {
      _duration = value ?? Duration.zero;
      notifyListeners();
    });

    _positionSubscription = player.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_positionSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }
}
