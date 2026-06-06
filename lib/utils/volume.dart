import 'dart:async';

import 'package:flutter/services.dart';

class VolumeListener {
  static const channel = EventChannel('venera/volume');

  void Function()? onUp;

  void Function()? onDown;

  VolumeListener({this.onUp, this.onDown});

  StreamSubscription? stream;

  void listen() {
    stream?.cancel();
    stream = channel.receiveBroadcastStream().listen(onEvent);
  }

  void onEvent(event) {
    if (event == 1) {
      onUp!();
    } else if (event == 2) {
      onDown!();
    }
  }

  void cancel() {
    stream?.cancel();
    stream = null;
  }
}

class VolumePageTurnRegistry {
  static final List<_VolumePageTurnEntry> _entries = [];

  static final VolumeListener _listener = VolumeListener(
    onUp: () => _dispatch(isDown: false),
    onDown: () => _dispatch(isDown: true),
  );

  static bool _listening = false;

  static int _suspendCount = 0;

  static void register(
    Object owner, {
    required bool Function() canHandle,
    required void Function() onUp,
    required void Function() onDown,
  }) {
    unregister(owner);
    _entries.add(
      _VolumePageTurnEntry(
        owner: owner,
        canHandle: canHandle,
        onUp: onUp,
        onDown: onDown,
      ),
    );
    if (!_listening && _suspendCount == 0) {
      _listener.listen();
      _listening = true;
    }
  }

  static void unregister(Object owner) {
    _entries.removeWhere((entry) => identical(entry.owner, owner));
    if (_entries.isEmpty && _listening) {
      _listener.cancel();
      _listening = false;
    }
  }

  static void suspend() {
    _suspendCount++;
    if (_listening) {
      _listener.cancel();
      _listening = false;
    }
  }

  static void resume() {
    if (_suspendCount > 0) {
      _suspendCount--;
    }
    if (_suspendCount == 0 && _entries.isNotEmpty && !_listening) {
      _listener.listen();
      _listening = true;
    }
  }

  static void _dispatch({required bool isDown}) {
    final staleEntries = <_VolumePageTurnEntry>[];
    for (final entry in List<_VolumePageTurnEntry>.of(_entries).reversed) {
      try {
        if (!entry.canHandle()) {
          continue;
        }
      } catch (_) {
        staleEntries.add(entry);
        continue;
      }
      if (isDown) {
        entry.onDown();
      } else {
        entry.onUp();
      }
      return;
    }
    if (staleEntries.isNotEmpty) {
      _entries.removeWhere(staleEntries.contains);
      if (_entries.isEmpty && _listening) {
        _listener.cancel();
        _listening = false;
      }
    }
  }
}

class _VolumePageTurnEntry {
  const _VolumePageTurnEntry({
    required this.owner,
    required this.canHandle,
    required this.onUp,
    required this.onDown,
  });

  final Object owner;

  final bool Function() canHandle;

  final void Function() onUp;

  final void Function() onDown;
}
