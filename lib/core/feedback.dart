import 'package:flutter/services.dart';

/// Retroalimentación táctil y sonora.
///
/// Todo sale de `package:flutter/services.dart`: ni una dependencia nueva ni
/// un solo archivo de audio. El sonido es el clic del sistema, así que respeta
/// el ajuste de sonidos táctiles del teléfono, y la vibración usa
/// `performHapticFeedback` de la vista, que **no** exige el permiso VIBRATE.
///
/// Se llama `Haptics` y no `Feedback` porque Material ya exporta una clase con
/// ese nombre y las dos acabarían importadas en el mismo archivo.
///
/// La intensidad codifica significado, y por eso hay varios métodos en vez de
/// uno solo: si todo vibrara igual, la vibración dejaría de informar y sería
/// solo ruido. De más leve a más fuerte:
///
/// - [select]   elegir una opción, mover un control discreto
/// - [tap]      abrir algo, pulsar un botón
/// - [section]  cambiar de pestaña
/// - [success]  completar una acción
/// - [warning]  respuesta incorrecta, validación fallida
/// `abstract final` en vez de un constructor privado `Haptics._()`: consigue
/// lo mismo — que nadie instancie ni extienda la clase — sin dejar una
/// declaración privada sin referencias que el analizador marcaría como
/// `unused_element`, y eso en este proyecto rompe el build.
abstract final class Haptics {
  /// Selección dentro de una lista de opciones. Lo más sutil posible.
  static void select() {
    HapticFeedback.selectionClick();
  }

  /// Pulsación de un botón o tarjeta. Lleva sonido porque es la acción que el
  /// usuario asocia con «he tocado algo».
  static void tap() {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
  }

  /// Cambio de pestaña o de pantalla.
  static void section() {
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Acción completada: respuesta correcta, exportación, copia.
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Algo salió mal o merece atención: respuesta incorrecta, plan inválido.
  static void warning() {
    HapticFeedback.heavyImpact();
  }
}
