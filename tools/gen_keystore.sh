#!/usr/bin/env bash
#
# Genera la clave con la que se firma el APK de distribución e imprime el
# base64 que hay que pegar en el secret KEYSTORE_BASE64 de GitHub.
#
# Se ejecuta una sola vez. Ver docs/FIRMA_APK.md
#
set -euo pipefail

KEYSTORE="planificamina-release.jks"
ALIAS="planificamina"

if ! command -v keytool >/dev/null 2>&1; then
  echo "No se encuentra keytool. Viene con el JDK; instala Java 17 y repite."
  exit 1
fi

if [ -f "$KEYSTORE" ]; then
  echo "Ya existe $KEYSTORE en esta carpeta."
  echo
  echo "No se sobrescribe a propósito: si esta clave ya firmó un APK que"
  echo "alguien tenga instalado, reemplazarla impide actualizar esa app."
  echo "Bórralo a mano solo si estás seguro de que nadie lo ha usado."
  exit 1
fi

echo "Se va a crear $KEYSTORE con validez de unos 27 años."
echo "Elige una contraseña y guárdala donde no se pierda: sin ella no se"
echo "pueden publicar actualizaciones instalables encima de esta app."
echo

keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias "$ALIAS" \
  -dname "CN=PlanificaMina, OU=Educacion, O=PlanificaMina, C=PE"

echo
echo "==========================================================="
echo "Listo: $KEYSTORE"
echo
echo "El .gitignore ya excluye *.jks. No lo subas al repositorio."
echo
echo "Ahora crea estos cuatro secrets en GitHub, en"
echo "Settings > Secrets and variables > Actions:"
echo
echo "  KEY_ALIAS          $ALIAS"
echo "  KEYSTORE_PASSWORD  la contraseña que acabas de escribir"
echo "  KEY_PASSWORD       la misma, salvo que dieras otra a la clave"
echo "  KEYSTORE_BASE64    el bloque que aparece debajo, entero"
echo "==========================================================="
echo

if base64 --help 2>&1 | grep -q -- '-w'; then
  base64 -w0 "$KEYSTORE"   # GNU coreutils (Linux, Git Bash)
else
  base64 "$KEYSTORE" | tr -d '\n'   # BSD/macOS
fi

echo
echo
echo "(Cópialo completo, sin saltos de línea ni espacios al final.)"
