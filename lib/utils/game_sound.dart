import 'package:flutter/services.dart';

mixin GameSound {
  static const platform = MethodChannel('com.robinson.luckywings/play_audio');

  void playSound({required String path}) =>
      platform.invokeMethod('playAudio', {'path': path});
}
