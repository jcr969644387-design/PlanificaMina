import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Retroalimentación táctil y sonora.
///
/// Se llama `Haptics` y no `Feedback` porque Material ya exporta una clase con
/// ese nombre y las dos acabarían importadas en el mismo archivo.
///
/// La vibración usa `performHapticFeedback` de la vista, que **no** exige el
/// permiso VIBRATE. El sonido son WAV cortos propios, en `assets/sounds/`,
/// generados por `tools/gen_sounds.ps1`.
///
/// La primera versión de esto usaba `SystemSound.play(SystemSoundType.click)`,
/// que no añadía dependencias pero tampoco se oía: en Android ese clic sale
/// solo si el usuario tiene activados los sonidos táctiles del sistema, y de
/// fábrica suelen venir apagados. Sonar de verdad exige reproducir audio
/// propio, y para eso hace falta un reproductor.
///
/// La intensidad codifica significado, y por eso hay varios métodos en vez de
/// uno solo: si todo sonara igual, el sonido dejaría de informar y sería solo
/// ruido. De más leve a más notorio:
///
/// - [select]   elegir una opción, mover un control discreto
/// - [tap]      abrir algo, pulsar un botón
/// - [section]  cambiar de pestaña
/// - [success]  completar una acción, guardar, confirmar
/// - [warning]  respuesta incorrecta, validación fallida
///
/// `abstract final` en vez de un constructor privado `Haptics._()`: consigue
/// lo mismo — que nadie instancie ni extienda la clase — sin dejar una
/// declaración privada sin referencias que el analizador marcaría como
/// `unused_element`, y eso en este proyecto rompe el build.
abstract final class Haptics {
  /// Volumen bajo a propósito. El encargo era «sonidos sutiles»: esto tiene
  /// que acompañar la interacción, no anunciarla.
  static const double _volume = 0.35;

  /// Un único reproductor reutilizado. Con uno solo, un toque rápido corta el
  /// sonido anterior en vez de acumular voces solapadas, que es justo lo que
  /// hace que una interfaz suene a juguete.
  static AudioPlayer? _player;

  /// Permite apagar el audio sin tocar las llamadas repartidas por la app.
  static bool enabled = true;

  static AudioPlayer _ensurePlayer() {
    var player = _player;
    if (player != null) return player;
    player = AudioPlayer();
    // lowLatency evita el retardo de preparar el flujo en cada toque, que es
    // lo que haría que el sonido llegara después del dedo.
    player.setReleaseMode(ReleaseMode.stop);
    player.setPlayerMode(PlayerMode.lowLatency);
    _player = player;
    return player;
  }

  /// Reproduce un efecto sin que un fallo de audio pueda tumbar la interfaz.
  ///
  /// Se llama sin `await` desde los métodos públicos, que son síncronos: el
  /// sonido acompaña a la interacción, no la bloquea.
  ///
  /// El `catch` general es deliberado: en un emulador sin salida de audio, o
  /// si el sistema deniega el foco, el plugin lanza. Un botón que no suena es
  /// un defecto menor; un botón que revienta al pulsarlo, no.
  static Future<void> _play(String file) async {
    if (!enabled) return;
    try {
      final player = _ensurePlayer();
      await player.stop();
      await player.play(AssetSource('sounds/$file'), volume: _volume);
    } catch (e) {
      debugPrint('Audio no disponible ($file): $e');
    }
  }

  /// Selección dentro de una lista de opciones. Lo más sutil posible.
  static void select() {
    HapticFeedback.selectionClick();
    _play('select.wav');
  }

  /// Pulsación de un botón o tarjeta.
  static void tap() {
    HapticFeedback.selectionClick();
    _play('tap.wav');
  }

  /// Cambio de pestaña o de pantalla.
  static void section() {
    HapticFeedback.lightImpact();
    _play('section.wav');
  }

  /// Acción completada: respuesta correcta, guardado, exportación, copia.
  static void success() {
    HapticFeedback.mediumImpact();
    _play('success.wav');
  }

  /// Algo salió mal o merece atención: respuesta incorrecta, plan inválido.
  static void warning() {
    HapticFeedback.heavyImpact();
    _play('warning.wav');
  }

  /// Libera el reproductor. La app no lo necesita porque vive mientras vive
  /// el proceso, pero deja el recurso cerrable desde los tests.
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
