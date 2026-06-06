part of 'components.dart';

Duration get _fastAnimationDuration =>
    appdata.settings['eInkMode'] == true
        ? Duration.zero
        : const Duration(milliseconds: 160);
