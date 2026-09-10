# Vincular el proyecto a tu repositorio de GitHub

Guía completa desde la carpeta descomprimida hasta el APK publicado automáticamente.

---

## 1. Crear el repositorio en GitHub

En GitHub: **New repository**.

- Nombre sugerido: `planificamina`
- Público o privado, da igual para el funcionamiento.
- **No marques** "Add a README", "Add .gitignore" ni "Choose a license". El proyecto ya trae los tres, y marcarlos crea un conflicto en el primer `push`.

---

## 2. Preparar la carpeta local

```bash
cd ruta/donde/descomprimiste/planificamina

# Reemplaza el marcador de la licencia por tu nombre
# (o edita el archivo LICENSE a mano)
```

Verifica que estás en la carpeta correcta: debe contener `pubspec.yaml`, `lib/` y `.github/`.

```bash
ls -a
```

---

## 3. Generar los andamios de plataforma

El proyecto trae `lib/`, `test/` y la configuración, pero no las carpetas `android/` e `ios/`, que son código generado por Flutter.

```bash
flutter create --platforms=android,ios --project-name planificamina .
```

Esto **no toca** tu código: solo añade los andamios. Si solo te interesa Android, usa `--platforms=android`.

Comprueba que todo compila antes de subir nada:

```bash
flutter pub get
flutter analyze
flutter test
```

---

## 4. Primer commit y vinculación

```bash
git init
git add .
git commit -m "PlanificaMina 1.0.0 — simulador de planeamiento minero"
git branch -M main

# Sustituye USUARIO y REPOSITORIO por los tuyos
git remote add origin https://github.com/USUARIO/REPOSITORIO.git
git push -u origin main
```

Si usas SSH en lugar de HTTPS:

```bash
git remote add origin git@github.com:USUARIO/REPOSITORIO.git
```

---

## 5. Qué ocurre automáticamente

En cuanto termina el `push`, GitHub Actions ejecuta el workflow **CI**: instala Flutter, corre `flutter analyze` y ejecuta la suite de pruebas. Lo ves en la pestaña **Actions**.

Si la suite falla, mira primero si el fallo viene de la **regresión pedagógica** — son las pruebas que verifican que cada caso de estudio tenga material sobre *y* bajo la ley de corte. Un fallo ahí significa que un caso quedó degenerado, no que la app esté rota.

---

## 6. Generar el APK

**Opción A — desde GitHub, sin instalar nada:**

Pestaña **Actions** → workflow **Build APK** → **Run workflow**. Al terminar, el APK queda como artefacto descargable de la ejecución.

**Opción B — publicarlo como release:**

```bash
git tag v1.0.0
git push origin v1.0.0
```

La etiqueta dispara la compilación y adjunta los APK al release automáticamente.

**Opción C — en tu máquina:**

```bash
flutter build apk --release
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 7. Configuración recomendada del repositorio

**Settings → Branches → Add branch protection rule** sobre `main`:

- Requerir que el CI pase antes de fusionar.
- Requerir Pull Request para cambios.

Es especialmente útil aquí: impide que un error de fórmula llegue a `main` sin pasar por las pruebas.

**Settings → Actions → General:** verifica que "Read and write permissions" esté activo si quieres que el workflow publique releases.

**Topics sugeridos** (rueda dentada junto a "About"): `flutter`, `dart`, `mining-engineering`, `educational-app`, `mine-planning`, `cutoff-grade`.

---

## 8. Corregir los enlaces de la plantilla

En `.github/ISSUE_TEMPLATE/config.yml` hay una URL con `USUARIO/REPOSITORIO`. Sustitúyela por la tuya:

```bash
sed -i 's|USUARIO/REPOSITORIO|tu-usuario/tu-repo|' .github/ISSUE_TEMPLATE/config.yml
git add .github/ISSUE_TEMPLATE/config.yml
git commit -m "docs: corregir enlace de la plantilla de issues"
git push
```

En macOS el comando es `sed -i '' 's|...|...|' archivo`.

---

## 9. Firmar el APK para distribución real

Mientras uses `flutter build apk --release` sin configurar firma, Android usa una clave de depuración: sirve para instalar manualmente y para pruebas con estudiantes, pero no para Play Store.

Para distribución real:

```bash
keytool -genkey -v -keystore ~/planificamina.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias planificamina
```

Crea `android/key.properties` (ya está en `.gitignore`, **nunca lo subas**):

```properties
storePassword=...
keyPassword=...
keyAlias=planificamina
storeFile=/ruta/absoluta/planificamina.jks
```

Y conecta la firma en `android/app/build.gradle`. Para firmar también en Actions, sube el keystore en base64 como *secret* del repositorio y decodifícalo en el workflow — no antes de tener el flujo local funcionando.

---

## Estructura que quedará en el repositorio

```
planificamina/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                     análisis + pruebas en cada push
│   │   └── build-apk.yml              APK al etiquetar una versión
│   ├── ISSUE_TEMPLATE/
│   │   ├── 01_error_de_contenido.yml  máxima prioridad del proyecto
│   │   ├── 02_error_de_software.yml
│   │   ├── 03_propuesta.yml
│   │   └── config.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── dependabot.yml
├── docs/                              etapas 3, 5, 6 y correcciones
├── lib/ · test/
├── .gitattributes · .gitignore
├── CHANGELOG.md · CONTRIBUTING.md · LICENSE · README.md
├── analysis_options.yaml · pubspec.yaml
└── android/ · ios/                    generados en el paso 3
```
