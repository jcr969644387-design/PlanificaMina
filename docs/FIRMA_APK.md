# Firmar el APK para distribución

## Qué problema resuelve y qué no

Al instalar el APK, Google Play Protect muestra una advertencia. Conviene
separar las dos causas, porque solo una está en nuestras manos.

**1. El APK se instala fuera de Google Play.** Android avisa siempre en ese
caso: «orígenes desconocidos», «Play Protect no reconoce al desarrollador»,
«¿enviar la app para analizar?». Esto **no desaparece** firmando el APK. Solo
desaparece publicando en Google Play, que exige una cuenta de desarrollador de
pago y un proceso de revisión.

**2. El APK va firmado con la clave de depuración.** Esta sí es nuestra, y es
la que se corrige aquí. Cuando Flutter compila sin una clave configurada,
recurre a la clave de depuración: la misma en todas las instalaciones de
Android del mundo, con el titular literal `CN=Android Debug`. Cualquiera puede
firmar cualquier cosa con ella, así que no identifica a nadie, y los sistemas
de seguridad la tratan con más recelo.

Firmar con una clave propia, además, es imprescindible para otra cosa: Android
solo permite **actualizar** una app instalada si la nueva versión está firmada
con la misma clave. Mientras se use la de depuración, cada versión nueva puede
obligar a desinstalar la anterior y perder el progreso guardado.

Resumiendo con honestidad: tras hacer esto, **seguirá apareciendo un aviso al
instalar desde el navegador**, pero será el aviso genérico de instalar fuera de
Play, no el de una app firmada con una clave de desarrollo.

## Pasos

Se hace una sola vez. Necesitas `keytool`, que viene con cualquier instalación
de Java (JDK 17, por ejemplo).

### 1. Generar la clave

Desde la raíz del proyecto:

```bash
./tools/gen_keystore.sh
```

El script pide una contraseña y genera `planificamina-release.jks` con validez
de 27 años. Al terminar imprime el contenido en base64, que es lo que hay que
pegar en GitHub.

Si prefieres hacerlo a mano:

```bash
keytool -genkeypair -v \
  -keystore planificamina-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias planificamina \
  -dname "CN=PlanificaMina, OU=Educacion, O=PlanificaMina, C=PE"
```

> **Guarda el archivo `.jks` y la contraseña en un sitio seguro.** Si los
> pierdes, no podrás publicar actualizaciones que se instalen encima de las
> versiones ya repartidas: Android las rechazará por firma distinta. No hay
> forma de recuperarlo.
>
> El `.gitignore` ya excluye `*.jks`. **Nunca subas el keystore al
> repositorio**: quien lo tenga puede firmar aplicaciones haciéndose pasar por
> esta.

### 2. Cargar los cuatro secrets en GitHub

En `Settings` → `Secrets and variables` → `Actions` → `New repository secret`,
crea estos cuatro:

| Secret | Contenido |
|---|---|
| `KEYSTORE_BASE64` | El base64 que imprime el script (o `base64 -w0 planificamina-release.jks`) |
| `KEYSTORE_PASSWORD` | La contraseña del almacén |
| `KEY_ALIAS` | `planificamina` |
| `KEY_PASSWORD` | La contraseña de la clave (la misma, si no pusiste otra) |

### 3. Volver a compilar

Cualquier push a `main`, o una etiqueta nueva, ya produce un APK firmado. El
workflow lo verifica solo: si el APK terminara firmado con la clave de
depuración pese a haber secrets, el build **falla** en vez de publicar un APK
que parece firmado y no lo está.

Mientras falte `KEYSTORE_BASE64`, el build no falla — sigue produciendo el APK
con la clave de depuración — pero deja un aviso visible en la ejecución.

## Comprobarlo

```bash
# Con las herramientas del Android SDK
apksigner verify --print-certs app-release.apk
```

Si aparece `CN=Android Debug`, sigue usando la clave de depuración. Si aparece
`CN=PlanificaMina`, está firmado correctamente.

## Cómo instalarlo con el mínimo de fricción

Aunque esté bien firmado, el aviso de origen desconocido sigue ahí. Para
repartirlo a estudiantes ayuda:

- Enviar el enlace del **release**, no el artefacto de Actions, que caduca y
  exige cuenta de GitHub.
- Avisar de antemano de que Android preguntará, y que hay que aceptar
  «Instalar de todos modos».
- No renombrar el archivo: algunos gestores de descargas rompen el APK si
  cambia la extensión.
