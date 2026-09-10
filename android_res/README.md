# Recursos de Android

El repositorio no versiona la carpeta `android/`: es un andamio generado, y el
workflow **Build APK** la crea con `flutter create` en cada ejecución. Eso tiene
una consecuencia incómoda: cualquier personalización que viva dentro de
`android/` se pierde en cada build.

Esta carpeta existe para lo que sí queremos conservar. El workflow copia
`android_res/res/` sobre `android/app/src/main/res/` justo después de generar el
andamio, pisando el logotipo de Flutter que trae el template.

```
res/
├── mipmap-anydpi-v26/ic_launcher.xml       icono adaptativo (Android 8+)
├── mipmap-{m,h,xh,xxh,xxx}dpi/
│   ├── ic_launcher.png                     icono legacy, con fondo
│   └── ic_launcher_foreground.png          capa frontal del adaptativo
└── values/planificamina_icon.xml           color de fondo del adaptativo
```

## El icono

Tres bancos de un tajo abierto vistos en sección, en el dorado de la paleta
(`AppColors.ore`) sobre el fondo de la app (`AppColors.bedrock`).

Son trapecios y no rectángulos por una razón concreta: apilados forman un
embudo escalonado, que se reconoce como una mina. Con rectángulos el icono
parecía un gráfico de barras.

La capa frontal del icono adaptativo dibuja el motivo al 48 % del lienzo, no al
76 % como la versión legacy, porque Android recorta hasta el 66 % central y
además le aplica una animación de acercamiento.

## Regenerarlo

`icon_source_1024.png` es la fuente a tamaño completo, por si conviene retocarla
a mano. Para volver a generar todas las densidades desde cero está el script que
las produjo, `tools/gen_icon.ps1`:

```powershell
./tools/gen_icon.ps1 "android_res/res"
```
