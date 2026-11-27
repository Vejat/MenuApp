import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class GuestReadyFeedback {
  web.AudioContext? _audio;

  void enableAudio() {
    try {
      final audio = _audio ??= web.AudioContext();
      if (audio.state != 'running') unawaited(_finish(audio.resume()));
    } on Object {
      // Unsupported or blocked audio leaves the visual alert available.
    }
  }

  void notify() {
    if (web.document.hidden) return;
    if (web.window.navigator.has('vibrate')) {
      try {
        web.window.navigator.vibrate([160, 100, 200].jsify()!);
      } on Object {
        // Vibration can be blocked by the browser or device settings.
      }
    }
    final audio = _audio;
    if (audio == null || audio.state != 'running') return;
    final start = audio.currentTime;
    for (final (frequency, offset) in [(660.0, 0.0), (880.0, .17)]) {
      final time = start + offset;
      final gain = audio.createGain();
      gain.gain.setValueAtTime(.001, time);
      gain.gain.linearRampToValueAtTime(.18, time + .015);
      gain.gain.exponentialRampToValueAtTime(.001, time + .24);
      gain.connect(audio.destination);
      final note = audio.createOscillator();
      note.frequency.value = frequency;
      note.connect(gain);
      note.onended = ((web.Event _) {
        note.disconnect();
        gain.disconnect();
      }).toJS;
      note.start(time);
      note.stop(time + .25);
    }
  }

  void dispose() {
    final audio = _audio;
    _audio = null;
    if (audio != null) unawaited(_finish(audio.close()));
  }

  Future<void> _finish(JSPromise<JSAny?> result) async {
    try {
      await result.toDart;
    } on Object {
      // Browsers may reject audio operations according to their policies.
    }
  }
}
